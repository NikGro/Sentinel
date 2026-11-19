import { chmodSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

/** Schema-Migrationen, strikt fortlaufend. Bestehende Einträge nie ändern, nur neue anhängen. */
const MIGRATIONS: readonly string[] = [
  `
  CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE sessions (
    token_hash TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
  );
  CREATE TABLE entities (
    kind TEXT NOT NULL,
    id TEXT NOT NULL,
    rev INTEGER NOT NULL,
    data TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    updated_by TEXT NOT NULL,
    PRIMARY KEY (kind, id)
  ) WITHOUT ROWID;
  CREATE TABLE blobs (
    id TEXT PRIMARY KEY,
    mime TEXT NOT NULL,
    bytes BLOB NOT NULL,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );
  CREATE TABLE track (
    member_id TEXT NOT NULL,
    ts INTEGER NOT NULL,
    lat REAL NOT NULL,
    lon REAL NOT NULL,
    PRIMARY KEY (member_id, ts)
  ) WITHOUT ROWID;
  CREATE TABLE kv (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  ) WITHOUT ROWID;
  CREATE TABLE audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts INTEGER NOT NULL,
    actor TEXT NOT NULL,
    action TEXT NOT NULL,
    detail TEXT NOT NULL DEFAULT ''
  );
  CREATE INDEX audit_ts ON audit (ts);
  `,
  // 0.13: Instanzen. Lagebezogene Objekte gehören zu einer Instanz (`inst`), übergreifende haben `inst = ''`.
  // Bestehende Lageobjekte wandern in die Hauptinstanz, die dauerhaften Orte werden instanzübergreifend.
  `
  CREATE TABLE entities_neu (
    kind TEXT NOT NULL,
    inst TEXT NOT NULL DEFAULT '',
    id TEXT NOT NULL,
    rev INTEGER NOT NULL,
    data TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    updated_by TEXT NOT NULL,
    PRIMARY KEY (kind, inst, id)
  ) WITHOUT ROWID;
  INSERT INTO entities_neu (kind, inst, id, rev, data, updated_at, updated_by)
    SELECT kind,
      CASE
        WHEN kind = 'layer' AND id = 'dauerhaft' THEN ''
        WHEN kind = 'annotation' AND json_extract(data, '$.layerId') = 'dauerhaft' THEN ''
        WHEN kind IN ('annotation', 'target', 'layer', 'room', 'message') THEN 'haupt'
        ELSE ''
      END,
      id, rev, data, updated_at, updated_by
    FROM entities;
  DROP TABLE entities;
  ALTER TABLE entities_neu RENAME TO entities;
  ALTER TABLE track ADD COLUMN inst TEXT NOT NULL DEFAULT 'haupt';
  `,
];

export class Database {
  readonly sql: DatabaseSync;

  constructor(dataDir: string | ':memory:') {
    const file = dataDir === ':memory:' ? ':memory:' : join(dataDir, 'sentinel.sqlite');
    const fresh = file !== ':memory:' && !existsSync(file);
    this.sql = new DatabaseSync(file);
    if (fresh) chmodSync(file, 0o600);
    this.sql.exec('PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA foreign_keys = ON; PRAGMA secure_delete = ON;');
    this.migrate();
  }

  private migrate(): void {
    const current = (this.sql.prepare('PRAGMA user_version').get() as { user_version: number }).user_version;
    for (let version = current; version < MIGRATIONS.length; version++) {
      this.transaction(() => {
        this.sql.exec(MIGRATIONS[version]!);
        this.sql.exec(`PRAGMA user_version = ${version + 1}`);
      });
    }
  }

  transaction<T>(work: () => T): T {
    this.sql.exec('BEGIN IMMEDIATE');
    try {
      const result = work();
      this.sql.exec('COMMIT');
      return result;
    } catch (error) {
      this.sql.exec('ROLLBACK');
      throw error;
    }
  }

  getKv(key: string): string | null {
    const row = this.sql.prepare('SELECT value FROM kv WHERE key = ?').get(key) as { value: string } | undefined;
    return row?.value ?? null;
  }

  setKv(key: string, value: string): void {
    this.sql.prepare('INSERT INTO kv (key, value) VALUES (?, ?) ON CONFLICT (key) DO UPDATE SET value = excluded.value').run(key, value);
  }

  deleteKv(key: string): void {
    this.sql.prepare('DELETE FROM kv WHERE key = ?').run(key);
  }

  audit(actor: string, action: string, detail = ''): void {
    this.sql.prepare('INSERT INTO audit (ts, actor, action, detail) VALUES (?, ?, ?, ?)').run(Date.now(), actor, action, detail.slice(0, 500));
  }

  close(): void {
    this.sql.close();
  }
}
