import type { Database } from './db.js';
import { SCOPED_KINDS, type Entity, type EntityData, type Kind, type Position } from './schemas.js';

/** Instanzübergreifende Objekte stehen unter `inst = ''`. */
export const GLOBAL = '';

interface EntityRow {
  id: string;
  rev: number;
  data: string;
  updated_at: number;
  updated_by: string;
}

const COLUMNS = 'id, rev, data, updated_at, updated_by';

function fromRow<K extends Kind>(row: EntityRow): Entity<K> {
  return { id: row.id, rev: row.rev, updatedAt: row.updated_at, updatedBy: row.updated_by, data: JSON.parse(row.data) as EntityData<K> };
}

/**
 * Ablage der Objekte in SQLite, ohne Fachlogik. Instanzbezogene Arten (siehe `SCOPED_KINDS`) werden aus der
 * angefragten Instanz und dem übergreifenden Bereich gelesen; alle anderen gelten überall.
 */
export class EntityStore {
  constructor(private readonly db: Database) {}

  list<K extends Kind>(kind: K, inst: string): Entity<K>[] {
    const rows = SCOPED_KINDS.has(kind)
      ? this.db.sql.prepare(`SELECT ${COLUMNS} FROM entities WHERE kind = ? AND inst IN (?, '')`).all(kind, inst)
      : this.db.sql.prepare(`SELECT ${COLUMNS} FROM entities WHERE kind = ?`).all(kind);
    return (rows as unknown as EntityRow[]).map((row) => fromRow<K>(row));
  }

  /** Objekte genau einer Instanz (ohne die übergreifenden). */
  listIn<K extends Kind>(kind: K, inst: string): Entity<K>[] {
    const rows = this.db.sql.prepare(`SELECT ${COLUMNS} FROM entities WHERE kind = ? AND inst = ?`).all(kind, inst) as unknown as EntityRow[];
    return rows.map((row) => fromRow<K>(row));
  }

  /** Alle Objekte einer Art über alle Instanzen, mit ihrer Instanz. */
  listAll<K extends Kind>(kind: K): { inst: string; entity: Entity<K> }[] {
    const rows = this.db.sql.prepare(`SELECT inst, ${COLUMNS} FROM entities WHERE kind = ?`).all(kind) as unknown as (EntityRow & { inst: string })[];
    return rows.map((row) => ({ inst: row.inst, entity: fromRow<K>(row) }));
  }

  /** Ein Objekt; bei instanzbezogenen Arten hat die Instanz Vorrang vor dem übergreifenden Bereich. */
  get<K extends Kind>(kind: K, id: string, inst: string): Entity<K> | null {
    const row = (
      SCOPED_KINDS.has(kind)
        ? this.db.sql.prepare(`SELECT ${COLUMNS} FROM entities WHERE kind = ? AND id = ? AND inst IN (?, '') ORDER BY inst DESC`).get(kind, id, inst)
        : this.db.sql.prepare(`SELECT ${COLUMNS} FROM entities WHERE kind = ? AND id = ?`).get(kind, id)
    ) as EntityRow | undefined;
    return row ? fromRow<K>(row) : null;
  }

  exists(kind: Kind, inst: string, id: string): boolean {
    return !!this.db.sql.prepare('SELECT 1 FROM entities WHERE kind = ? AND inst = ? AND id = ?').get(kind, inst, id);
  }

  write<K extends Kind>(kind: K, inst: string, id: string, data: EntityData<K>, actorId: string): Entity<K> {
    const now = Date.now();
    const row = this.db.sql
      .prepare(
        `INSERT INTO entities (kind, inst, id, rev, data, updated_at, updated_by) VALUES (?, ?, ?, 1, ?, ?, ?)
         ON CONFLICT (kind, inst, id) DO UPDATE SET rev = rev + 1, data = excluded.data, updated_at = excluded.updated_at, updated_by = excluded.updated_by
         RETURNING rev`,
      )
      .get(kind, inst, id, JSON.stringify(data), now, actorId) as { rev: number };
    return { id, rev: row.rev, updatedAt: now, updatedBy: actorId, data };
  }

  remove(kind: Kind, inst: string, id: string): void {
    this.db.sql.prepare('DELETE FROM entities WHERE kind = ? AND inst = ? AND id = ?').run(kind, inst, id);
  }
}

/** Bestreifung: aufgezeichnete Wege je Fahnder und Instanz. */
export class TrackStore {
  constructor(private readonly db: Database) {}

  add(inst: string, memberId: string, p: Position): void {
    this.db.sql.prepare('INSERT OR IGNORE INTO track (member_id, ts, lat, lon, inst) VALUES (?, ?, ?, ?, ?)').run(memberId, p.ts, p.lat, p.lon, inst);
  }

  byMember(inst: string): { memberId: string; punkte: [number, number, number][] }[] {
    const rows = this.db.sql.prepare('SELECT member_id, ts, lat, lon FROM track WHERE inst = ? ORDER BY member_id, ts').all(inst) as unknown as {
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

  clear(inst: string): void {
    this.db.sql.prepare('DELETE FROM track WHERE inst = ?').run(inst);
  }

  pruneBefore(ts: number): void {
    this.db.sql.prepare('DELETE FROM track WHERE ts < ?').run(ts);
  }
}
