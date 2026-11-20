import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { test } from 'node:test';
import { Database } from '../src/db.js';
import { Lage, LageError, LAYER_DAUERHAFT, LAYER_LAGE, type LageEvent } from '../src/lage.js';
import { fahnder, newLage, pos, profil, zentrale } from './helpers.js';

const punkt = [{ lat: 53.5, lon: 10 }];

function mitZwei() {
  const lage = newLage();
  lage.put(fahnder('a'), 'member', 'a', profil('Falke'));
  lage.put(fahnder('b'), 'member', 'b', profil('Adler'));
  return lage;
}

test('Instanzen: eigene Lage, Ziele und Einsatzzustand; dauerhafte Orte überall', () => {
  const lage = mitZwei();
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'nord', name: 'Einsatz Nord' });
  assert.equal(lage.activeInstance('a'), 'nord', 'Ersteller wechselt hinein');
  assert.deepEqual(lage.get('instance', 'nord')?.data.mitglieder, ['a']);

  lage.put(fahnder('a'), 'annotation', 'n1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt }, 'nord');
  lage.put(fahnder('a'), 'annotation', 'd1', { layerId: LAYER_DAUERHAFT, typ: 'marker', punkte: punkt }, 'nord');
  lage.put(fahnder('b'), 'annotation', 'h1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt });
  lage.put(fahnder('a'), 'target', 'z1', { vorname: 'Max' }, 'nord');

  assert.deepEqual(lage.list('annotation', 'nord').map((a) => a.id).sort(), ['d1', 'n1']);
  assert.deepEqual(lage.list('annotation', 'haupt').map((a) => a.id).sort(), ['d1', 'h1']);
  assert.equal(lage.list('target', 'haupt').length, 0);
  assert.equal(lage.snapshot('nord').rooms.length, 1, 'Jede Instanz hat ihren allgemeinen Chatraum');

  lage.command(fahnder('a'), 'a.uebernehmen');
  assert.equal(lage.operationOf('nord').a?.memberId, 'a');
  assert.equal(lage.operationOf('haupt').a, null);
});

test('Instanzen: beitreten, wechseln, verlassen; A wird beim Wechsel abgegeben', () => {
  const lage = mitZwei();
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'nord', name: 'Nord' });
  lage.command(fahnder('a'), 'a.uebernehmen');
  lage.command(fahnder('b'), 'instanz.beitreten', { id: 'nord' });
  assert.equal(lage.isMember('nord', 'b'), true);
  assert.equal(lage.activeInstance('b'), 'haupt', 'Beitreten öffnet die Instanz noch nicht');

  lage.command(fahnder('a'), 'instanz.wechseln', { id: 'haupt' });
  assert.equal(lage.operationOf('nord').a, null);
  assert.equal(lage.isMember('nord', 'a'), true, 'Mitgliedschaft bleibt beim Wechsel');

  lage.command(fahnder('b'), 'instanz.wechseln', { id: 'nord' });
  lage.command(fahnder('b'), 'instanz.verlassen', { id: 'nord' });
  assert.equal(lage.activeInstance('b'), 'haupt');
  assert.equal(lage.isMember('nord', 'b'), false);
  // Die Standardinstanz lässt sich verlassen; ohne Instanz ist man außer Dienst, mit dem Betreten wieder im Dienst.
  lage.command(fahnder('b'), 'instanz.verlassen', { id: 'haupt' });
  assert.equal(lage.get('member', 'b')?.data.aktiv, false);
  assert.equal(lage.isMember('haupt', 'b'), false);
  lage.command(fahnder('b'), 'instanz.wechseln', { id: 'haupt' });
  assert.equal(lage.get('member', 'b')?.data.aktiv, true);
  assert.equal(lage.isMember('haupt', 'b'), true);
});

test('Instanzen: löschen räumt alles ab, die Hauptlage bleibt', () => {
  const lage = mitZwei();
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'nord', name: 'Nord' });
  lage.put(fahnder('a'), 'annotation', 'n1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt }, 'nord');
  lage.reportPosition('a', pos(53.5, 10));
  assert.equal(lage.coverage('nord').length, 1);
  assert.equal(lage.coverage('haupt').length, 0, 'Bestreifung je Instanz');
  assert.throws(() => lage.command(fahnder('b'), 'instanz.loeschen', { id: 'nord' }), /Mitglieder/);
  lage.command(fahnder('a'), 'instanz.loeschen', { id: 'nord' });
  assert.equal(lage.get('instance', 'nord'), null);
  assert.equal(lage.activeInstance('a'), 'haupt');
  assert.equal(lage.list('annotation', 'nord').length, 0);
  assert.equal(lage.coverage('nord').length, 0);
  assert.throws(() => lage.command(zentrale, 'instanz.loeschen', { id: 'haupt' }), /Standardinstanz/);
});

test('Pakete: Inhalt wird als eigenständige Objekte in die Instanz übernommen', () => {
  const lage = mitZwei();
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'p1', name: 'Bahnhof', art: 'paket' });
  assert.equal(lage.activeInstance('a'), 'p1');
  lage.put(fahnder('a'), 'annotation', 'x1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt, gruppe: 'g1' }, 'p1');
  lage.put(fahnder('a'), 'annotation', 'x2', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt, gruppe: 'g1' }, 'p1');
  lage.put(fahnder('a'), 'target', 'auto', { art: 'fahrzeug', bezeichnung: 'BMW' }, 'p1');
  lage.put(fahnder('a'), 'target', 'person', { vorname: 'Max', bindung: { art: 'fahrzeug', zielId: 'auto' } }, 'p1');

  assert.throws(() => lage.command(fahnder('a'), 'paket.importieren', { paketId: 'p1' }), /Einsatz-Instanz/);
  lage.command(fahnder('b'), 'paket.importieren', { paketId: 'p1' });
  const imported = lage.list('annotation', 'haupt');
  assert.equal(imported.length, 2);
  assert.ok(imported.every((a) => a.id !== 'x1' && a.id !== 'x2'), 'Neue Kennungen');
  const targets = lage.list('target', 'haupt');
  const auto = targets.find((t) => t.data.art === 'fahrzeug')!;
  assert.equal(targets.find((t) => t.data.vorname === 'Max')?.data.bindung?.zielId, auto.id, 'Bindung zeigt auf die Kopie');

  // Nachträgliche Änderungen am Paket wirken nicht auf die übernommenen Objekte.
  lage.del(fahnder('a'), 'annotation', 'x1', 'p1');
  assert.equal(lage.list('annotation', 'haupt').length, 2);
});

test('Lage-Layer wird nur geleert, nie gelöscht', () => {
  const lage = mitZwei();
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt });
  lage.put(fahnder('a'), 'annotation', 'm2', { layerId: LAYER_DAUERHAFT, typ: 'marker', punkte: punkt });
  assert.throws(() => lage.del(fahnder('a'), 'layer', LAYER_LAGE), LageError);
  lage.command(fahnder('a'), 'lage.leeren');
  assert.deepEqual(lage.list('annotation').map((a) => a.id), ['m2']);
  assert.ok(lage.get('layer', LAYER_LAGE));
});

test('Hinweis bei A-Position und Notruf in einer Instanz', () => {
  const lage = mitZwei();
  const events: LageEvent[] = [];
  lage.on('event', (e) => events.push(e));
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'nord', name: 'Nord' });
  lage.command(fahnder('a'), 'sos.ausloesen');
  lage.command(fahnder('a'), 'a.uebernehmen');
  const hinweise = events.filter((e) => e.type === 'hinweis');
  assert.deepEqual(hinweise.map((e) => e.type === 'hinweis' && [e.inst, e.art]), [['nord', 'sos'], ['nord', 'a']]);
});

test('Datenbank aus 0.12: Lageobjekte wandern in die Hauptinstanz, dauerhafte Orte werden übergreifend', () => {
  const dir = mkdtempSync(join(tmpdir(), 'sentinel-mig-'));
  const raw = new DatabaseSync(join(dir, 'sentinel.sqlite'));
  raw.exec(`
    CREATE TABLE devices (id TEXT PRIMARY KEY, token_hash TEXT NOT NULL UNIQUE, name TEXT NOT NULL, created_at INTEGER NOT NULL, last_seen INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE sessions (token_hash TEXT PRIMARY KEY, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL);
    CREATE TABLE entities (kind TEXT NOT NULL, id TEXT NOT NULL, rev INTEGER NOT NULL, data TEXT NOT NULL, updated_at INTEGER NOT NULL, updated_by TEXT NOT NULL, PRIMARY KEY (kind, id)) WITHOUT ROWID;
    CREATE TABLE blobs (id TEXT PRIMARY KEY, mime TEXT NOT NULL, bytes BLOB NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL);
    CREATE TABLE track (member_id TEXT NOT NULL, ts INTEGER NOT NULL, lat REAL NOT NULL, lon REAL NOT NULL, PRIMARY KEY (member_id, ts)) WITHOUT ROWID;
    CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
    CREATE TABLE audit (id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, actor TEXT NOT NULL, action TEXT NOT NULL, detail TEXT NOT NULL DEFAULT '');
    PRAGMA user_version = 1;
  `);
  const insert = raw.prepare('INSERT INTO entities (kind, id, rev, data, updated_at, updated_by) VALUES (?, ?, 1, ?, 0, ?)');
  insert.run('layer', 'lage', JSON.stringify({ name: 'Lage', art: 'lage', status: 'live' }), 'system');
  insert.run('layer', 'dauerhaft', JSON.stringify({ name: 'Dauerhafte Orte', art: 'dauerhaft', status: 'live' }), 'system');
  insert.run('annotation', 'm1', JSON.stringify({ layerId: 'lage', typ: 'marker', punkte: punkt }), 'a');
  insert.run('annotation', 'm2', JSON.stringify({ layerId: 'dauerhaft', typ: 'marker', punkte: punkt }), 'a');
  insert.run('member', 'a', JSON.stringify(profil()), 'a');
  raw.prepare('INSERT INTO track VALUES (?, ?, ?, ?)').run('a', Date.now(), 53.5, 10);
  raw.close();

  const lage = new Lage(new Database(dir));
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'nord', name: 'Nord' });
  assert.deepEqual(lage.list('annotation', 'haupt').map((a) => a.id).sort(), ['m1', 'm2']);
  assert.deepEqual(lage.list('annotation', 'nord').map((a) => a.id), ['m2']);
  assert.equal(lage.get('member', 'a')?.data.instanz, 'nord');
  assert.equal(lage.coverage('haupt').length, 1);
});

test('Instanzen lassen sich nicht direkt schreiben, nur über Kommandos', () => {
  const lage = mitZwei();
  assert.throws(() => lage.put(fahnder('a'), 'instance', 'x', { name: 'X' }), /Instanzenmenü/);
  assert.throws(() => lage.del(zentrale, 'instance', 'haupt'), /Instanzenmenü/);
  assert.throws(() => lage.command(fahnder('a'), 'instanz.wechseln', { id: 'gibtsnicht' }), /existiert nicht/);
});

test('Markierung zieht zwischen Lage und dauerhaften Orten um', () => {
  const lage = mitZwei();
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'nord', name: 'Nord' });
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt }, 'nord');
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_DAUERHAFT, typ: 'marker', punkte: punkt }, 'nord');
  assert.deepEqual(lage.list('annotation', 'haupt').map((a) => a.id), ['m1'], 'Jetzt in allen Instanzen');
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt }, 'nord');
  assert.equal(lage.list('annotation', 'haupt').length, 0);
  assert.equal(lage.list('annotation', 'nord').length, 1, 'Kein Doppel');
});

test('Profil übernehmen: Angaben und Mitgliedschaften wandern zum neuen Gerät', () => {
  const lage = mitZwei();
  lage.command(fahnder('a'), 'instanz.erstellen', { id: 'nord', name: 'Nord' });
  const adopted = lage.adoptMember('neu', 'a');
  assert.equal(adopted.data.spitzname, 'Falke');
  assert.equal(lage.get('member', 'a'), null);
  assert.ok(lage.isMember('nord', 'neu'));
  assert.throws(() => lage.adoptMember('neu', 'b'), /schon ein Profil/);
});

test('Ziel an der A bleibt nach Abgabe der A an ihrer letzten Position', () => {
  const lage = mitZwei();
  lage.put(fahnder('a'), 'target', 'z', { vorname: 'Max', quelle: 'a', standort: { lat: 53.0, lon: 10.0, ts: 1 } });
  lage.command(fahnder('a'), 'a.uebernehmen');
  lage.reportPosition('a', pos(53.6, 10.1));
  lage.command(fahnder('a'), 'a.freigeben');
  assert.equal(lage.get('target', 'z')?.data.standort?.lat, 53.6);
});

test('Standardinstanz heißt KSOD, auch nach Umbenennung einer alten Hauptlage', () => {
  const db = new Database(':memory:');
  const first = new Lage(db);
  assert.equal(first.get('instance', 'haupt', '')?.data.name, 'KSOD');
  const old = first.get('instance', 'haupt', '')!;
  db.sql.prepare("UPDATE entities SET data = ? WHERE kind = 'instance' AND id = 'haupt'").run(JSON.stringify({ ...old.data, name: 'Hauptlage' }));
  const second = new Lage(db);
  assert.equal(second.get('instance', 'haupt', '')?.data.name, 'KSOD');
});
