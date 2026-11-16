import { EventEmitter } from 'node:events';
import type { Database } from './db.js';
import { distanceMeters } from './geo.js';
import {
  commandArgs,
  ENTITY_SCHEMAS,
  KINDS,
  type CommandName,
  type Entity,
  type EntityData,
  type Fortbewegung,
  type Kind,
  type LeapfrogStop,
  type OepnvFahrt,
  type Operation,
  type Position,
  normalizeCallsign,
} from './schemas.js';

export type Role = 'fahnder' | 'zentrale';
export interface Actor {
  id: string;
  role: Role;
}

export type LageEvent =
  | { type: 'put'; kind: Kind; entity: Entity }
  | { type: 'del'; kind: Kind; id: string }
  | { type: 'operation'; operation: Operation }
  | { type: 'pos'; id: string; p: Position }
  | { type: 'tpos'; id: string; p: Position }
  | { type: 'bestreifungReset' }
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

const DEFAULT_OPERATION: Operation = {
  funkkanal: null,
  titel: '',
  hinweise: '',
  a: null,
  ueberschlagen: { teilnehmer: [], zuweisungen: {}, naechste: [] },
  rev: 0,
};

/** Liefert die kommenden Halte einer ÖPNV-Linie ab einem Standort (siehe oepnv.ts). */
export type UpcomingStops = (linienId: string, position: { lat: number; lon: number }, count: number) => LeapfrogStop[];

/**
 * Die laufende Lage: alle gemeinsam bearbeiteten Objekte, der Einsatzzustand und die Live-Positionen.
 * Es gibt bewusst genau eine Lage je Server, damit niemand versehentlich in einem anderen Arbeitsraum landet.
 * Vorbereitete Inhalte entstehen als Entwurfs-Ebenen und werden bei Bedarf in die Lage geladen.
 */
export class Lage extends EventEmitter<{ event: [LageEvent] }> {
  private operationState: Operation;
  private readonly positions = new Map<string, Position>();
  private readonly trackerPositions = new Map<string, Position>();
  private readonly lastTrackPoint = new Map<string, Position>();

  constructor(
    private readonly db: Database,
    private readonly upcomingStops: UpcomingStops = () => [],
  ) {
    super();
    const stored = db.getKv('operation');
    const parsed = stored ? (JSON.parse(stored) as Partial<Operation>) : {};
    this.operationState = {
      funkkanal: parsed.funkkanal ?? null,
      titel: parsed.titel ?? '',
      hinweise: parsed.hinweise ?? '',
      a: parsed.a ?? null,
      ueberschlagen: parsed.ueberschlagen ?? DEFAULT_OPERATION.ueberschlagen,
      rev: parsed.rev ?? 0,
    };
    const trackerPos = db.getKv('trackerPositions');
    if (trackerPos) for (const [id, p] of Object.entries(JSON.parse(trackerPos) as Record<string, Position>)) this.trackerPositions.set(id, p);
    this.migrate();
    this.ensure('layer', LAYER_LAGE, { name: 'Lage', art: 'lage', status: 'live', beschreibung: 'Laufender Einsatz' });
    this.ensure('layer', LAYER_DAUERHAFT, { name: 'Dauerhafte Orte', art: 'dauerhaft', status: 'live', beschreibung: 'Bleibt beim Zurücksetzen erhalten' });
    this.ensure('room', ROOM_ALLGEMEIN, { name: 'Allgemein' });
    this.pruneTrack();
  }

  /**
   * Bringt gespeicherte Objekte auf den aktuellen Stand des Datenmodells.
   * Fehlende Felder erhalten ihre Vorgabewerte; umbenannte Felder werden übertragen.
   */
  private migrate(): void {
    const rows = this.db.sql.prepare('SELECT kind, id, data FROM entities').all() as unknown as { kind: string; id: string; data: string }[];
    const trackerNames = new Map(
      rows.filter((r) => r.kind === 'tracker').map((r) => [r.id, String((JSON.parse(r.data) as { name?: unknown }).name ?? '')]),
    );
    for (const row of rows) {
      if (!(KINDS as string[]).includes(row.kind)) continue;
      const raw = JSON.parse(row.data) as Record<string, unknown>;
      if (row.kind === 'member') {
        raw.spitzname ??= raw.funkrufname ?? raw.name;
        if (raw.fahrzeugId && !raw.fortbewegung) raw.fortbewegung = 'fahrzeug';
        delete raw.funkrufname;
      }
      if (row.kind === 'vehicle') {
        if (!raw.funkrufname) raw.funkrufname = String(raw.bezeichnung || 'Fahrzeug').slice(0, 20);
        // Aus 0.1 übernommene Fahrzeuge trugen Marke und Modell als Namen. Hat der verbundene Tracker einen
        // gültigen Funkrufnamen, gilt dieser.
        if (normalizeCallsign(String(raw.funkrufname)) === null && typeof raw.trackerId === 'string') {
          const callsign = normalizeCallsign(trackerNames.get(raw.trackerId) ?? '');
          if (callsign) raw.funkrufname = callsign;
        }
      }
      const parsed = ENTITY_SCHEMAS[row.kind as Kind].safeParse(raw);
      if (!parsed.success) continue;
      const next = JSON.stringify(parsed.data);
      if (next !== row.data) this.db.sql.prepare('UPDATE entities SET data = ? WHERE kind = ? AND id = ?').run(next, row.kind, row.id);
    }
  }

  // ───────────────────────────── Lesen ─────────────────────────────

  get operation(): Operation {
    return this.operationState;
  }

  list<K extends Kind>(kind: K): Entity<K>[] {
    const rows = this.db.sql.prepare('SELECT id, rev, data, updated_at, updated_by FROM entities WHERE kind = ?').all(kind) as unknown as EntityRow[];
    return rows.map((row) => fromRow<K>(row));
  }

  get<K extends Kind>(kind: K, id: string): Entity<K> | null {
    const row = this.db.sql.prepare('SELECT id, rev, data, updated_at, updated_by FROM entities WHERE kind = ? AND id = ?').get(kind, id) as
      | EntityRow
      | undefined;
    return row ? fromRow<K>(row) : null;
  }

  positionOf(memberId: string): Position | undefined {
    return this.positions.get(memberId);
  }

  /** Vollständiger Zustand für einen neu verbundenen Client. */
  snapshot() {
    return {
      members: this.list('member'),
      vehicles: this.list('vehicle'),
      annotations: this.list('annotation'),
      targets: this.list('target'),
      trackers: this.list('tracker'),
      layers: this.list('layer'),
      rooms: this.list('room'),
      messages: this.list('message').sort((a, b) => a.updatedAt - b.updatedAt),
      operation: this.operationState,
      positions: [...this.positions].map(([id, p]) => ({ id, p })),
      trackerPositions: [...this.trackerPositions].map(([id, p]) => ({ id, p })),
    };
  }

  coverage(): { memberId: string; punkte: [number, number, number][] }[] {
    const rows = this.db.sql.prepare('SELECT member_id, ts, lat, lon FROM track ORDER BY member_id, ts').all() as unknown as {
      member_id: string;
      ts: number;
      lat: number;
      lon: number;
    }[];
    const byMember = new Map<string, [number, number, number][]>();
    for (const row of rows) {
      let list = byMember.get(row.member_id);
      if (!list) byMember.set(row.member_id, (list = []));
      list.push([row.lat, row.lon, row.ts]);
    }
    return [...byMember].map(([memberId, punkte]) => ({ memberId, punkte }));
  }

  // ───────────────────────────── Objekte schreiben ─────────────────────────────

  put(actor: Actor, kind: Kind, id: string, raw: unknown): Entity {
    const parsed = ENTITY_SCHEMAS[kind].safeParse(raw);
    if (!parsed.success) throw new LageError('ungueltig', parsed.error.issues[0]?.message ?? 'Ungültige Eingabe');
    let data = parsed.data as EntityData<Kind>;
    const existing = this.get(kind, id);

    switch (kind) {
      case 'member': {
        if (actor.role !== 'zentrale' && actor.id !== id) throw new LageError('verboten', 'Nur das eigene Profil ist änderbar.');
        // Aktivität, Fortbewegung und Fahrzeug ändern sich ausschließlich über Kommandos.
        const previous = (existing as Entity<'member'> | null)?.data;
        const next = data as EntityData<'member'>;
        data = {
          ...next,
          aktiv: previous?.aktiv ?? true,
          fortbewegung: previous?.fortbewegung ?? 'fuss',
          fahrzeugId: previous?.fahrzeugId ?? null,
          oepnv: previous?.oepnv ?? null,
        };
        break;
      }
      case 'message': {
        if (existing) throw new LageError('verboten', 'Nachrichten können nicht geändert werden.');
        if (!this.get('room', (data as EntityData<'message'>).roomId)) throw new LageError('ungueltig', 'Chatraum existiert nicht.');
        break;
      }
      case 'annotation':
        if (!this.get('layer', (data as EntityData<'annotation'>).layerId)) throw new LageError('ungueltig', 'Ebene existiert nicht.');
        break;
      case 'layer': {
        const next = data as EntityData<'layer'>;
        if (PROTECTED_LAYERS.has(id)) {
          const current = (existing as Entity<'layer'>).data;
          data = { ...next, art: current.art, status: 'live' };
        } else if (next.art === 'lage' || next.art === 'dauerhaft') {
          throw new LageError('ungueltig', 'Diese Ebenenart ist fest vergeben.');
        }
        break;
      }
      case 'vehicle': {
        const next = data as EntityData<'vehicle'>;
        // Wer in einem abgeschalteten Fahrzeug saß, ist danach zu Fuß unterwegs.
        if (!next.aktiv) for (const m of this.occupants(id)) this.write('member', m.id, { ...m.data, fortbewegung: 'fuss', fahrzeugId: null }, actor.id);
        break;
      }
      default:
        break;
    }

    const entity = this.write(kind, id, data, actor.id);
    if (kind === 'message') this.trimMessages((data as EntityData<'message'>).roomId);
    return entity;
  }

  del(actor: Actor, kind: Kind, id: string): void {
    if (!this.get(kind, id)) return;
    switch (kind) {
      case 'member':
        if (actor.role !== 'zentrale') throw new LageError('verboten', 'Profile entfernt nur die Kommandozentrale.');
        if (this.operationState.a?.memberId === id) this.updateOperation({ a: null });
        this.positions.delete(id);
        this.leaveLeapfrog(id);
        break;
      case 'message': {
        const message = this.get('message', id)!;
        if (actor.role !== 'zentrale' && message.updatedBy !== actor.id) throw new LageError('verboten', 'Nur eigene Nachrichten können gelöscht werden.');
        break;
      }
      case 'room':
        for (const m of this.list('message')) if (m.data.roomId === id) this.remove('message', m.id);
        // Der allgemeine Chatraum bleibt bestehen und wird nur geleert.
        if (id === ROOM_ALLGEMEIN) return;
        break;
      case 'layer':
        if (PROTECTED_LAYERS.has(id)) throw new LageError('verboten', 'Diese Ebene kann nicht gelöscht werden.');
        for (const a of this.list('annotation')) if (a.data.layerId === id) this.remove('annotation', a.id);
        break;
      case 'vehicle':
        for (const m of this.occupants(id)) this.write('member', m.id, { ...m.data, fortbewegung: 'fuss', fahrzeugId: null }, actor.id);
        break;
      case 'tracker':
        for (const t of this.list('target')) if (t.data.trackerId === id) this.write('target', t.id, { ...t.data, trackerId: null }, actor.id);
        for (const v of this.list('vehicle')) if (v.data.trackerId === id) this.write('vehicle', v.id, { ...v.data, trackerId: null }, actor.id);
        for (const a of this.list('annotation')) if (a.data.trackerId === id) this.write('annotation', a.id, { ...a.data, trackerId: null }, actor.id);
        this.trackerPositions.delete(id);
        this.persistTrackerPositions();
        break;
      default:
        break;
    }
    this.remove(kind, id);
  }

  // ───────────────────────────── Positionen ─────────────────────────────

  reportPosition(memberId: string, p: Position): void {
    const member = this.get('member', memberId);
    // Im Ruhemodus wird kein Standort geteilt.
    if (member && !member.data.aktiv) return;
    this.positions.set(memberId, p);
    this.emit('event', { type: 'pos', id: memberId, p });
    this.recordTrack(memberId, p);
    if (this.operationState.a?.memberId === memberId) this.updateLeapfrog();
  }

  /** Bestreifung: Jeder Weg wird aufgezeichnet; wer sie sehen möchte, schaltet die Anzeige in seiner App ein. */
  private recordTrack(memberId: string, p: Position): void {
    if ((p.acc ?? 0) > TRACK_MAX_ACCURACY_M) return;
    const last = this.lastTrackPoint.get(memberId);
    if (last && (p.ts <= last.ts || distanceMeters(last, p) < TRACK_MIN_DISTANCE_M)) return;
    this.lastTrackPoint.set(memberId, p);
    this.db.sql.prepare('INSERT OR IGNORE INTO track (member_id, ts, lat, lon) VALUES (?, ?, ?, ?)').run(memberId, p.ts, p.lat, p.lon);
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
    return true;
  }

  memberWentOffline(memberId: string): void {
    this.lastTrackPoint.delete(memberId);
  }

  // ───────────────────────────── Kommandos ─────────────────────────────

  command(actor: Actor, name: CommandName, rawArgs: unknown): void {
    const parsed = commandArgs[name].safeParse(rawArgs ?? {});
    if (!parsed.success) throw new LageError('ungueltig', parsed.error.issues[0]?.message ?? 'Ungültige Eingabe');
    const args = (parsed.data ?? {}) as Record<string, unknown>;
    const now = Date.now();
    const op = this.operationState;

    switch (name) {
      case 'a.uebernehmen': {
        if (actor.role !== 'fahnder') throw new LageError('verboten', 'Die A-Position kann nur ein Fahnder übernehmen.');
        const me = this.get('member', actor.id);
        if (!me) throw new LageError('unbekannt', 'Profil fehlt.');
        if (!me.data.aktiv) throw new LageError('konflikt', 'Im Ruhemodus kann die A-Position nicht übernommen werden.');
        this.leaveLeapfrog(actor.id);
        this.updateOperation({ a: { memberId: actor.id, seit: now } });
        this.updateLeapfrog();
        break;
      }
      case 'a.freigeben':
        if (op.a && (op.a.memberId === actor.id || actor.role === 'zentrale')) {
          this.updateOperation({ a: null });
          this.updateLeapfrog();
        }
        break;
      case 'funkkanal.setzen':
        this.updateOperation({ funkkanal: args.kanal as string | null });
        break;
      case 'lage.setzen':
        this.updateOperation({ titel: args.titel as string, hinweise: args.hinweise as string });
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
          this.updateOperation({ ueberschlagen: { ...op.ueberschlagen, teilnehmer: [...op.ueberschlagen.teilnehmer, actor.id] } });
          this.updateLeapfrog();
        }
        break;
      }
      case 'ueberschlagen.verlassen':
        this.leaveLeapfrog(actor.id);
        break;
      case 'tracker.intervall': {
        const tracker = this.get('tracker', args.trackerId as string);
        if (!tracker) throw new LageError('unbekannt', 'Tracker existiert nicht.');
        if (tracker.data.anbieter !== 'sinotrack') throw new LageError('konflikt', 'Das Sendeintervall von PAJ-Trackern wird im PAJ-Portal eingestellt.');
        const sekunden = args.sekunden as number;
        this.write('tracker', tracker.id, { ...tracker.data, intervall: sekunden }, actor.id);
        this.emit('event', { type: 'trackerIntervall', anbieter: tracker.data.anbieter, kennung: tracker.data.kennung, sekunden });
        break;
      }
      case 'bestreifung.zuruecksetzen':
        this.resetCoverage();
        break;
      case 'lage.zuruecksetzen':
        this.reset(actor, args.ziele as boolean);
        break;
    }
    this.db.audit(actor.id, `cmd:${name}`);
  }

  /**
   * Fortbewegung wechseln. Steigt der letzte Insasse aus einem Fahrzeug aus,
   * bleibt das Fahrzeug an dessen aktuellem Standort stehen.
   */
  private setMobility(actor: Actor, art: Fortbewegung, fahrzeugId: string | null, oepnv: OepnvFahrt | null, now: number): void {
    const member = this.get('member', actor.id);
    if (!member) throw new LageError('unbekannt', 'Profil fehlt.');
    if (art === 'fahrzeug') {
      const vehicle = fahrzeugId ? this.get('vehicle', fahrzeugId) : null;
      if (!vehicle) throw new LageError('unbekannt', 'Bitte ein Fahrzeug auswählen.');
      if (!vehicle.data.aktiv) throw new LageError('konflikt', 'Dieses Fahrzeug ist für den Einsatz nicht aktiv geschaltet.');
    }
    if (art === 'oepnv' && !oepnv) throw new LageError('ungueltig', 'Bitte Linie und Richtung auswählen.');

    const previousVehicle = member.data.fahrzeugId;
    const nextVehicle = art === 'fahrzeug' ? fahrzeugId : null;
    this.write(
      'member',
      member.id,
      { ...member.data, fortbewegung: art, fahrzeugId: nextVehicle, oepnv: art === 'oepnv' ? oepnv : null },
      actor.id,
    );

    if (previousVehicle && previousVehicle !== nextVehicle) {
      const vehicle = this.get('vehicle', previousVehicle);
      const position = this.positions.get(actor.id);
      if (vehicle && position && this.occupants(previousVehicle).length === 0) {
        this.write('vehicle', vehicle.id, { ...vehicle.data, abgestellt: { lat: position.lat, lon: position.lon, ts: now } }, actor.id);
      }
    }
    if (nextVehicle && nextVehicle !== previousVehicle) {
      const vehicle = this.get('vehicle', nextVehicle);
      if (vehicle?.data.abgestellt) this.write('vehicle', vehicle.id, { ...vehicle.data, abgestellt: null }, actor.id);
    }
    if (this.operationState.a?.memberId === actor.id) this.updateLeapfrog();
  }

  /** Ruhemodus: Wer sich abmeldet, gibt die A-Position ab und fährt nicht mehr überschlagend. */
  private setActive(actor: Actor, aktiv: boolean): void {
    const member = this.get('member', actor.id);
    if (!member) throw new LageError('unbekannt', 'Profil fehlt.');
    this.write('member', member.id, { ...member.data, aktiv }, actor.id);
    if (aktiv) return;
    if (this.operationState.a?.memberId === actor.id) this.updateOperation({ a: null });
    this.leaveLeapfrog(actor.id);
    this.positions.delete(actor.id);
    this.updateLeapfrog();
  }

  private leaveLeapfrog(memberId: string): void {
    const current = this.operationState.ueberschlagen;
    if (!current.teilnehmer.includes(memberId)) return;
    const zuweisungen = { ...current.zuweisungen };
    delete zuweisungen[memberId];
    this.updateOperation({ ueberschlagen: { ...current, teilnehmer: current.teilnehmer.filter((id) => id !== memberId), zuweisungen } });
  }

  /**
   * Überschlagendes Anfahren: Solange die A im ÖPNV fährt, wird jedem Teilnehmer eine der kommenden Haltestellen
   * zugewiesen. Bestehende Zuweisungen bleiben, solange die Haltestelle noch vor der A liegt; ist die A vorbei,
   * erhält der Teilnehmer die nächste noch unbesetzte Haltestelle dahinter.
   */
  private updateLeapfrog(): void {
    const op = this.operationState;
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
    if (JSON.stringify(next) !== JSON.stringify(op.ueberschlagen)) this.updateOperation({ ueberschlagen: next });
  }

  private resetCoverage(): void {
    this.db.sql.exec('DELETE FROM track');
    this.lastTrackPoint.clear();
    this.emit('event', { type: 'bestreifungReset' });
  }

  private pruneTrack(now = Date.now()): void {
    this.db.sql.prepare('DELETE FROM track WHERE ts < ?').run(now - TRACK_RETENTION_MS);
  }

  /** Setzt die laufende Lage zurück. Dauerhafte Orte, Profile, Fahrzeuge, Tracker und Chaträume bleiben erhalten. */
  private reset(actor: Actor, includeTargets: boolean): void {
    const layers = this.list('layer');
    const doomed = new Set(layers.filter((l) => l.data.status === 'live' && l.data.art !== 'dauerhaft').map((l) => l.id));
    for (const a of this.list('annotation')) if (doomed.has(a.data.layerId)) this.remove('annotation', a.id);
    for (const l of layers) if (doomed.has(l.id) && !PROTECTED_LAYERS.has(l.id)) this.remove('layer', l.id);
    for (const m of this.list('message')) this.remove('message', m.id);
    if (includeTargets) for (const t of this.list('target')) this.remove('target', t.id);
    this.updateOperation({ a: null, titel: '', hinweise: '', ueberschlagen: DEFAULT_OPERATION.ueberschlagen });
    this.resetCoverage();
    this.db.audit(actor.id, 'lage.zurueckgesetzt', includeTargets ? 'inklusive Zielpersonen' : '');
  }

  // ───────────────────────────── intern ─────────────────────────────

  private occupants(vehicleId: string): Entity<'member'>[] {
    return this.list('member').filter((m) => m.data.fortbewegung === 'fahrzeug' && m.data.fahrzeugId === vehicleId);
  }

  private updateOperation(patch: Partial<Operation>): void {
    this.operationState = { ...this.operationState, ...patch, rev: this.operationState.rev + 1 };
    this.db.setKv('operation', JSON.stringify(this.operationState));
    this.emit('event', { type: 'operation', operation: this.operationState });
  }

  private write<K extends Kind>(kind: K, id: string, data: EntityData<K>, actorId: string): Entity<K> {
    const now = Date.now();
    const row = this.db.sql
      .prepare(
        `INSERT INTO entities (kind, id, rev, data, updated_at, updated_by) VALUES (?, ?, 1, ?, ?, ?)
         ON CONFLICT (kind, id) DO UPDATE SET rev = rev + 1, data = excluded.data, updated_at = excluded.updated_at, updated_by = excluded.updated_by
         RETURNING rev`,
      )
      .get(kind, id, JSON.stringify(data), now, actorId) as { rev: number };
    const entity: Entity<K> = { id, rev: row.rev, updatedAt: now, updatedBy: actorId, data };
    this.emit('event', { type: 'put', kind, entity: entity as Entity });
    return entity;
  }

  private remove(kind: Kind, id: string): void {
    this.db.sql.prepare('DELETE FROM entities WHERE kind = ? AND id = ?').run(kind, id);
    this.emit('event', { type: 'del', kind, id });
  }

  private ensure<K extends Kind>(kind: K, id: string, data: EntityData<K>): void {
    if (!this.get(kind, id)) this.write(kind, id, data, 'system');
  }

  private trimMessages(roomId: string): void {
    const messages = this.list('message').filter((m) => m.data.roomId === roomId);
    if (messages.length <= MAX_MESSAGES_PER_ROOM) return;
    messages.sort((a, b) => a.updatedAt - b.updatedAt);
    for (const old of messages.slice(0, messages.length - MAX_MESSAGES_PER_ROOM)) this.remove('message', old.id);
  }

  private persistTrackerPositions(): void {
    this.db.setKv('trackerPositions', JSON.stringify(Object.fromEntries(this.trackerPositions)));
  }
}

interface EntityRow {
  id: string;
  rev: number;
  data: string;
  updated_at: number;
  updated_by: string;
}

function fromRow<K extends Kind>(row: EntityRow): Entity<K> {
  return { id: row.id, rev: row.rev, updatedAt: row.updated_at, updatedBy: row.updated_by, data: JSON.parse(row.data) as EntityData<K> };
}

export { KINDS };
