import type { Database } from './db.js';

/** Felder, in denen Objekte auf hochgeladene Dateien verweisen (Fotos, Anhänge, Sprachnachrichten). */
const REFERENCE = /"(?:fotoBlob|fahrzeugFotoBlob|blobId)":"([A-Za-z0-9_-]{1,64})"/g;

/**
 * Löscht Dateien, auf die kein Objekt mehr verweist, z. B. nach gelöschten Nachrichten, Zielen oder Markierungen.
 * Frisch hochgeladene Dateien bleiben eine Weile verschont: Sie werden hochgeladen, bevor das Objekt gespeichert ist.
 * Liefert die Anzahl gelöschter Dateien.
 */
export function pruneOrphanBlobs(db: Database, minAgeMs = 24 * 3600_000, now = Date.now()): number {
  const referenced = new Set<string>();
  const rows = db.sql.prepare('SELECT data FROM entities').all() as { data: string }[];
  for (const { data } of rows) for (const match of data.matchAll(REFERENCE)) referenced.add(match[1]!);
  const candidates = db.sql.prepare('SELECT id FROM blobs WHERE created_at < ?').all(now - minAgeMs) as { id: string }[];
  const orphans = candidates.filter((c) => !referenced.has(c.id));
  if (orphans.length === 0) return 0;
  const remove = db.sql.prepare('DELETE FROM blobs WHERE id = ?');
  db.transaction(() => {
    for (const { id } of orphans) remove.run(id);
  });
  db.audit('system', 'dateien.aufgeraeumt', String(orphans.length));
  return orphans.length;
}
