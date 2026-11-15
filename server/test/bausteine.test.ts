import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cellCorners, selectCells } from '../src/argus.js';
import { distanceMeters, utmToWgs84 } from '../src/geo.js';
import { modelRadiusMeters, ReachService } from '../src/reach/reach.js';
import { hashPassword, RateLimiter, Vault, verifyPassword } from '../src/security.js';
import { parseH02Binary, parseH02Text } from '../src/trackers/h02.js';

test('UTM 32N nach WGS84 (Hamburger Rathaus)', () => {
  const p = utmToWgs84(565_835.6, 5_933_949.0);
  assert.ok(distanceMeters(p, { lat: 53.5503, lon: 9.9937 }) < 2, `${p.lat}, ${p.lon}`);
});

test('Argus: Zelle wird zu vier Ecken mit 500 m Kantenlänge', () => {
  const ecken = cellCorners('Z500_568000_5942000')!;
  assert.equal(ecken.length, 4);
  assert.ok(Math.abs(distanceMeters(ecken[0]!, ecken[1]!) - 500) < 2);
  assert.equal(cellCorners('kaputt'), null);
});

test('Argus: wählt die auffälligsten Zellen im Zeitraum', () => {
  const csv = ['zelle_id,datum,stunde,rate,fold', 'Z500_568000_5942000,2026-11-15,20,0.00003,0', 'Z500_568500_5942000,2026-11-15,20,0.00001,0', 'Z500_569000_5942000,2026-11-15,3,0.9,0', 'Z500_568000_5942000,2026-11-16,20,0.9,0'].join('\n');
  const cells = selectCells(csv, 0.00001, '2026-11-15', 18, 23, 1);
  assert.equal(cells.length, 1);
  assert.equal(cells[0]!.zelleId, 'Z500_568000_5942000');
  assert.ok(Math.abs(cells[0]!.faktor - 3) < 1e-9);
});

test('H02-Text: gültige Position', () => {
  const fix = parseH02Text('*HQ,9170123456,V1,121530,A,5333.0180,N,00959.6220,E,010.50,090,151126,FFFFFBFF#')!;
  assert.equal(fix.kennung, '9170123456');
  assert.ok(Math.abs(fix.position.lat - 53.5503) < 1e-4);
  assert.ok(Math.abs(fix.position.lon - 9.99370) < 1e-4);
  assert.equal(fix.position.ts, Date.UTC(2026, 10, 15, 12, 15, 30));
  assert.equal(fix.position.hdg, 90);
});

test('H02-Text: ohne GPS-Empfang oder Müll gibt es keine Position', () => {
  assert.equal(parseH02Text('*HQ,9170123456,V1,121530,V,5333.0180,N,00959.6220,E,0.00,0,151126,FFFFFBFF#'), null);
  assert.equal(parseH02Text('*HQ,9170123456,XT#'), null);
  assert.equal(parseH02Text('GET / HTTP/1.1'), null);
});

test('H02-Binär: gültige Position', () => {
  // Kennung 9170123456, 12:15:30, 15.11.26, 53°33.0180' N, Akku, 009°59.6220' E, Flags E|N|gültig, 10 kn, Kurs 90
  const hex = '24' + '9170123456' + '121530' + '151126' + '53330180' + '06' + '009596220' + 'e' + '010' + '090' + 'ffffbbff' + '00';
  const fix = parseH02Binary(Buffer.from(hex.padEnd(64, '0'), 'hex'))!;
  assert.equal(fix.kennung, '9170123456');
  assert.ok(Math.abs(fix.position.lat - 53.5503) < 1e-4);
  assert.ok(Math.abs(fix.position.lon - 9.9937) < 1e-4);
});

test('Weg-Zeit-Modell wächst mit der Zeit, Kfz > ÖPNV > Fuß', () => {
  assert.ok(modelRadiusMeters('fuss', 30) > modelRadiusMeters('fuss', 10));
  assert.ok(modelRadiusMeters('kfz', 30) > modelRadiusMeters('oepnv', 30));
  assert.ok(modelRadiusMeters('oepnv', 30) > modelRadiusMeters('fuss', 30));
  assert.ok(modelRadiusMeters('oepnv', 2) >= modelRadiusMeters('fuss', 2));
});

test('Weg-Zeit: Valhalla-Fläche wird übernommen, bei Fehler greift das Modell', async () => {
  const ok = (async () => new Response(JSON.stringify({ features: [{ geometry: { type: 'Polygon', coordinates: [[[10, 53], [10.1, 53], [10.1, 53.1], [10, 53]]] } }] }))) as typeof fetch;
  const viaRouting = await new ReachService('http://valhalla', ok).compute({ lat: 53, lon: 10 }, 10, ['fuss', 'oepnv']);
  assert.equal(viaRouting[0]!.quelle, 'valhalla');
  assert.deepEqual(viaRouting[0]!.ringe[0]![0], [53, 10]);
  assert.equal(viaRouting[1]!.quelle, 'modell');
  const broken = (async () => new Response('', { status: 500 })) as typeof fetch;
  const fallback = await new ReachService('http://valhalla', broken).compute({ lat: 53, lon: 10 }, 10, ['kfz']);
  assert.equal(fallback[0]!.quelle, 'modell');
});

test('Sicherheit: Passwort-Hash, Tresor, Ratenbegrenzung', async () => {
  const hash = await hashPassword('korrekt-pferd-batterie');
  assert.ok(await verifyPassword('korrekt-pferd-batterie', hash));
  assert.ok(!(await verifyPassword('falsch', hash)));
  const vault = new Vault('schluessel');
  assert.equal(vault.open(vault.seal('geheim')), 'geheim');
  assert.equal(new Vault('anderer').open(vault.seal('geheim')), null);
  const limiter = new RateLimiter(2, 1000);
  assert.deepEqual([limiter.take('ip', 0), limiter.take('ip', 1), limiter.take('ip', 2), limiter.take('ip', 1001)], [true, true, false, true]);
});
