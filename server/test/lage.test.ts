import assert from 'node:assert/strict';
import { test } from 'node:test';
import { LageError, LAYER_DAUERHAFT, LAYER_LAGE } from '../src/lage.js';
import { fahnder, newLage, pos, profil, zentrale } from './helpers.js';

test('Funkrufname wird geprüft und normalisiert', () => {
  const lage = newLage();
  const entity = lage.put(fahnder('a'), 'member', 'a', profil('p35/657'));
  assert.equal((entity.data as { funkrufname: string }).funkrufname, 'P 35/657');
  assert.throws(() => lage.put(fahnder('a'), 'member', 'a', profil('P 3524')), LageError);
  assert.throws(() => lage.put(fahnder('a'), 'member', 'a', profil('ABCD 1/2')), LageError);
});

test('Fremde Profile sind nicht änderbar', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'member', 'a', profil());
  assert.throws(() => lage.put(fahnder('b'), 'member', 'a', profil()), /eigene Profil/);
});

test('A-Position nur im Observationsmodus, Wechsel in die Fahndung übernimmt sie als letzten Standort', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'member', 'a', profil());
  lage.reportPosition('a', pos(53.55, 9.99));
  lage.command(fahnder('a'), 'a.uebernehmen', {});
  assert.equal(lage.operation.a?.memberId, 'a');

  lage.command(fahnder('a'), 'modus.setzen', { modus: 'fahndung' });
  assert.equal(lage.operation.a, null);
  assert.equal(lage.operation.lkp?.quelle, 'a');
  assert.equal(lage.operation.lkp?.lat, 53.55);
  assert.notEqual(lage.operation.bestreifungSeit, null);
  assert.throws(() => lage.command(fahnder('a'), 'a.uebernehmen', {}), /Observationsmodus/);

  lage.command(fahnder('a'), 'modus.setzen', { modus: 'observation' });
  assert.notEqual(lage.operation.lkp, null, 'letzter Standort bleibt beim Rückwechsel erhalten');
});

test('Bestreifung wird nur im Fahndungsmodus aufgezeichnet und entprellt', () => {
  const lage = newLage();
  lage.reportPosition('a', pos(53.55, 9.99, 1000));
  assert.equal(lage.coverage().length, 0);
  lage.command(zentrale, 'modus.setzen', { modus: 'fahndung' });
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
  assert.throws(() => lage.command(fahnder('a'), 'funkkanal.setzen', { kanal: '12a' }), LageError);
});

test('Ein- und Aussteigen: Fahrzeug bleibt am Ort des Aussteigens zurück', () => {
  const lage = newLage();
  lage.put(fahnder('a'), 'member', 'a', profil());
  lage.put(fahnder('a'), 'vehicle', 'v1', { bezeichnung: 'Golf grau', kennzeichen: 'HH AB 123' });
  lage.command(fahnder('a'), 'fahrzeug.einsteigen', { fahrzeugId: 'v1' });
  assert.equal(lage.get('member', 'a')?.data.fahrzeugId, 'v1');
  // Ein Profil-Update darf die Besetzung nicht überschreiben.
  lage.put(fahnder('a'), 'member', 'a', { ...profil(), fahrzeugId: null });
  assert.equal(lage.get('member', 'a')?.data.fahrzeugId, 'v1');
  lage.reportPosition('a', pos(53.5, 10.0));
  lage.command(fahnder('a'), 'fahrzeug.aussteigen', {});
  assert.equal(lage.get('member', 'a')?.data.fahrzeugId, null);
  assert.equal(lage.get('vehicle', 'v1')?.data.abgestellt?.lat, 53.5);
});

test('Entwurfs-Ebenen sind für Fahnder unsichtbar, bis sie geladen werden', () => {
  const lage = newLage();
  lage.put(zentrale, 'layer', 'p1', { name: 'Vorplanung', art: 'paket', status: 'entwurf' });
  lage.put(zentrale, 'annotation', 'm1', { layerId: 'p1', typ: 'marker', titel: 'Treffpunkt', punkte: [{ lat: 53.5, lon: 10 }] });
  assert.equal(lage.snapshot('fahnder').annotations.length, 0);
  assert.equal(lage.snapshot('zentrale').annotations.length, 1);

  const events: string[] = [];
  lage.on('event', (e) => events.push(e.type));
  lage.put(zentrale, 'layer', 'p1', { name: 'Vorplanung', art: 'paket', status: 'live' });
  assert.ok(events.includes('layerVisibility'));
  assert.equal(lage.snapshot('fahnder').annotations.length, 1);
});

test('Zurücksetzen räumt die Lage, dauerhafte Orte bleiben', () => {
  const lage = newLage();
  const punkt = [{ lat: 53.5, lon: 10 }];
  lage.put(fahnder('a'), 'annotation', 'm1', { layerId: LAYER_LAGE, typ: 'marker', punkte: punkt });
  lage.put(fahnder('a'), 'annotation', 'm2', { layerId: LAYER_DAUERHAFT, typ: 'marker', punkte: punkt });
  lage.put(fahnder('a'), 'message', 'n1', { text: 'Hallo' });
  lage.put(fahnder('a'), 'target', 't1', { nachname: 'Muster' });
  lage.command(zentrale, 'lage.zuruecksetzen', { ziele: false });
  assert.deepEqual(lage.list('annotation').map((a) => a.id), ['m2']);
  assert.equal(lage.list('message').length, 0);
  assert.equal(lage.list('target').length, 1);
  assert.equal(lage.list('layer').length, 2);
});

test('Geschützte Ebenen und Nachrichten sind nicht löschbar, Flächen brauchen drei Punkte', () => {
  const lage = newLage();
  assert.throws(() => lage.del(zentrale, 'layer', LAYER_LAGE), LageError);
  lage.put(fahnder('a'), 'message', 'n1', { text: 'x' });
  assert.throws(() => lage.del(fahnder('a'), 'message', 'n1'), LageError);
  assert.throws(() => lage.put(fahnder('a'), 'message', 'n1', { text: 'geändert' }), LageError);
  assert.throws(() => lage.put(fahnder('a'), 'annotation', 'f', { layerId: LAYER_LAGE, typ: 'flaeche', punkte: [{ lat: 1, lon: 1 }] }), LageError);
});

test('Tracker an der Zielperson führt im Fahndungsmodus den letzten Standort nach', () => {
  const lage = newLage();
  lage.put(zentrale, 'tracker', 'tr1', { name: 'ST-901 Nr. 1', anbieter: 'sinotrack', kennung: '9170123456' });
  lage.put(zentrale, 'target', 't1', { nachname: 'Muster', trackerId: 'tr1' });
  lage.command(zentrale, 'modus.setzen', { modus: 'fahndung' });
  assert.equal(lage.reportTrackerPosition('sinotrack', '0000000000', pos(1, 1)), false);
  assert.equal(lage.reportTrackerPosition('sinotrack', '9170123456', pos(53.6, 10.1)), true);
  assert.equal(lage.operation.lkp?.quelle, 'tracker');
  assert.equal(lage.operation.lkp?.targetId, 't1');
});
