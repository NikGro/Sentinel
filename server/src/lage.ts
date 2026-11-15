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
  type Kind,
  type Modus,
  type Operation,
  type Position,
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
  /** Eine Ebene wurde für die Fahnder sichtbar (in die Lage geladen) oder unsichtbar (zurück in den Entwurf). */
  | { type: 'layerVisibility'; layerId: string; live: boolean }
  | { type: 'bestreifungReset' };

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
const PROTECTED_LAYERS = new Set([LAYER_LAGE, LAYER_DAUERHAFT]);
const MAX_MESSAGES = 500;
/** Bestreifung: Punkt nur speichern, wenn er sich deutlich vom letzten unterscheidet und brauchbar genau ist. */
const TRACK_MIN_DISTANCE_M = 12;
const TRACK_MAX_ACCURACY_M = 60;

const DEFAULT_OPERATION: Operation = {
  modus: 'observation',
  funkkanal: null,
  titel: '',
  hinweise: '',
  a: null,
  lkp: null,
  bestreifungSeit: null,
  rev: 0,
};

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

  constructor(private readonly db: Database) {
    super();
    const stored = db.getKv('operation');
    this.operationState = stored ? { ...DEFAULT_OPERATION, ...(JSON.parse(stored) as Operation) } : { ...DEFAULT_OPERATION };
    const trackerPos = db.getKv('trackerPositions');
    if (trackerPos) for (const [id, p] of Object.entries(JSON.parse(trackerPos) as Record<string, Position>)) this.trackerPositions.set(id, p);
    this.ensureLayer(LAYER_LAGE, { name: 'Lage', art: 'lage', status: 'live', beschreibung: 'Laufender Einsatz' });
    this.ensureLayer(LAYER_DAUERHAFT, { name: 'Dauerhafte Orte', art: 'dauerhaft', status: 'live', beschreibung: 'Bleibt beim Zurücksetzen erhalten' });
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

  isLayerLive(layerId: string): boolean {
    return this.get('layer', layerId)?.data.status === 'live';
  }

  /** Vollständiger Zustand für einen neu verbundenen Client. Fahnder sehen keine Entwürfe. */
  snapshot(role: Role) {
    const layers = this.list('layer').filter((l) => role === 'zentrale' || l.data.status === 'live');
    const visible = new Set(layers.map((l) => l.id));
    return {
      members: this.list('member'),
      vehicles: this.list('vehicle'),
      annotations: this.list('annotation').filter((a) => visible.has(a.data.layerId)),
      targets: this.list('target'),
      trackers: this.list('tracker'),
      layers,
      messages: this.list('message').sort((a, b) => a.updatedAt - b.updatedAt),
      operation: this.operationState,
      positions: [...this.positions].map(([id, p]) => ({ id, p })),
      trackerPositions: [...this.trackerPositions].map(([id, p]) => ({ id, p })),
    };
  }

  coverage(): { memberId: string; punkte: [number, number, number][] }[] {
    const since = this.operationState.bestreifungSeit ?? 0;
    const rows = this.db.sql.prepare('SELECT member_id, ts, lat, lon FROM track WHERE ts >= ? ORDER BY member_id, ts').all(since) as unknown as {
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
        // Die Fahrzeugbesetzung ändert sich ausschließlich über Kommandos.
        const previous = existing as Entity<'member'> | null;
        data = { ...(data as EntityData<'member'>), fahrzeugId: previous?.data.fahrzeugId ?? null };
        break;
      }
      case 'message':
        if (existing) throw new LageError('verboten', 'Nachrichten können nicht geändert werden.');
        break;
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
      default:
        break;
    }

    const entity = this.write(kind, id, data, actor.id);
    if (kind === 'layer') {
      const before = (existing as Entity<'layer'> | null)?.data.status;
      const after = (data as EntityData<'layer'>).status;
      if (before !== undefined && before !== after) this.emit('event', { type: 'layerVisibility', layerId: id, live: after === 'live' });
    }
    if (kind === 'message') this.trimMessages();
    return entity;
  }

  del(actor: Actor, kind: Kind, id: string): void {
    if (!this.get(kind, id)) return;
    switch (kind) {
      case 'member':
        if (actor.role !== 'zentrale') throw new LageError('verboten', 'Profile entfernt nur die Kommandozentrale.');
        if (this.operationState.a?.memberId === id) this.updateOperation({ a: null });
        this.positions.delete(id);
        break;
      case 'message':
        throw new LageError('verboten', 'Nachrichten können nicht gelöscht werden.');
      case 'layer':
        if (PROTECTED_LAYERS.has(id)) throw new LageError('verboten', 'Diese Ebene kann nicht gelöscht werden.');
        for (const a of this.list('annotation')) if (a.data.layerId === id) this.remove('annotation', a.id);
        break;
      case 'vehicle':
        for (const m of this.list('member')) if (m.data.fahrzeugId === id) this.write('member', m.id, { ...m.data, fahrzeugId: null }, actor.id);
        break;
      case 'tracker':
        for (const t of this.list('target')) if (t.data.trackerId === id) this.write('target', t.id, { ...t.data, trackerId: null }, actor.id);
        for (const v of this.list('vehicle')) if (v.data.trackerId === id) this.write('vehicle', v.id, { ...v.data, trackerId: null }, actor.id);
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
    this.positions.set(memberId, p);
    this.emit('event', { type: 'pos', id: memberId, p });
    if (this.operationState.modus !== 'fahndung') return;
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
    this.followTargetTracker(tracker.id, p);
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
      case 'modus.setzen':
        this.setModus((args as { modus: Modus }).modus, now);
        break;
      case 'a.uebernehmen':
        if (actor.role !== 'fahnder') throw new LageError('verboten', 'Die A-Position kann nur ein Fahnder übernehmen.');
        if (op.modus !== 'observation') throw new LageError('konflikt', 'Die A-Position gibt es nur im Observationsmodus.');
        this.updateOperation({ a: { memberId: actor.id, seit: now } });
        break;
      case 'a.freigeben':
        if (op.a && (op.a.memberId === actor.id || actor.role === 'zentrale')) this.updateOperation({ a: null });
        break;
      case 'funkkanal.setzen':
        this.updateOperation({ funkkanal: (args as { kanal: string | null }).kanal });
        break;
      case 'lage.setzen': {
        const { titel, hinweise } = args as { titel: string; hinweise: string };
        this.updateOperation({ titel, hinweise });
        break;
      }
      case 'lkp.setzen': {
        const a = args as { lat: number; lon: number; ts?: number; targetId?: string | null };
        this.updateOperation({ lkp: { lat: a.lat, lon: a.lon, ts: Math.min(a.ts ?? now, now), quelle: 'manuell', targetId: a.targetId ?? null } });
        break;
      }
      case 'lkp.loeschen':
        this.updateOperation({ lkp: null });
        break;
      case 'fahrzeug.einsteigen':
        this.boardVehicle(actor, (args as { fahrzeugId: string }).fahrzeugId);
        break;
      case 'fahrzeug.aussteigen':
        this.leaveVehicle(actor, now);
        break;
      case 'bestreifung.zuruecksetzen':
        this.resetCoverage(now);
        break;
      case 'lage.zuruecksetzen':
        this.reset(actor, (args as { ziele: boolean }).ziele, now);
        break;
    }
    this.db.audit(actor.id, `cmd:${name}`);
  }

  /**
   * Moduswechsel ohne Informationsverlust:
   * - Observation → Fahndung: Die A-Position wird zum letzten bekannten Standort (Sichtkontakt abgerissen),
   *   die Bestreifungs-Aufzeichnung beginnt bzw. läuft weiter.
   * - Fahndung → Observation: Letzter Standort und Bestreifung bleiben gespeichert, werden aber nur noch blass bzw. gar nicht gezeigt.
   * - Oberflächenfahndung: weder A-Position noch Weg-Zeit-Berechnung, nur Kräfte und Markierungen.
   */
  private setModus(modus: Modus, now: number): void {
    const op = this.operationState;
    if (op.modus === modus) return;
    const patch: Partial<Operation> = { modus };
    if (modus !== 'observation' && op.a) {
      const position = this.positions.get(op.a.memberId);
      if (modus === 'fahndung' && position) {
        patch.lkp = { lat: position.lat, lon: position.lon, ts: now, quelle: 'a', targetId: op.lkp?.targetId ?? null };
      }
      patch.a = null;
    }
    if (modus === 'fahndung' && op.bestreifungSeit === null) patch.bestreifungSeit = now;
    this.updateOperation(patch);
  }

  /** Im Fahndungsmodus folgt der letzte bekannte Standort automatisch einem Tracker an der Zielperson. */
  private followTargetTracker(trackerId: string, p: Position): void {
    const op = this.operationState;
    if (op.modus !== 'fahndung') return;
    if (op.lkp && op.lkp.quelle !== 'tracker') return;
    const target = this.list('target').find((t) => t.data.trackerId === trackerId);
    if (!target) return;
    if (op.lkp && p.ts - op.lkp.ts < 30_000 && distanceMeters(op.lkp, p) < 25) return;
    this.updateOperation({ lkp: { lat: p.lat, lon: p.lon, ts: p.ts, quelle: 'tracker', targetId: target.id } });
  }

  private boardVehicle(actor: Actor, fahrzeugId: string): void {
    const member = this.get('member', actor.id);
    if (!member) throw new LageError('unbekannt', 'Profil fehlt.');
    if (!this.get('vehicle', fahrzeugId)) throw new LageError('unbekannt', 'Fahrzeug existiert nicht.');
    this.write('member', member.id, { ...member.data, fahrzeugId }, actor.id);
  }

  private leaveVehicle(actor: Actor, now: number): void {
    const member = this.get('member', actor.id);
    const fahrzeugId = member?.data.fahrzeugId;
    if (!member || !fahrzeugId) return;
    this.write('member', member.id, { ...member.data, fahrzeugId: null }, actor.id);
    const vehicle = this.get('vehicle', fahrzeugId);
    const position = this.positions.get(actor.id);
    const stillOccupied = this.list('member').some((m) => m.data.fahrzeugId === fahrzeugId);
    if (vehicle && position && !stillOccupied) {
      this.write('vehicle', vehicle.id, { ...vehicle.data, abgestellt: { lat: position.lat, lon: position.lon, ts: now } }, actor.id);
    }
  }

  private resetCoverage(now: number): void {
    this.db.sql.exec('DELETE FROM track');
    this.lastTrackPoint.clear();
    this.updateOperation({ bestreifungSeit: this.operationState.modus === 'fahndung' ? now : null });
    this.emit('event', { type: 'bestreifungReset' });
  }

  /** Setzt die laufende Lage zurück. Dauerhafte Orte, Profile, Fahrzeuge und Tracker bleiben erhalten. */
  private reset(actor: Actor, includeTargets: boolean, now: number): void {
    const layers = this.list('layer');
    const doomed = new Set(layers.filter((l) => l.data.status === 'live' && l.data.art !== 'dauerhaft').map((l) => l.id));
    for (const a of this.list('annotation')) if (doomed.has(a.data.layerId)) this.remove('annotation', a.id);
    for (const l of layers) if (doomed.has(l.id) && !PROTECTED_LAYERS.has(l.id)) this.remove('layer', l.id);
    for (const m of this.list('message')) this.remove('message', m.id);
    if (includeTargets) for (const t of this.list('target')) this.remove('target', t.id);
    this.updateOperation({ a: null, lkp: null, titel: '', hinweise: '' });
    this.resetCoverage(now);
    this.db.audit(actor.id, 'lage.zurueckgesetzt', includeTargets ? 'inklusive Zielpersonen' : '');
  }

  // ───────────────────────────── intern ─────────────────────────────

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

  private ensureLayer(id: string, data: EntityData<'layer'>): void {
    if (!this.get('layer', id)) this.write('layer', id, data, 'system');
  }

  private trimMessages(): void {
    const messages = this.list('message');
    if (messages.length <= MAX_MESSAGES) return;
    messages.sort((a, b) => a.updatedAt - b.updatedAt);
    for (const old of messages.slice(0, messages.length - MAX_MESSAGES)) this.remove('message', old.id);
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
