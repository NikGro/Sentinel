import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Database } from '../src/db.js';
import { Lage, LageError, LAYER_DAUERHAFT, LAYER_LAGE, ROOM_ALLGEMEIN } from '../src/lage.js';
import { fahnder, newLage, pos, profil, zentrale } from './helpers.js';

const fahrzeug = (funkrufname = 'p35/24') => ({ funkrufname, bezeichnung: 'Golf grau', kennzeichen: 'HH AB 123' });

test('Fahnder haben Spitznamen, Fahrzeuge einen normalisierten Funkrufnamen', () => {
  const lage = newLage();
  const member = lage.put(fahnder('a'), 'member', 'a', profil('Falke'));
  assert.equal((member.data as { spitzname: string }).spitzname, 'Falke');
  assert.equal((member.data as { fortbewegung: string }).fortbewegung, 'fuss');
  const vehicle = lage.put(fahnder('a'), 'vehicle', 'v1', fahrzeug());
  assert.equal((vehicle.data as { funkrufname: string }).funkrufname, 'P 35/24');
  assert.throws(() => lage.put(fahnder('a'), 'member', 'a', { name: 'x', dienststelle: 'y' }), LageError);
});

test('Fremde Profile sind nicht änderbar, Aktivität und Fortbewegung nur über Kommandos', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'member', 'a', profil());
  assert.throws(() => lage.put(fahnder('b'), 'member', 'a', profil()), /eigene Profil/);
  lage.put(fahnder('a'), 'member', 'a', { ...profil(), aktiv: false, fortbewegung: 'oepnv' });
  assert.equal(lage.get('member', 'a')?.data.aktiv, true);
  assert.equal(lage.get('member', 'a')?.data.fortbewegung, 'fuss');
});

test('Fortbewegung: Fahrzeug bleibt stehen, wenn der letzte Insasse aussteigt', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'member', 'a', profil('Falke'));
  lage.put(fahnder('b'), 'member', 'b', profil('Adler'));
  lage.put(fahnder('a'), 'vehicle', 'v1', fahrzeug());
  lage.command(fahnder('a'), 'fortbewegung.setzen', { art: 'fahrzeug', fahrzeugId: 'v1' });
  lage.command(fahnder('b'), 'fortbewegung.setzen', { art: 'fahrzeug', fahrzeugId: 'v1' });
  lage.reportPosition('a', pos(53.5, 10.0));
  lage.reportPosition('b', pos(53.51, 10.01));
  lage.command(fahnder('a'), 'fortbewegung.setzen', { art: 'fuss' });
  assert.equal(lage.get('vehicle', 'v1')?.data.abgestellt, null, 'B sitzt noch drin');
  lage.command(fahnder('b'), 'fortbewegung.setzen', { art: 'oepnv', oepnv: { linienId: '123', linie: 'U3', richtung: 'Barmbek' } });
  assert.equal(lage.get('vehicle', 'v1')?.data.abgestellt?.lat, 53.51);
  assert.equal(lage.get('member', 'b')?.data.oepnv?.linie, 'U3');
  assert.throws(() => lage.command(fahnder('a'), 'fortbewegung.setzen', { art: 'oepnv' }), /Linie/);
  lage.put(fahnder('a'), 'vehicle', 'v1', { ...fahrzeug(), aktiv: false });
  assert.throws(() => lage.command(fahnder('a'), 'fortbewegung.setzen', { art: 'fahrzeug', fahrzeugId: 'v1' }), /nicht aktiv/);
});

test('Ruhemodus: kein Standort, A-Position wird abgegeben', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'member', 'a', profil());
  lage.command(fahnder('a'), 'a.uebernehmen', {});
  lage.command(fahnder('a'), 'aktiv.setzen', { aktiv: false });
  assert.equal(lage.operation.a, null);
  lage.reportPosition('a', pos(53.5, 10));
  assert.equal(lage.positionOf('a'), undefined);
  assert.throws(() => lage.command(fahnder('a'), 'a.uebernehmen', {}), /Ruhemodus/);
});

test('Bestreifung wird immer aufgezeichnet und entprellt', () => {
  const lage = newLage();
  const start = Date.now();
  lage.reportPosition('a', pos(53.55, 9.99, start + 1));
  lage.reportPosition('a', pos(53.55001, 9.99, start + 2)); // ca. 1 m weiter: wird verworfen
  lage.reportPosition('a', pos(53.551, 9.99, start + 3)); // ca. 110 m weiter
  assert.equal(lage.coverage()[0]?.punkte.length, 2);
  lage.command(zentrale, 'bestreifung.zuruecksetzen', {});
  assert.equal(lage.coverage().length, 0);
});

test('Funkkanal: 1 bis 5 Ziffern', () => {
  const lage = newLage();
  lage.command(fahnder('a'), 'funkkanal.setzen', { kanal: '4711' });
  assert.equal(lage.operation.funkkanal, '4711');
  assert.throws(() => lage.command(fahnder('a'), 'funkkanal.setzen', { kanal: '123456' }), LageError);
});

test('Fahndungsraum braucht einen Zeitpunkt, Marker können einem Tracker folgen', () => {
  const lage = newLage();
  const punkt = [{ lat: 53.5, lon: 10 }];
  assert.throws(() => lage.put(fahnder('a'), 'annotation', 'f1', { layerId: LAYER_LAGE, typ: 'fahndungsraum', punkte: punkt }), /Zeitpunkt/);
  lage.put(fahnder('a'), 'annotation', 'f1', { layerId: LAYER_LAGE, typ: 'fahndungsraum', punkte: punkt, zeit: Date.now() - 600_000 });
  lage.put(zentrale, 'tracker', 'tr1', { name: 'Tracker 1', anbieter: 'sinotrack', kennung: '9170123456' });
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt, trackerId: 'tr1' });
  lage.del(zentrale, 'tracker', 'tr1');
  assert.equal(lage.get('annotation', 'm1')?.data.trackerId, null);
});

test('Ziele: Art und von Hand gesetzter Standort', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'target', 't1', { art: 'fahrzeug', bezeichnung: 'BMW 3er', kennzeichen: 'HH XY 1', standort: { lat: 53.5, lon: 10, ts: 1 } });
  assert.equal(lage.get('target', 't1')?.data.art, 'fahrzeug');
  assert.equal(lage.get('target', 'tx'), null);
  lage.put(fahnder('a'), 'target', 't2', { nachname: 'Muster' });
  assert.equal(lage.get('target', 't2')?.data.art, 'person');
});

test('Chaträume: anlegen, schreiben, löschen; der allgemeine Raum bleibt', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'room', 'r1', { name: 'Team Nord' });
  lage.put(fahnder('a'), 'message', 'n1', { roomId: 'r1', text: 'Hallo' });
  lage.put(fahnder('a'), 'message', 'n2', { roomId: ROOM_ALLGEMEIN, anhang: { blobId: 'abc', art: 'audio', mime: 'audio/mp4', groesse: 10, dauer: 3 } });
  assert.throws(() => lage.put(fahnder('a'), 'message', 'n3', { roomId: 'gibtsnicht', text: 'x' }), /Chatraum/);
  assert.throws(() => lage.put(fahnder('a'), 'message', 'n4', { roomId: 'r1' }), /leer/);
  lage.del(fahnder('b'), 'room', 'r1');
  assert.deepEqual(lage.list('message').map((m) => m.id), ['n2']);
  assert.throws(() => lage.del(fahnder('a'), 'room', ROOM_ALLGEMEIN), LageError);
});

test('Überschlagendes Anfahren: Teilnehmer erhalten die kommenden Halte und rücken nach', () => {
  const halte = [0, 1, 2, 3, 4, 5].map((i) => ({ name: `H${i}`, lat: 53.5 + i * 0.01, lon: 10 }));
  // Die kommenden Halte ergeben sich hier direkt aus der Breite der A.
  const upcoming = (_id: string, p: { lat: number }, count: number) => halte.filter((h) => h.lat > p.lat + 0.0001).slice(0, count);
  const lage = new Lage(new Database(':memory:'), upcoming);
  for (const id of ['a', 'b', 'c']) lage.put(fahnder(id), 'member', id, profil(id));
  lage.command(fahnder('a'), 'fortbewegung.setzen', { art: 'oepnv', oepnv: { linienId: '1', linie: 'U3', richtung: 'Nord' } });
  lage.command(fahnder('a'), 'a.uebernehmen', {});
  lage.reportPosition('a', pos(53.5, 10));
  lage.command(fahnder('b'), 'ueberschlagen.beitreten', {});
  lage.command(fahnder('c'), 'ueberschlagen.beitreten', {});
  const z = () => Object.fromEntries(Object.entries(lage.operation.ueberschlagen.zuweisungen).map(([k, v]) => [k, v.name]));
  assert.deepEqual(z(), { b: 'H1', c: 'H2' });
  assert.equal(lage.operation.ueberschlagen.naechste[0]?.name, 'H1');
  // A fährt an H1 vorbei: B springt hinter C.
  lage.reportPosition('a', pos(53.515, 10, Date.now() + 1000));
  assert.deepEqual(z(), { b: 'H3', c: 'H2' });
  assert.throws(() => lage.command(fahnder('a'), 'ueberschlagen.beitreten', {}), /A hält/);
  lage.command(fahnder('a'), 'a.freigeben', {});
  assert.deepEqual(z(), {});
});

test('Tracker-Intervall nur für SinoTrack, wird an das Gerät weitergegeben', () => {
  const lage = newLage();
  lage.put(zentrale, 'tracker', 'tr1', { name: 'ST', anbieter: 'sinotrack', kennung: '9170123456' });
  lage.put(zentrale, 'tracker', 'tr2', { name: 'PAJ', anbieter: 'paj', kennung: '1011381908' });
  const sent: unknown[] = [];
  lage.on('event', (e) => e.type === 'trackerIntervall' && sent.push(e));
  lage.command(fahnder('a'), 'tracker.intervall', { trackerId: 'tr1', sekunden: 30 });
  assert.equal(lage.get('tracker', 'tr1')?.data.intervall, 30);
  assert.equal(sent.length, 1);
  assert.throws(() => lage.command(fahnder('a'), 'tracker.intervall', { trackerId: 'tr2', sekunden: 30 }), /PAJ/);
});

test('Zurücksetzen räumt die Lage, dauerhafte Orte und Chaträume bleiben', () => {
  const lage = newLage();
  const punkt = [{ lat: 53.5, lon: 10 }];
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt });
  lage.put(fahnder('a'), 'annotation', 'm2', { layerId: LAYER_DAUERHAFT, typ: 'marker', punkte: punkt });
  lage.put(fahnder('a'), 'room', 'r1', { name: 'Nord' });
  lage.put(fahnder('a'), 'message', 'n1', { roomId: 'r1', text: 'Hallo' });
  lage.command(zentrale, 'lage.zuruecksetzen', { ziele: false });
  assert.deepEqual(lage.list('annotation').map((a) => a.id), ['m2']);
  assert.equal(lage.list('message').length, 0);
  assert.equal(lage.list('room').length, 2);
});

test('Bestehende Daten werden auf das neue Modell übertragen', () => {
  const db = new Database(':memory:');
  const insert = db.sql.prepare('INSERT INTO entities (kind, id, rev, data, updated_at, updated_by) VALUES (?, ?, 1, ?, 0, ?)');
  insert.run('member', 'a', JSON.stringify({ name: 'Nikki', funkrufname: 'P 35/24', dienststelle: 'ZF 35', telefon: '', fotoBlob: null, fahrzeugId: null }), 'a');
  insert.run('vehicle', 'v1', JSON.stringify({ bezeichnung: 'Volvo EX30, Schwarz', kennzeichen: '', beschreibung: '', fotoBlob: null, trackerId: null, abgestellt: null }), 'a');
  insert.run('message', 'n1', JSON.stringify({ text: 'Alt' }), 'a');
  db.setKv('operation', JSON.stringify({ modus: 'fahndung', funkkanal: '12', titel: '', hinweise: '', a: null, lkp: null, bestreifungSeit: 1, rev: 3 }));
  const lage = new Lage(db);
  assert.equal(lage.get('member', 'a')?.data.spitzname, 'P 35/24');
  assert.equal(lage.get('member', 'a')?.data.aktiv, true);
  assert.equal(lage.get('vehicle', 'v1')?.data.funkrufname, 'Volvo EX30, Schwarz');
  assert.equal(lage.get('message', 'n1')?.data.roomId, ROOM_ALLGEMEIN);
  assert.equal(lage.operation.funkkanal, '12');
  assert.equal('modus' in lage.operation, false);
});
