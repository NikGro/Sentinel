import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Database } from '../src/db.js';
import { SpurStore, transitPosition } from '../src/spur.js';
import { parseH02Status, parseH02Text } from '../src/trackers/h02.js';
import { fahnder, newLage, pos, profil } from './helpers.js';

test('Spur: nur Neues wird gespeichert, laufende Quellen auch im Stand alle fünf Minuten', () => {
  const store = new SpurStore(new Database(':memory:'));
  const t0 = 1_700_000_000_000;
  assert.equal(store.add('member', 'a', 'haupt', { lat: 53.55, lon: 10, ts: t0, quelle: 'gps' }), true);
  // Kaum bewegt, kurz danach: verworfen.
  assert.equal(store.add('member', 'a', 'haupt', { lat: 53.55001, lon: 10, ts: t0 + 10_000, quelle: 'gps' }), false);
  // Im Stand, aber fünf Minuten später: Herzschlag.
  assert.equal(store.add('member', 'a', 'haupt', { lat: 53.55001, lon: 10, ts: t0 + 300_000, quelle: 'gps' }), true);
  // Von Hand gesetzt: kein Herzschlag, nur bei Änderung.
  assert.equal(store.add('target', 'z', 'haupt', { lat: 53.5, lon: 10, ts: t0, quelle: 'hand' }), true);
  assert.equal(store.add('target', 'z', 'haupt', { lat: 53.5, lon: 10, ts: t0 + 900_000, quelle: 'hand' }), false);
  // Quellenwechsel am selben Ort zählt.
  assert.equal(store.add('target', 'z', 'haupt', { lat: 53.5, lon: 10, ts: t0 + 901_000, quelle: 'tracker', info: 'ST-901' }), true);

  const rows = store.read('target', 'z', t0, t0 + 1_000_000);
  assert.deepEqual(rows.map((r) => r[4]), ['hand', 'tracker']);
  assert.equal(rows[1]?.[5], 'ST-901');
  assert.deepEqual(store.range('member', 'a'), { von: t0, bis: t0 + 300_000 });
  assert.equal(store.read('member', 'a', t0, t0 + 1_000_000, 'andere').length, 0);
});

test('ÖPNV-Position folgt den Zeiten an den Halten', () => {
  const a = {
    punkte: [
      { lat: 53.5, lon: 10 },
      { lat: 53.6, lon: 10 },
    ],
    fahrt: { id: 'f', zeiten: [1000, 2000] },
    weg: [],
  } as unknown as Parameters<typeof transitPosition>[0];
  assert.deepEqual(transitPosition(a, 500), { lat: 53.5, lon: 10 });
  const mid = transitPosition(a, 1500);
  assert.ok(mid && Math.abs(mid.lat - 53.55) < 1e-9);
  assert.deepEqual(transitPosition(a, 9999), { lat: 53.6, lon: 10 });
});

test('Ziel bleibt an der letzten Trackerposition, wenn der Tracker getrennt oder gelöscht wird', () => {
  const lage = newLage();
  const actor = fahnder('a');
  lage.put(actor, 'member', 'a', profil());
  lage.put(actor, 'tracker', 't1', { name: 'ST-901', anbieter: 'sinotrack', kennung: '1234567890' });
  lage.reportTrackerPosition('sinotrack', '1234567890', pos(53.57, 10.02, 1_700_000_000_000));
  lage.put(actor, 'target', 'z', { art: 'fahrzeug', bezeichnung: 'BMW', trackerId: 't1' });
  lage.put(actor, 'target', 'z', { art: 'fahrzeug', bezeichnung: 'BMW', trackerId: null });
  assert.equal(lage.get('target', 'z')?.data.standort?.lat, 53.57);

  lage.put(actor, 'target', 'y', { art: 'fahrzeug', bezeichnung: 'Audi', trackerId: 't1' });
  lage.del(actor, 'tracker', 't1');
  const y = lage.get('target', 'y')?.data;
  assert.equal(y?.trackerId, null);
  assert.equal(y?.standort?.lon, 10.02);
});

test('Spur einer Zielperson: Quelle wechselt mit der Bindung (A, dann Tracker im Zielfahrzeug)', () => {
  const lage = newLage();
  const actor = fahnder('a');
  lage.put(actor, 'member', 'a', profil('Falke'));
  lage.command(actor, 'a.uebernehmen', {});
  const t0 = Date.now() - 60_000;
  lage.reportPosition('a', pos(53.55, 10, t0));
  lage.put(actor, 'target', 'p', { art: 'person', vorname: 'Max', quelle: 'a' });
  lage.recordSpuren(t0 + 1000);
  lage.put(actor, 'tracker', 't1', { name: 'ST-901', anbieter: 'sinotrack', kennung: '1234567890' });
  lage.reportTrackerPosition('sinotrack', '1234567890', pos(53.6, 10.1, t0 + 20_000));
  lage.put(actor, 'target', 'f', { art: 'fahrzeug', bezeichnung: 'BMW', trackerId: 't1' });
  lage.put(actor, 'target', 'p', { art: 'person', vorname: 'Max', quelle: 'a', bindung: { art: 'fahrzeug', zielId: 'f' } });
  lage.recordSpuren(t0 + 30_000);
  const rows = lage.spuren.read('target', 'p', 0, Date.now());
  assert.deepEqual(rows.map((r) => r[4]), ['a', 'tracker']);
  assert.equal(rows[0]?.[5], 'Falke');
  assert.equal(rows[1]?.[5], 'BMW · ST-901');
  // Der Fahnder selbst hat eine GPS-Spur.
  assert.equal(lage.spuren.read('member', 'a', 0, Date.now())[0]?.[4], 'gps');
});

test('Ausgeschaltete Aufzeichnung schreibt keine Spur', () => {
  const lage = newLage();
  const actor = fahnder('a');
  lage.put(actor, 'member', 'a', { ...profil(), aufzeichnung: false });
  lage.reportPosition('a', pos(53.55, 10));
  assert.equal(lage.spuren.read('member', 'a', 0, Date.now() + 1000).length, 0);
});

test('H02: Akku und Empfang aus LINK, Zündung und Alarm aus dem Statuswort', () => {
  const link = parseH02Status('*HQ,1234567890,LINK,120000,31,9,87,0,0,201126#');
  assert.equal(link.akku, 87);
  assert.equal(link.signal, 100);
  assert.equal(link.satelliten, 9);
  const v1 = parseH02Status('*HQ,1234567890,V1,120000,A,5333.0000,N,01000.0000,E,0.00,0,201126,FFFFFBFF#');
  assert.equal(v1.gps, true);
  assert.equal(v1.statusRoh, 'FFFFFBFF');
  assert.equal(v1.zuendung, false);
  assert.equal(v1.alarm, null);
  const power = parseH02Status('*HQ,1234567890,V1,120000,V,5333.0000,N,01000.0000,E,0.00,0,201126,FFF7FFFF#');
  assert.equal(power.gps, false);
  assert.equal(power.stromAus, true);
  assert.equal(power.alarm, 'Stromversorgung unterbrochen');
});

test('H02: V8 und andere Nachrichtenarten mit zusätzlichen Feldern werden gelesen', () => {
  const v8 = parseH02Text('*HQ,7026222172,V8,101530,A,5333.1234,N,01001.5678,E,012.50,090,201126,FFFFFBFF,262,01,1A2B,3C4D#');
  assert.ok(v8);
  assert.equal(v8.kennung, '7026222172');
  assert.ok(Math.abs(v8.position.lat - (53 + 33.1234 / 60)) < 1e-9);
  assert.equal(v8.position.hdg, 90);
  assert.equal(parseH02Status('*HQ,7026222172,V8,101530,A,5333.1234,N,01001.5678,E,012.50,090,201126,FFFFFBFF#').statusRoh, 'FFFFFBFF');
  // V4: Bestätigung mit Befehl und Zeit vor den Positionsfeldern.
  const v4 = parseH02Text('*HQ,7026222172,V4,S20,DONE,101530,A,5333.1234,N,01001.5678,E,0.00,0,201126,FFFFFBFF#');
  assert.ok(v4);
  // Ohne GPS-Empfang keine Position.
  assert.equal(parseH02Text('*HQ,7026222172,V8,101530,V,5333.1234,N,01001.5678,E,0.00,0,201126,FFFFFBFF#'), null);
});
