import assert from 'node:assert/strict';
import { test } from 'node:test';
import { pruneOrphanBlobs } from '../src/blobs.js';
import { Database } from '../src/db.js';
import { Lage, LAYER_LAGE } from '../src/lage.js';
import { fahnder, profil } from './helpers.js';

test('Verwaiste Dateien werden gelöscht, verwendete und frische bleiben', () => {
  const db = new Database(':memory:');
  const lage = new Lage(db);
  const day = 24 * 3600_000;
  const now = Date.now();
  const blob = (id: string, age: number) => db.sql.prepare('INSERT INTO blobs (id, mime, bytes, created_by, created_at) VALUES (?, ?, ?, ?, ?)').run(id, 'image/jpeg', Buffer.from([1]), 'a', now - age);
  for (const id of ['profil', 'anhang', 'alt', 'frisch']) blob(id, id === 'frisch' ? 1000 : 2 * day);

  lage.put(fahnder('a'), 'member', 'a', { ...profil(), fotoBlob: 'profil' });
  const anhang = { blobId: 'anhang', art: 'bild', name: 'x.jpg', mime: 'image/jpeg', groesse: 1 };
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_LAGE, typ: 'marker', punkte: [{ lat: 53.5, lon: 10 }], anhaenge: [anhang] });

  assert.equal(pruneOrphanBlobs(db, day, now), 1);
  const left = (db.sql.prepare('SELECT id FROM blobs ORDER BY id').all() as { id: string }[]).map((r) => r.id);
  assert.deepEqual(left, ['anhang', 'frisch', 'profil']);

  lage.del(fahnder('a'), 'annotation', 'm1');
  assert.equal(pruneOrphanBlobs(db, day, now), 1, 'Nach dem Löschen der Markierung ist ihr Foto verwaist');
});
