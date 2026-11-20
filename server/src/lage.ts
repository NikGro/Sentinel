import { randomBytes } from 'node:crypto';
import { EventEmitter } from 'node:events';
import type { Database } from './db.js';
import { EntityStore, TrackStore } from './entities.js';
import { migrateEntities, normalizeTargetPhotos } from './migrations.js';
import { distanceMeters } from './geo.js';
import { SpurStore, transitPosition, type SpurPunkt } from './spur.js';
import {
  commandArgs,
  ENTITY_SCHEMAS,
  INSTANZ_HAUPT,
  SCOPED_KINDS,
  type CommandName,
  type Entity,
  type EntityData,
  type Fortbewegung,
  type Kind,
  type LeapfrogStop,
  type OepnvFahrt,
  type Operation,
  type Position,
} from './schemas.js';

export type Role = 'fahnder' | 'zentrale';
export interface Actor {
  id: string;
  role: Role;
}

/** `inst` ist die Instanz des Ereignisses; `''` heißt instanzübergreifend (an alle). */
export type LageEvent =
  | { type: 'put'; kind: Kind; entity: Entity; inst: string }
  | { type: 'del'; kind: Kind; id: string; inst: string }
  | { type: 'operation'; operation: Operation; inst: string }
  | { type: 'pos'; id: string; p: Position; inst: string }
  | { type: 'tpos'; id: string; p: Position }
  | { type: 'bestreifungReset'; inst: string }
  /** Fahnder hat die Instanz gewechselt: seine Verbindungen erhalten den Zustand der neuen Instanz. */
  | { type: 'wechsel'; memberId: string; inst: string }
  /** Wichtiges Ereignis in einer Instanz (A-Position, Notruf) für Mitglieder, die gerade woanders sind. */
  | { type: 'hinweis'; inst: string; art: 'a' | 'sos'; memberId: string }
  /** Neues Sendeintervall für einen Tracker, das an das Gerät übertragen werden soll. */
  | { type: 'trackerIntervall'; anbieter: 'sinotrack' | 'paj'; kennung: string; sekunden: number };

/** Fachlicher Fehler, dessen Text dem Benutzer gezeigt werden darf. */
export class LageError extends Error {
  constructor(
    readonly code: 'verboten' | 'ungueltig' | 'unbekannt' | 'konflikt',
    message: string,
  ) {
    super(message);
  }
}

export const LAYER_LAGE = 'lage';
export const LAYER_DAUERHAFT = 'dauerhaft';
export const ROOM_ALLGEMEIN = 'allgemein';
const PROTECTED_LAYERS = new Set([LAYER_LAGE, LAYER_DAUERHAFT]);
const MAX_MESSAGES_PER_ROOM = 500;
/** Bestreifung: Punkt nur speichern, wenn er sich deutlich vom letzten unterscheidet und brauchbar genau ist. */
const TRACK_MIN_DISTANCE_M = 12;
const TRACK_MAX_ACCURACY_M = 60;
/** Ältere Bestreifung wird verworfen, damit die Datenbank nicht unbegrenzt wächst. */
const TRACK_RETENTION_MS = 72 * 3600_000;
const LEAPFROG_STOPS = 8;
/** Name der Standardinstanz. */
const STANDARD_INSTANZ_NAME = 'KSOD';
const MAX_INSTANCES = 200;

const DEFAULT_OPERATION: Operation = {
  funkkanal: null,
  titel: '',
  hinweise: '',
  a: null,
  ueberschlagen: { teilnehmer: [], zuweisungen: {}, naechste: [] },
  sos: null,
  fahrzeuge: [],
  rev: 0,
};

/** Liefert die kommenden Halte einer ÖPNV-Linie ab einem Standort (siehe oepnv.ts). */
export type UpcomingStops = (linienId: string, position: { lat: number; lon: number }, count: number) => LeapfrogStop[];

/**
 * Die Lagen aller Instanzen: gemeinsam bearbeitete Objekte, Einsatzzustand und Live-Positionen.
 * Lagebezogene Objekte (Markierungen, Ziele, Ebenen, Chats) und der Einsatzzustand gehören zu einer Instanz;
 * Profile, Fahrzeuge, Tracker, Instanzen und die dauerhaften Orte gelten instanzübergreifend.
 * Jeder Fahnder hat genau eine aktive Instanz; er sieht nur deren Lage und die Kräfte darin.
 */
export class Lage extends EventEmitter<{ event: [LageEvent] }> {
  private readonly operations = new Map<string, Operation>();
  private readonly positions = new Map<string, Position>();
  private readonly trackerPositions = new Map<string, Position>();
  private readonly lastTrackPoint = new Map<string, Position>();
  private readonly entities: EntityStore;
  private readonly tracks: TrackStore;
  /** Standortverlauf von Fahndern, Zielen, Fahrzeugen und Trackern. */
  readonly spuren: SpurStore;

  constructor(
    private readonly db: Database,
    private readonly upcomingStops: UpcomingStops = () => [],
  ) {
    super();
    this.entities = new EntityStore(db);
    this.tracks = new TrackStore(db);
    this.spuren = new SpurStore(db);
    const trackerPos = db.getKv('trackerPositions');
    if (trackerPos) for (const [id, p] of Object.entries(JSON.parse(trackerPos) as Record<string, Position>)) this.trackerPositions.set(id, p);
    migrateEntities(db);
    this.ensure('instance', '', INSTANZ_HAUPT, { name: STANDARD_INSTANZ_NAME, art: 'einsatz', beschreibung: '', mitglieder: [], erstelltVon: 'system' });
    // 0.18: Die Standardinstanz heißt „KSOD“ (einmalig umbenennen, falls sie noch den alten Namen trägt).
    const haupt = this.get('instance', INSTANZ_HAUPT, '');
    if (haupt && haupt.data.name === 'Hauptlage') this.write('instance', '', INSTANZ_HAUPT, { ...haupt.data, name: STANDARD_INSTANZ_NAME }, 'system');
    // 0.18: Auch die Standardinstanz hat eine Mitgliederliste (man kann sie verlassen und ist dann außer Dienst).
    // Bisher war jeder dort Mitglied; das wird einmalig übernommen.
    if (!db.getKv('hauptMitglieder')) {
      const current = this.get('instance', INSTANZ_HAUPT, '');
      if (current) {
        const all = [...new Set([...current.data.mitglieder, ...this.list('member').map((m) => m.id)])];
        this.write('instance', '', INSTANZ_HAUPT, { ...current.data, mitglieder: all }, 'system');
      }
      db.setKv('hauptMitglieder', '1');
    }
    this.ensure('layer', '', LAYER_DAUERHAFT, { name: 'Dauerhafte Orte', art: 'dauerhaft', status: 'live', beschreibung: 'In allen Instanzen sichtbar' });
    for (const instance of this.list('instance')) this.ensureInstance(instance.id);
    this.pruneTrack();
    this.expireAnnotations();
  }

  // ───────────────────────────── Lesen ─────────────────────────────

  /** Einsatzzustand einer Instanz. */
  operationOf(inst: string = INSTANZ_HAUPT): Operation {
    let op = this.operations.get(inst);
    if (!op) {
      const stored = this.db.getKv(operationKey(inst));
      const parsed = stored ? (JSON.parse(stored) as Partial<Operation>) : {};
      op = {
        funkkanal: parsed.funkkanal ?? null,
        titel: parsed.titel ?? '',
        hinweise: parsed.hinweise ?? '',
        a: parsed.a ?? null,
        ueberschlagen: parsed.ueberschlagen ?? DEFAULT_OPERATION.ueberschlagen,
        sos: parsed.sos ?? null,
        // Früher war „im Einsatz“ ein Merkmal des Fahrzeugs selbst; das gilt als Ausgangsstand je Instanz.
        fahrzeuge: parsed.fahrzeuge ?? this.list('vehicle').filter((v) => v.data.aktiv).map((v) => v.id),
        rev: parsed.rev ?? 0,
      };
      this.operations.set(inst, op);
      // Umstellung einmalig festhalten, damit später angelegte Fahrzeuge nicht nachträglich als aktiv gelten.
      if (parsed.fahrzeuge === undefined) this.db.setKv(operationKey(inst), JSON.stringify(op));
    }
    return op;
  }

  /** Einsatzzustand der Hauptinstanz. */
  get operation(): Operation {
    return this.operationOf(INSTANZ_HAUPT);
  }

  /** Objekte einer Art: instanzbezogene aus `inst` und die übergreifenden, sonst alle. */
  list<K extends Kind>(kind: K, inst: string = INSTANZ_HAUPT): Entity<K>[] {
    return this.entities.list(kind, inst);
  }

  get<K extends Kind>(kind: K, id: string, inst: string = INSTANZ_HAUPT): Entity<K> | null {
    return this.entities.get(kind, id, inst);
  }

  positionOf(memberId: string): Position | undefined {
    return this.positions.get(memberId);
  }

  /** Aktive Instanz eines Fahnders. */
  activeInstance(memberId: string): string {
    const inst = this.get('member', memberId)?.data.instanz ?? INSTANZ_HAUPT;
    return this.get('instance', inst) ? inst : INSTANZ_HAUPT;
  }

  /** Ob ein Fahnder Mitglied einer Instanz ist (Pakete stehen allen offen). */
  isMember(inst: string, memberId: string): boolean {
    const instance = this.get('instance', inst);
    return !!instance && (instance.data.art === 'paket' || instance.data.mitglieder.includes(memberId));
  }

  /** Vollständiger Zustand einer Instanz für einen neu verbundenen oder wechselnden Client. */
  snapshot(inst: string = INSTANZ_HAUPT) {
    const members = this.list('member');
    const here = new Set(members.filter((m) => this.activeInstance(m.id) === inst).map((m) => m.id));
    return {
      instanz: inst,
      instances: this.list('instance'),
      members,
      vehicles: this.list('vehicle'),
      annotations: this.list('annotation', inst),
      targets: this.list('target', inst),
      trackers: this.list('tracker'),
      layers: this.list('layer', inst),
      rooms: this.list('room', inst),
      messages: this.list('message', inst).sort((a, b) => a.updatedAt - b.updatedAt),
      operation: this.operationOf(inst),
      positions: [...this.positions].filter(([id]) => here.has(id)).map(([id, p]) => ({ id, p })),
      trackerPositions: [...this.trackerPositions].map(([id, p]) => ({ id, p })),
    };
  }

  coverage(inst: string = INSTANZ_HAUPT): { memberId: string; punkte: [number, number, number][] }[] {
    return this.tracks.byMember(inst);
  }

  // ───────────────────────────── Objekte schreiben ─────────────────────────────

  put(actor: Actor, kind: Kind, id: string, raw: unknown, inst: string = INSTANZ_HAUPT): Entity {
    if (kind === 'instance') throw new LageError('verboten', 'Instanzen werden über das Instanzenmenü verwaltet.');
    const parsed = ENTITY_SCHEMAS[kind].safeParse(raw);
    if (!parsed.success) throw new LageError('ungueltig', parsed.error.issues[0]?.message ?? 'Ungültige Eingabe');
    let data = parsed.data as EntityData<Kind>;
    let scope = this.scopeOf(kind, id, data, inst);
    const existing = this.get(kind, id, inst);

    switch (kind) {
      case 'member': {
        if (actor.role !== 'zentrale' && actor.id !== id) throw new LageError('verboten', 'Nur das eigene Profil ist änderbar.');
        // Aktivität, Fortbewegung, Fahrzeug und Instanz ändern sich ausschließlich über Kommandos.
        const previous = (existing as Entity<'member'> | null)?.data;
        const next = data as EntityData<'member'>;
        data = {
          ...next,
          aktiv: previous?.aktiv ?? true,
          fortbewegung: previous?.fortbewegung ?? 'fuss',
          fahrzeugId: previous?.fahrzeugId ?? null,
          fahrzeugSeit: previous?.fahrzeugSeit ?? null,
          oepnv: previous?.oepnv ?? null,
          instanz: previous?.instanz ?? INSTANZ_HAUPT,
        };
        break;
      }
      case 'message': {
        if (existing) throw new LageError('verboten', 'Nachrichten können nicht geändert werden.');
        if (!this.get('room', (data as EntityData<'message'>).roomId, inst)) throw new LageError('ungueltig', 'Chatraum existiert nicht.');
        break;
      }
      case 'target': {
        const next = data as EntityData<'target'>;
        normalizeTargetPhotos(next);
        // Wird der Tracker getrennt oder die Quelle gewechselt, bleibt das Ziel an der letzten Trackerposition stehen.
        const previous = (existing as Entity<'target'> | null)?.data;
        if (previous && sourceOf(previous) === 'tracker' && sourceOf(next) !== 'tracker' && previous.trackerId) {
          const p = this.trackerPositions.get(previous.trackerId);
          const standortUnchanged = JSON.stringify(next.standort) === JSON.stringify(previous.standort);
          if (p && standortUnchanged) data = { ...next, standort: { lat: p.lat, lon: p.lon, ts: p.ts } };
        }
        break;
      }
      case 'annotation': {
        if (!this.get('layer', (data as EntityData<'annotation'>).layerId, inst)) throw new LageError('ungueltig', 'Ebene existiert nicht.');
        // Wechselt die Markierung zwischen dauerhaften Orten und Lage, zieht sie in den anderen Bereich um.
        const other = scope === '' ? inst : '';
        if (this.entities.exists('annotation', other, id)) this.remove('annotation', other, id);
        break;
      }
      case 'layer': {
        const next = data as EntityData<'layer'>;
        if (PROTECTED_LAYERS.has(id)) {
          const current = (existing as Entity<'layer'>).data;
          data = { ...next, art: current.art, status: 'live' };
        } else if (next.art === 'lage' || next.art === 'dauerhaft') {
          throw new LageError('ungueltig', 'Diese Ebenenart ist fest vergeben.');
        }
        scope = this.scopeOf(kind, id, data, inst);
        break;
      }
      default:
        break;
    }

    const entity = this.write(kind, scope, id, data, actor.id);
    if (kind === 'message') this.trimMessages(inst, (data as EntityData<'message'>).roomId);
    // Neue Fahnder beginnen in der Standardinstanz (und damit im Dienst).
    if (kind === 'member' && !existing) {
      const haupt = this.get('instance', INSTANZ_HAUPT, '');
      if (haupt && !haupt.data.mitglieder.includes(id)) this.write('instance', '', INSTANZ_HAUPT, { ...haupt.data, mitglieder: [...haupt.data.mitglieder, id] }, 'system');
    }
    return entity;
  }

  del(actor: Actor, kind: Kind, id: string, inst: string = INSTANZ_HAUPT): void {
    if (kind === 'instance') throw new LageError('verboten', 'Instanzen werden über das Instanzenmenü verwaltet.');
    const existing = this.get(kind, id, inst);
    if (!existing) return;
    const scope = this.scopeOf(kind, id, existing.data, inst);
    switch (kind) {
      case 'member':
        if (actor.role !== 'zentrale') throw new LageError('verboten', 'Profile entfernt nur Sentinel Web.');
        for (const instance of this.list('instance')) {
          if (this.operationOf(instance.id).a?.memberId === id) this.updateOperation(instance.id, { a: null });
          this.leaveLeapfrog(instance.id, id);
          if (instance.data.mitglieder.includes(id)) {
            this.write('instance', '', instance.id, { ...instance.data, mitglieder: instance.data.mitglieder.filter((m) => m !== id) }, actor.id);
          }
        }
        this.positions.delete(id);
        break;
      case 'message': {
        const message = existing as Entity<'message'>;
        if (actor.role !== 'zentrale' && message.updatedBy !== actor.id) throw new LageError('verboten', 'Nur eigene Nachrichten können gelöscht werden.');
        break;
      }
      case 'room':
        for (const m of this.list('message', inst)) if (m.data.roomId === id) this.remove('message', inst, m.id);
        // Der allgemeine Chatraum bleibt bestehen und wird nur geleert.
        if (id === ROOM_ALLGEMEIN) return;
        break;
      case 'layer':
        if (PROTECTED_LAYERS.has(id)) throw new LageError('verboten', 'Diese Ebene kann nicht gelöscht werden.');
        for (const a of this.list('annotation', inst)) if (a.data.layerId === id) this.remove('annotation', inst, a.id);
        break;
      case 'vehicle':
        for (const m of this.occupants(id)) this.write('member', '', m.id, { ...m.data, fortbewegung: 'fuss', fahrzeugId: null, fahrzeugSeit: null }, actor.id);
        for (const instance of this.list('instance')) {
          const fahrzeuge = this.operationOf(instance.id).fahrzeuge;
          if (fahrzeuge.includes(id)) this.updateOperation(instance.id, { fahrzeuge: fahrzeuge.filter((v) => v !== id) });
        }
        break;
      case 'tracker':
        for (const { inst: i, entity: t } of this.entities.listAll('target')) {
          if (t.data.trackerId !== id) continue;
          // Das Ziel bleibt an der letzten Position des gelöschten Trackers stehen.
          const p = this.trackerPositions.get(id);
          const standort = p && sourceOf(t.data) === 'tracker' ? { lat: p.lat, lon: p.lon, ts: p.ts } : t.data.standort;
          this.write('target', i, t.id, { ...t.data, trackerId: null, quelle: t.data.quelle === 'tracker' ? 'hand' : t.data.quelle, standort }, actor.id);
        }
        this.spuren.clear('tracker', id);
        for (const v of this.list('vehicle')) if (v.data.trackerId === id) this.write('vehicle', '', v.id, { ...v.data, trackerId: null }, actor.id);
        for (const { inst: i, entity: a } of this.entities.listAll('annotation')) if (a.data.trackerId === id) this.write('annotation', i, a.id, { ...a.data, trackerId: null }, actor.id);
        this.trackerPositions.delete(id);
        this.persistTrackerPositions();
        break;
      default:
        break;
    }
    // Mit dem Objekt verschwindet auch seine Spur.
    if (kind === 'member' || kind === 'target' || kind === 'vehicle') this.spuren.clear(kind, id);
    this.remove(kind, scope, id);
  }

  /**
   * Ein bestehendes Profil auf ein neu angemeldetes Gerät übernehmen (z. B. nach dem Abmelden): Die Angaben wandern
   * zur neuen Kennung, das alte Profil verschwindet. So entsteht kein doppeltes Profil.
   */
  adoptMember(newId: string, oldId: string): Entity<'member'> {
    const old = this.get('member', oldId);
    if (!old) throw new LageError('unbekannt', 'Profil existiert nicht.');
    if (this.get('member', newId)) throw new LageError('konflikt', 'Dieses Gerät hat schon ein Profil.');
    const entity = this.write('member', '', newId, { ...old.data, fortbewegung: 'fuss', fahrzeugId: null, fahrzeugSeit: null, oepnv: null }, newId);
    for (const instance of this.list('instance')) {
      if (instance.data.mitglieder.includes(oldId)) {
        this.write('instance', '', instance.id, { ...instance.data, mitglieder: [...instance.data.mitglieder.filter((m) => m !== oldId), newId] }, newId);
      }
    }
    this.del({ id: 'zentrale', role: 'zentrale' }, 'member', oldId);
    return entity;
  }

  // ───────────────────────────── Positionen ─────────────────────────────

  reportPosition(memberId: string, p: Position): void {
    const member = this.get('member', memberId);
    // Im Ruhemodus wird kein Standort geteilt.
    if (member && !member.data.aktiv) return;
    const inst = this.activeInstance(memberId);
    this.positions.set(memberId, p);
    this.emit('event', { type: 'pos', id: memberId, p, inst });
    this.recordTrack(inst, memberId, p);
    if (member?.data.aufzeichnung !== false && (p.acc ?? 0) <= TRACK_MAX_ACCURACY_M) {
      this.spuren.add('member', memberId, inst, { lat: p.lat, lon: p.lon, ts: p.ts, spd: p.spd ?? null, quelle: 'gps' });
    }
    if (this.operationOf(inst).a?.memberId === memberId) this.updateLeapfrog(inst);
  }

  /** Bestreifung: Jeder Weg wird aufgezeichnet; wer sie sehen möchte, schaltet die Anzeige in seiner App ein. */
  private recordTrack(inst: string, memberId: string, p: Position): void {
    if ((p.acc ?? 0) > TRACK_MAX_ACCURACY_M) return;
    const last = this.lastTrackPoint.get(memberId);
    if (last && (p.ts <= last.ts || distanceMeters(last, p) < TRACK_MIN_DISTANCE_M)) return;
    this.lastTrackPoint.set(memberId, p);
    this.tracks.add(inst, memberId, p);
  }

  /** Position eines Trackers, gemeldet von einem Tracker-Anbieter. `kennung` ist die Gerätekennung. */
  reportTrackerPosition(anbieter: 'sinotrack' | 'paj', kennung: string, p: Position): boolean {
    const tracker = this.list('tracker').find((t) => t.data.anbieter === anbieter && t.data.kennung === kennung);
    if (!tracker) return false;
    const previous = this.trackerPositions.get(tracker.id);
    if (previous && p.ts <= previous.ts) return true;
    this.trackerPositions.set(tracker.id, p);
    this.persistTrackerPositions();
    this.emit('event', { type: 'tpos', id: tracker.id, p });
    if (tracker.data.aufzeichnung !== false) this.spuren.add('tracker', tracker.id, '', { lat: p.lat, lon: p.lon, ts: p.ts, spd: p.spd ?? null, quelle: 'tracker' });
    return true;
  }

  /** Letzte bekannte Position eines Trackers. */
  trackerPositionOf(trackerId: string): Position | undefined {
    return this.trackerPositions.get(trackerId);
  }

  /**
   * Spuren der Ziele und Fahrzeuge fortschreiben. Ihr Standort ergibt sich aus Bindung und Quelle (ÖPNV-Fahrt,
   * Zielfahrzeug, Tracker, A-Position, von Hand); er wird hier genauso aufgelöst wie in der App.
   */
  recordSpuren(now = Date.now()): void {
    for (const { inst, entity: t } of this.entities.listAll('target')) {
      if (t.data.aufzeichnung === false) continue;
      const p = this.resolveTarget(inst, t.data, now);
      if (p) this.spuren.add('target', t.id, inst, p);
    }
    const inUse = new Set(this.list('instance').flatMap((i) => this.operationOf(i.id).fahrzeuge));
    for (const v of this.list('vehicle')) {
      if (v.data.aufzeichnung === false || !inUse.has(v.id)) continue;
      const p = this.resolveVehicle(v, now);
      if (p) this.spuren.add('vehicle', v.id, '', p);
    }
  }

  private resolveTarget(inst: string, t: EntityData<'target'>, now: number, depth = 0): SpurPunkt | null {
    const b = t.bindung;
    if (b && b.art !== 'fuss' && b.zielId && depth < 2) {
      if (b.art === 'oepnv') {
        const a = this.get('annotation', b.zielId, inst) ?? this.get('annotation', b.zielId, '');
        if (a) {
          const p = transitPosition(a.data, now) ?? a.data.punkte[0];
          const line = a.data.linie;
          const info = line ? [line.ref, line.richtung].filter(Boolean).join(' → ') : a.data.titel;
          if (p) return { lat: p.lat, lon: p.lon, ts: now, quelle: 'oepnv', info: info || null };
        }
      } else {
        const other = this.get('target', b.zielId, inst);
        if (other) {
          const p = this.resolveTarget(inst, other.data, now, depth + 1);
          const name = targetName(other.data);
          if (p) return { ...p, info: p.info ? `${name} · ${p.info}` : name };
        }
      }
    }
    switch (sourceOf(t)) {
      case 'a': {
        const a = this.operationOf(inst).a;
        const p = a ? this.positions.get(a.memberId) : undefined;
        if (a && p) return { lat: p.lat, lon: p.lon, ts: p.ts, spd: p.spd ?? null, quelle: 'a', info: this.get('member', a.memberId)?.data.spitzname ?? null };
        break;
      }
      case 'tracker': {
        const p = t.trackerId ? this.trackerPositions.get(t.trackerId) : undefined;
        if (t.trackerId && p) return { lat: p.lat, lon: p.lon, ts: p.ts, spd: p.spd ?? null, quelle: 'tracker', info: this.get('tracker', t.trackerId)?.data.name ?? null };
        break;
      }
      case 'hand':
        break;
    }
    return t.standort ? { lat: t.standort.lat, lon: t.standort.lon, ts: now, quelle: 'hand' } : null;
  }

  private resolveVehicle(v: Entity<'vehicle'>, now: number): SpurPunkt | null {
    const crew = this.occupants(v.id);
    const leader = this.vehicleLeader(v.id);
    const p = leader ? this.positions.get(leader.id) : undefined;
    if (p) return { lat: p.lat, lon: p.lon, ts: p.ts, spd: p.spd ?? null, quelle: 'besatzung', info: crew.map((m) => m.data.spitzname).join(', ') };
    const tracker = v.data.trackerId ? this.trackerPositions.get(v.data.trackerId) : undefined;
    if (tracker) return { lat: tracker.lat, lon: tracker.lon, ts: tracker.ts, spd: tracker.spd ?? null, quelle: 'tracker', info: this.get('tracker', v.data.trackerId!)?.data.name ?? null };
    if (v.data.abgestellt) return { lat: v.data.abgestellt.lat, lon: v.data.abgestellt.lon, ts: now, quelle: 'abgestellt' };
    return null;
  }

  /** Spuren älter als `days` Tage verwerfen. */
  pruneSpuren(days: number, now = Date.now()): void {
    this.spuren.pruneBefore(now - days * 86_400_000);
  }

  memberWentOffline(memberId: string): void {
    this.lastTrackPoint.delete(memberId);
  }

  // ───────────────────────────── Kommandos ─────────────────────────────

  /**
   * Führt ein Kommando aus. Fahnder handeln in ihrer aktiven Instanz; für die Kommandozentrale
   * gibt `inst` die gerade geöffnete Instanz an.
   */
  command(actor: Actor, name: CommandName, rawArgs: unknown, inst?: string): void {
    const parsed = commandArgs[name].safeParse(rawArgs ?? {});
    if (!parsed.success) throw new LageError('ungueltig', parsed.error.issues[0]?.message ?? 'Ungültige Eingabe');
    const args = (parsed.data ?? {}) as Record<string, unknown>;
    const now = Date.now();
    const here = actor.role === 'fahnder' ? this.activeInstance(actor.id) : (inst ?? INSTANZ_HAUPT);
    const op = this.operationOf(here);

    switch (name) {
      case 'a.uebernehmen': {
        if (actor.role !== 'fahnder') throw new LageError('verboten', 'Die A-Position kann nur ein Fahnder übernehmen.');
        const me = this.get('member', actor.id);
        if (!me) throw new LageError('unbekannt', 'Profil fehlt.');
        if (!me.data.aktiv) throw new LageError('konflikt', 'Im Ruhemodus kann die A-Position nicht übernommen werden.');
        this.leaveLeapfrog(here, actor.id);
        this.updateOperation(here, { a: { memberId: actor.id, seit: now } });
        this.updateLeapfrog(here);
        break;
      }
      case 'sos.ausloesen': {
        if (actor.role !== 'fahnder') throw new LageError('verboten', 'Einen Notruf kann nur ein Fahnder auslösen.');
        if (!this.get('member', actor.id)) throw new LageError('unbekannt', 'Profil fehlt.');
        if (op.sos && op.sos.memberId !== actor.id) throw new LageError('konflikt', 'Es läuft bereits ein Notruf.');
        this.updateOperation(here, { sos: { memberId: actor.id, seit: now } });
        break;
      }
      case 'sos.beenden':
        // Beenden darf, wer ihn ausgelöst hat, oder die Kommandozentrale; jeder andere nimmt ihn nur für sich zur Kenntnis.
        if (op.sos && (op.sos.memberId === actor.id || actor.role === 'zentrale')) this.updateOperation(here, { sos: null });
        break;
      case 'a.freigeben':
        if (op.a && (op.a.memberId === actor.id || actor.role === 'zentrale')) {
          this.updateOperation(here, { a: null });
          this.updateLeapfrog(here);
        }
        break;
      case 'funkkanal.setzen':
        this.updateOperation(here, { funkkanal: args.kanal as string | null });
        break;
      case 'lage.setzen':
        this.updateOperation(here, { titel: args.titel as string, hinweise: args.hinweise as string });
        break;
      case 'fortbewegung.setzen':
        this.setMobility(actor, args.art as Fortbewegung, (args.fahrzeugId as string | null | undefined) ?? null, (args.oepnv as OepnvFahrt | null | undefined) ?? null, now);
        break;
      case 'aktiv.setzen':
        this.setActive(actor, args.aktiv as boolean);
        break;
      case 'ueberschlagen.beitreten': {
        if (actor.role !== 'fahnder') throw new LageError('verboten', 'Nur Fahnder können überschlagend anfahren.');
        if (op.a?.memberId === actor.id) throw new LageError('konflikt', 'Wer die A hält, fährt nicht überschlagend.');
        if (!op.ueberschlagen.teilnehmer.includes(actor.id)) {
          this.updateOperation(here, { ueberschlagen: { ...op.ueberschlagen, teilnehmer: [...op.ueberschlagen.teilnehmer, actor.id] } });
          this.updateLeapfrog(here);
        }
        break;
      }
      case 'ueberschlagen.verlassen':
        this.leaveLeapfrog(here, actor.id);
        break;
      case 'tracker.intervall': {
        const tracker = this.get('tracker', args.trackerId as string);
        if (!tracker) throw new LageError('unbekannt', 'Tracker existiert nicht.');
        if (tracker.data.anbieter !== 'sinotrack') throw new LageError('konflikt', 'Das Sendeintervall von PAJ-Trackern wird im PAJ-Portal eingestellt.');
        const sekunden = args.sekunden as number;
        this.write('tracker', '', tracker.id, { ...tracker.data, intervall: sekunden }, actor.id);
        this.emit('event', { type: 'trackerIntervall', anbieter: tracker.data.anbieter, kennung: tracker.data.kennung, sekunden });
        break;
      }
      case 'fahrzeug.aktivieren': {
        const vehicleId = args.fahrzeugId as string;
        if (!this.get('vehicle', vehicleId)) throw new LageError('unbekannt', 'Fahrzeug nicht gefunden.');
        const others = op.fahrzeuge.filter((v) => v !== vehicleId);
        this.updateOperation(here, { fahrzeuge: args.aktiv ? [...others, vehicleId] : others });
        // Wer in dieser Instanz im abgemeldeten Fahrzeug saß, ist danach zu Fuß unterwegs.
        if (!args.aktiv) {
          for (const m of this.occupants(vehicleId)) {
            if (this.activeInstance(m.id) === here) this.write('member', '', m.id, { ...m.data, fortbewegung: 'fuss', fahrzeugId: null, fahrzeugSeit: null }, actor.id);
          }
        }
        break;
      }
      case 'bestreifung.zuruecksetzen':
        this.resetCoverage(here);
        break;
      case 'lage.zuruecksetzen':
        this.reset(actor, here, args.ziele as boolean);
        break;
      case 'lage.leeren':
        // Der Lage-Layer bleibt bestehen und wird nur geleert.
        for (const a of this.list('annotation', here)) if (a.data.layerId === LAYER_LAGE) this.remove('annotation', here, a.id);
        break;
      case 'instanz.erstellen':
        this.createInstance(actor, args.id as string, args.name as string, args.beschreibung as string, args.art as 'einsatz' | 'paket');
        break;
      case 'instanz.bearbeiten': {
        const instance = this.requireInstance(args.id as string);
        this.requireMembership(actor, instance);
        if (instance.id === INSTANZ_HAUPT && actor.role !== 'zentrale') throw new LageError('verboten', 'Die Standardinstanz benennt nur Sentinel Web um.');
        this.write('instance', '', instance.id, { ...instance.data, name: args.name as string, beschreibung: args.beschreibung as string }, actor.id);
        break;
      }
      case 'instanz.loeschen':
        this.deleteInstance(actor, args.id as string);
        break;
      case 'instanz.beitreten': {
        const instance = this.requireInstance(args.id as string);
        if (actor.role !== 'fahnder') break;
        if (instance.data.art === 'einsatz' && !instance.data.mitglieder.includes(actor.id)) {
          this.write('instance', '', instance.id, { ...instance.data, mitglieder: [...instance.data.mitglieder, actor.id] }, actor.id);
        }
        // Wer eine Instanz betritt, ist im Dienst.
        if (instance.data.art === 'einsatz') this.setActive(actor, true);
        break;
      }
      case 'instanz.verlassen': {
        const instance = this.requireInstance(args.id as string);
        if (actor.role !== 'fahnder') break;
        this.write('instance', '', instance.id, { ...instance.data, mitglieder: instance.data.mitglieder.filter((m) => m !== actor.id) }, actor.id);
        // In eine verbleibende Instanz wechseln (die Standardinstanz zuerst); ohne Instanz ist man außer Dienst.
        const remaining = this.list('instance')
          .filter((i) => i.data.art === 'einsatz' && i.id !== instance.id && i.data.mitglieder.includes(actor.id))
          .sort((x, y) => Number(y.id === INSTANZ_HAUPT) - Number(x.id === INSTANZ_HAUPT));
        if (remaining.length === 0) {
          this.setActive(actor, false);
        } else if (this.activeInstance(actor.id) === instance.id) {
          this.switchInstance(actor.id, remaining[0]!.id);
        }
        break;
      }
      case 'instanz.wechseln': {
        const instance = this.requireInstance(args.id as string);
        if (actor.role !== 'fahnder') break;
        // Wechseln heißt beitreten, wenn man noch nicht Mitglied ist; und im Dienst sein.
        if (instance.data.art === 'einsatz' && !instance.data.mitglieder.includes(actor.id)) {
          this.write('instance', '', instance.id, { ...instance.data, mitglieder: [...instance.data.mitglieder, actor.id] }, actor.id);
        }
        this.switchInstance(actor.id, instance.id);
        if (instance.data.art === 'einsatz') this.setActive(actor, true);
        break;
      }
      case 'paket.importieren':
        this.importPackage(actor, args.paketId as string, here);
        break;
    }
    this.db.audit(actor.id, `cmd:${name}`, here === INSTANZ_HAUPT ? '' : here);
  }

  // ───────────────────────────── Instanzen ─────────────────────────────

  private requireInstance(id: string): Entity<'instance'> {
    const instance = this.get('instance', id);
    if (!instance) throw new LageError('unbekannt', 'Instanz existiert nicht.');
    return instance;
  }

  private requireMembership(actor: Actor, instance: Entity<'instance'>): void {
    if (actor.role === 'zentrale') return;
    if (!this.isMember(instance.id, actor.id)) throw new LageError('verboten', 'Nur Mitglieder dürfen das.');
  }

  private createInstance(actor: Actor, id: string, name: string, beschreibung: string, art: 'einsatz' | 'paket'): void {
    if (this.get('instance', id)) throw new LageError('konflikt', 'Diese Instanz gibt es schon.');
    if (this.list('instance').length >= MAX_INSTANCES) throw new LageError('konflikt', 'Es gibt bereits zu viele Instanzen.');
    const mitglieder = actor.role === 'fahnder' && art === 'einsatz' ? [actor.id] : [];
    // Neue Instanz: noch kein Fahrzeug im Einsatz (auch kein Rest einer früheren Instanz gleichen Namens).
    const fresh = { ...DEFAULT_OPERATION, fahrzeuge: [] };
    this.operations.set(id, fresh);
    this.db.setKv(operationKey(id), JSON.stringify(fresh));
    this.write('instance', '', id, { name, art, beschreibung, mitglieder, erstelltVon: actor.id }, actor.id);
    this.ensureInstance(id);
    if (actor.role === 'fahnder') this.switchInstance(actor.id, id);
  }

  /** Jede Instanz hat ihren Lage-Layer und den allgemeinen Chatraum. */
  private ensureInstance(inst: string): void {
    const instance = this.get('instance', inst);
    const paket = instance?.data.art === 'paket';
    this.ensure('layer', inst, LAYER_LAGE, paket
      ? { name: 'Paket', art: 'lage', status: 'live', beschreibung: 'Inhalt des Pakets' }
      : { name: 'Lage', art: 'lage', status: 'live', beschreibung: 'Laufender Einsatz' });
    this.ensure('room', inst, ROOM_ALLGEMEIN, { name: 'Allgemein' });
  }

  private deleteInstance(actor: Actor, id: string): void {
    const instance = this.requireInstance(id);
    if (id === INSTANZ_HAUPT) throw new LageError('verboten', 'Die Standardinstanz kann nicht gelöscht werden.');
    this.requireMembership(actor, instance);
    for (const m of this.list('member')) if (m.data.instanz === id) this.switchInstance(m.id, INSTANZ_HAUPT);
    for (const kind of SCOPED_KINDS) for (const entity of this.entities.listIn(kind, id)) this.remove(kind, id, entity.id);
    this.tracks.clear(id);
    this.db.deleteKv(operationKey(id));
    this.operations.delete(id);
    this.remove('instance', '', id);
    this.db.audit(actor.id, 'instanz.geloescht', instance.data.name);
  }

  /** Aktive Instanz wechseln. Wer die A hält oder überschlagend fährt, gibt das in der bisherigen Instanz ab. */
  private switchInstance(memberId: string, inst: string): void {
    const member = this.get('member', memberId);
    if (!member) throw new LageError('unbekannt', 'Profil fehlt.');
    const previous = this.activeInstance(memberId);
    if (previous !== inst) {
      if (this.operationOf(previous).a?.memberId === memberId) this.updateOperation(previous, { a: null });
      this.leaveLeapfrog(previous, memberId);
      this.updateLeapfrog(previous);
      this.lastTrackPoint.delete(memberId);
    }
    this.write('member', '', memberId, { ...member.data, instanz: inst }, memberId);
    this.emit('event', { type: 'wechsel', memberId, inst });
  }

  /**
   * Übernimmt den Inhalt eines Pakets in eine Einsatz-Instanz. Die Objekte werden dabei kopiert und sind danach
   * eigenständige Objekte der Instanz; es gibt bewusst keine Verbindung zum Paket und kein Rückgängig.
   */
  private importPackage(actor: Actor, paketId: string, inst: string): void {
    const paket = this.requireInstance(paketId);
    if (paket.data.art !== 'paket') throw new LageError('ungueltig', 'Das ist kein Paket.');
    const target = this.requireInstance(inst);
    if (target.data.art !== 'einsatz') throw new LageError('ungueltig', 'Pakete werden in eine Einsatz-Instanz übernommen.');
    const newId = (() => {
      const map = new Map<string, string>();
      return (old: string) => {
        let next = map.get(old);
        if (!next) map.set(old, (next = randomId()));
        return next;
      };
    })();
    this.db.transaction(() => {
      for (const row of this.entities.listIn('target', paketId)) {
        const { data } = row;
        const bindung = data.bindung?.zielId ? { ...data.bindung, zielId: newId(data.bindung.zielId) } : data.bindung;
        this.write('target', inst, newId(row.id), { ...data, bindung }, actor.id);
      }
      for (const row of this.entities.listIn('annotation', paketId)) {
        const { data } = row;
        this.write('annotation', inst, newId(row.id), { ...data, layerId: LAYER_LAGE, gruppe: null }, actor.id);
      }
    });
    this.db.audit(actor.id, 'paket.uebernommen', `${paket.data.name} → ${target.data.name}`);
  }

  /**
   * Fortbewegung wechseln. Steigt der letzte Insasse aus einem Fahrzeug aus,
   * bleibt das Fahrzeug an dessen aktuellem Standort stehen.
   */
  private setMobility(actor: Actor, art: Fortbewegung, fahrzeugId: string | null, oepnv: OepnvFahrt | null, now: number): void {
    const member = this.get('member', actor.id);
    if (!member) throw new LageError('unbekannt', 'Profil fehlt.');
    // Ohne Fahrzeug-ID: generisches Fahrzeug (nicht in der Liste, z. B. Privatwagen oder Mietwagen).
    if (art === 'fahrzeug' && fahrzeugId) {
      const vehicle = this.get('vehicle', fahrzeugId);
      if (!vehicle) throw new LageError('unbekannt', 'Fahrzeug nicht gefunden.');
      if (!this.operationOf(this.activeInstance(actor.id)).fahrzeuge.includes(fahrzeugId)) {
        throw new LageError('konflikt', 'Dieses Fahrzeug ist in diesem Einsatz nicht aktiv geschaltet.');
      }
    }
    if (art === 'oepnv' && !oepnv) throw new LageError('ungueltig', 'Bitte Linie und Richtung auswählen.');

    const previousVehicle = member.data.fahrzeugId;
    const nextVehicle = art === 'fahrzeug' ? fahrzeugId : null;
    this.write(
      'member',
      '',
      member.id,
      {
        ...member.data,
        fortbewegung: art,
        fahrzeugId: nextVehicle,
        // Beim Wechsel in ein anderes Fahrzeug neu, sonst bleibt der Einstiegszeitpunkt.
        fahrzeugSeit: nextVehicle ? (nextVehicle === previousVehicle ? (member.data.fahrzeugSeit ?? now) : now) : null,
        oepnv: art === 'oepnv' ? oepnv : null,
      },
      actor.id,
    );

    if (previousVehicle && previousVehicle !== nextVehicle) {
      const vehicle = this.get('vehicle', previousVehicle);
      const position = this.positions.get(actor.id);
      if (vehicle && position && this.occupants(previousVehicle).length === 0) {
        this.write('vehicle', '', vehicle.id, { ...vehicle.data, abgestellt: { lat: position.lat, lon: position.lon, ts: now } }, actor.id);
      }
    }
    if (nextVehicle && nextVehicle !== previousVehicle) {
      const vehicle = this.get('vehicle', nextVehicle);
      if (vehicle?.data.abgestellt) this.write('vehicle', '', vehicle.id, { ...vehicle.data, abgestellt: null }, actor.id);
    }
    const inst = this.activeInstance(actor.id);
    if (this.operationOf(inst).a?.memberId === actor.id) this.updateLeapfrog(inst);
  }

  /** Ruhemodus: Wer sich abmeldet, gibt die A-Position ab und fährt nicht mehr überschlagend. */
  private setActive(actor: Actor, aktiv: boolean): void {
    const member = this.get('member', actor.id);
    if (!member) throw new LageError('unbekannt', 'Profil fehlt.');
    this.write('member', '', member.id, { ...member.data, aktiv }, actor.id);
    if (aktiv) return;
    const inst = this.activeInstance(actor.id);
    if (this.operationOf(inst).a?.memberId === actor.id) this.updateOperation(inst, { a: null });
    this.leaveLeapfrog(inst, actor.id);
    this.positions.delete(actor.id);
    this.updateLeapfrog(inst);
  }

  private leaveLeapfrog(inst: string, memberId: string): void {
    const current = this.operationOf(inst).ueberschlagen;
    if (!current.teilnehmer.includes(memberId)) return;
    const zuweisungen = { ...current.zuweisungen };
    delete zuweisungen[memberId];
    this.updateOperation(inst, { ueberschlagen: { ...current, teilnehmer: current.teilnehmer.filter((id) => id !== memberId), zuweisungen } });
  }

  /**
   * Überschlagendes Anfahren: Solange die A im ÖPNV fährt, wird jedem Teilnehmer eine der kommenden Haltestellen
   * zugewiesen. Bestehende Zuweisungen bleiben, solange die Haltestelle noch vor der A liegt; ist die A vorbei,
   * erhält der Teilnehmer die nächste noch unbesetzte Haltestelle dahinter.
   */
  private updateLeapfrog(inst: string): void {
    const op = this.operationOf(inst);
    const holder = op.a ? this.get('member', op.a.memberId) : null;
    const position = op.a ? this.positions.get(op.a.memberId) : undefined;
    const linienId = holder?.data.fortbewegung === 'oepnv' ? holder.data.oepnv?.linienId : undefined;
    const naechste = linienId && position ? this.upcomingStops(linienId, position, LEAPFROG_STOPS) : [];

    const key = (s: LeapfrogStop) => `${s.name}|${s.lat.toFixed(5)}|${s.lon.toFixed(5)}`;
    const upcomingKeys = naechste.map(key);
    const zuweisungen: Record<string, LeapfrogStop> = {};
    const taken = new Set<string>();
    const teilnehmer = op.ueberschlagen.teilnehmer.filter((id) => this.get('member', id)?.data.aktiv);
    for (const id of teilnehmer) {
      const current = op.ueberschlagen.zuweisungen[id];
      if (current && upcomingKeys.includes(key(current)) && !taken.has(key(current))) {
        zuweisungen[id] = current;
        taken.add(key(current));
      }
    }
    for (const id of teilnehmer) {
      if (zuweisungen[id]) continue;
      // Nächste freie Haltestelle hinter der am weitesten vorne liegenden bereits besetzten.
      const lastTaken = Math.max(-1, ...upcomingKeys.map((k, i) => (taken.has(k) ? i : -1)));
      const free = naechste.find((s, i) => i > lastTaken && !taken.has(key(s))) ?? naechste.find((s) => !taken.has(key(s)));
      if (!free) continue;
      zuweisungen[id] = free;
      taken.add(key(free));
    }
    const next = { teilnehmer, zuweisungen, naechste };
    if (JSON.stringify(next) !== JSON.stringify(op.ueberschlagen)) this.updateOperation(inst, { ueberschlagen: next });
  }

  private resetCoverage(inst: string): void {
    this.tracks.clear(inst);
    for (const m of this.list('member')) if (this.activeInstance(m.id) === inst) this.lastTrackPoint.delete(m.id);
    this.emit('event', { type: 'bestreifungReset', inst });
  }

  /**
   * Übernommene echte Fahrten: Zeiten an den Halten aus der Echtzeit nachführen. Zugeordnet wird über die Halte-ID,
   * bei älteren Markierungen ohne IDs über die Lage. Hat die Markierung eine Lebensdauer (nur Fahrzeug), wandert sie
   * mit der Ankunft am Endhalt mit: Das Fahrzeug verschwindet fünf Minuten nach der tatsächlichen Ankunft.
   */
  async refreshTrips(
    load: (tripId: string) => Promise<{ realTime?: boolean; stops: { stopId?: string; lat: number; lon: number; arr: number | null; dep: number | null }[] }>,
    now = Date.now(),
  ): Promise<number> {
    let updated = 0;
    for (const { inst, entity: a } of this.entities.listAll('annotation')) {
      const fahrt = a.data.fahrt;
      if (!fahrt || (a.data.typ !== 'oepnvfahrzeug' && a.data.typ !== 'oepnvlinie')) continue;
      const last = fahrt.zeiten.at(-1);
      if (last && last < now - 600_000) continue;
      try {
        const trip = await load(fahrt.id);
        const zeiten = a.data.punkte.map((p, i) => {
          const id = fahrt.haltIds?.[i];
          const match = (id ? trip.stops.find((s) => s.stopId === id) : undefined)
            ?? trip.stops.find((s) => Math.abs(s.lat - p.lat) < 0.0015 && Math.abs(s.lon - p.lon) < 0.0025);
          return match ? (match.dep ?? match.arr) : (fahrt.zeiten[i] ?? null);
        });
        if (!zeiten.some((z) => z !== null)) continue;
        const end = zeiten.filter((z): z is number => z !== null).at(-1);
        const ablauf = a.data.ablauf !== null && a.data.ablauf !== undefined && end ? end + 300_000 : a.data.ablauf;
        const current = this.get('annotation', a.id, inst || INSTANZ_HAUPT);
        if (!current) continue;
        const changed = JSON.stringify(zeiten) !== JSON.stringify(fahrt.zeiten) || ablauf !== a.data.ablauf || (trip.realTime ?? false) !== (fahrt.echtzeit ?? false);
        // Stand auch ohne Änderung festhalten, damit die App weiß, dass die Echtzeit frisch ist (höchstens minütlich).
        this.write('annotation', inst, a.id, { ...current.data, ablauf, fahrt: { ...fahrt, zeiten, echtzeit: trip.realTime ?? false, stand: now } }, 'system');
        if (changed) updated++;
      } catch {
        // Nicht erreichbar: beim nächsten Mal erneut.
      }
    }
    return updated;
  }

  /** Löscht Markierungen, deren Lebensdauer abgelaufen ist. Liefert die Anzahl. */
  expireAnnotations(now = Date.now()): number {
    let count = 0;
    for (const { inst, entity: a } of this.entities.listAll('annotation')) {
      if (a.data.ablauf !== null && a.data.ablauf !== undefined && a.data.ablauf <= now) {
        this.remove('annotation', inst, a.id);
        count++;
      }
    }
    return count;
  }

  private pruneTrack(now = Date.now()): void {
    this.tracks.pruneBefore(now - TRACK_RETENTION_MS);
  }

  /** Setzt die Lage einer Instanz zurück. Dauerhafte Orte, Profile, Fahrzeuge, Tracker und Chaträume bleiben erhalten. */
  private reset(actor: Actor, inst: string, includeTargets: boolean): void {
    const layers = this.list('layer', inst);
    const doomed = new Set(layers.filter((l) => l.data.status === 'live' && l.data.art !== 'dauerhaft').map((l) => l.id));
    for (const a of this.list('annotation', inst)) if (doomed.has(a.data.layerId)) this.remove('annotation', inst, a.id);
    for (const l of layers) if (doomed.has(l.id) && !PROTECTED_LAYERS.has(l.id)) this.remove('layer', inst, l.id);
    for (const m of this.list('message', inst)) this.remove('message', inst, m.id);
    if (includeTargets) for (const t of this.list('target', inst)) this.remove('target', inst, t.id);
    this.updateOperation(inst, { a: null, titel: '', hinweise: '', ueberschlagen: DEFAULT_OPERATION.ueberschlagen, sos: null });
    this.resetCoverage(inst);
    this.db.audit(actor.id, 'lage.zurueckgesetzt', includeTargets ? 'inklusive Zielpersonen' : '');
  }

  // ───────────────────────────── intern ─────────────────────────────

  /** Wohin ein Objekt gehört: instanzübergreifend (`''`) oder in die Instanz. */
  private scopeOf(kind: Kind, id: string, data: unknown, inst: string): string {
    if (!SCOPED_KINDS.has(kind)) return '';
    if (kind === 'layer' && id === LAYER_DAUERHAFT) return '';
    if (kind === 'annotation' && (data as { layerId?: string }).layerId === LAYER_DAUERHAFT) return '';
    return inst;
  }

  private occupants(vehicleId: string): Entity<'member'>[] {
    return this.list('member').filter((m) => m.data.fortbewegung === 'fahrzeug' && m.data.fahrzeugId === vehicleId);
  }

  /**
   * Wer den Standort eines Fahrzeugs vorgibt: wer zuerst eingestiegen ist und einen Standort hat, auch über
   * Instanzen hinweg. So zeigen nie zwei Telefone das Fahrzeug an verschiedenen Orten.
   */
  vehicleLeader(vehicleId: string): Entity<'member'> | null {
    const crew = this.occupants(vehicleId).filter((m) => this.positions.has(m.id));
    crew.sort((a, b) => (a.data.fahrzeugSeit ?? Number.MAX_SAFE_INTEGER) - (b.data.fahrzeugSeit ?? Number.MAX_SAFE_INTEGER) || a.id.localeCompare(b.id));
    return crew[0] ?? null;
  }

  private updateOperation(inst: string, patch: Partial<Operation>): void {
    const previous = this.operationOf(inst);
    // Wechselt oder endet die A, bleiben Ziele, die ihr gefolgt sind, an ihrer letzten Position stehen.
    if (previous.a && 'a' in patch && patch.a?.memberId !== previous.a.memberId) this.freezeTargetsAtA(inst, previous.a.memberId);
    const next = { ...previous, ...patch, rev: previous.rev + 1 };
    this.operations.set(inst, next);
    this.db.setKv(operationKey(inst), JSON.stringify(next));
    this.emit('event', { type: 'operation', operation: next, inst });
    if (next.a && next.a.memberId !== previous.a?.memberId) this.emit('event', { type: 'hinweis', inst, art: 'a', memberId: next.a.memberId });
    if (next.sos && next.sos.memberId !== previous.sos?.memberId) this.emit('event', { type: 'hinweis', inst, art: 'sos', memberId: next.sos.memberId });
  }

  /** Letzte A-Position als Standort aller Ziele speichern, die der A folgen (und nicht eingestiegen sind). */
  private freezeTargetsAtA(inst: string, memberId: string): void {
    const p = this.positions.get(memberId);
    if (!p) return;
    for (const t of this.entities.listIn('target', inst)) {
      if (t.data.quelle !== 'a' || (t.data.bindung && t.data.bindung.art !== 'fuss' && t.data.bindung.zielId)) continue;
      this.write('target', inst, t.id, { ...t.data, standort: { lat: p.lat, lon: p.lon, ts: p.ts } }, 'system');
    }
  }

  private write<K extends Kind>(kind: K, inst: string, id: string, data: EntityData<K>, actorId: string): Entity<K> {
    const entity = this.entities.write(kind, inst, id, data, actorId);
    this.emit('event', { type: 'put', kind, entity: entity as Entity, inst });
    return entity;
  }

  private remove(kind: Kind, inst: string, id: string): void {
    this.entities.remove(kind, inst, id);
    this.emit('event', { type: 'del', kind, id, inst });
  }

  private ensure<K extends Kind>(kind: K, inst: string, id: string, data: EntityData<K>): void {
    if (!this.entities.exists(kind, inst, id)) this.write(kind, inst, id, data, 'system');
  }

  private trimMessages(inst: string, roomId: string): void {
    const messages = this.list('message', inst).filter((m) => m.data.roomId === roomId);
    if (messages.length <= MAX_MESSAGES_PER_ROOM) return;
    messages.sort((a, b) => a.updatedAt - b.updatedAt);
    for (const old of messages.slice(0, messages.length - MAX_MESSAGES_PER_ROOM)) this.remove('message', inst, old.id);
  }

  private persistTrackerPositions(): void {
    this.db.setKv('trackerPositions', JSON.stringify(Object.fromEntries(this.trackerPositions)));
  }
}

/** Woher der Standort eines Ziels kommt; ohne ausdrückliche Wahl der Tracker, sofern verbunden. */
function sourceOf(t: EntityData<'target'>): 'hand' | 'tracker' | 'a' {
  return t.quelle ?? (t.trackerId ? 'tracker' : 'hand');
}

function targetName(t: EntityData<'target'>): string {
  return t.bezeichnung || [t.vorname, t.nachname].filter(Boolean).join(' ') || t.kennzeichen || 'Ziel';
}

/** Die Hauptinstanz speichert ihren Einsatzzustand wie bisher unter `operation`. */
function operationKey(inst: string): string {
  return inst === INSTANZ_HAUPT ? 'operation' : `operation@${inst}`;
}

function randomId(length = 20): string {
  return randomBytes(Math.ceil(length * 0.75)).toString('base64url').slice(0, length);
}


