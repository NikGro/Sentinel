import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { cellCorners, selectCells } from '../src/argus.js';
import { distanceMeters, utmToWgs84 } from '../src/geo.js';
import { MapKitTokens } from '../src/mapkit.js';
import { modelRadiusMeters, ReachService } from '../src/reach/reach.js';
import { costingFor, decodePolyline6, RouteService, sonderrechteLohnen } from '../src/reach/route.js';
import { hashPassword, RateLimiter, Vault, verifyPassword } from '../src/security.js';
import { intervalCommand, parseH02Binary, parseH02Text } from '../src/trackers/h02.js';
import { nextStopIndex, OepnvStore, parseRoutes } from '../src/oepnv.js';
import { sniffMime } from '../src/http/device.js';

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

test('Apple Maps: Token ist ES256-signiert und an die eigene Adresse gebunden', () => {
  assert.equal(new MapKitTokens({ teamId: '', keyId: '', keyFile: '' }, 'https://x').configured, false);
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const keyFile = join(mkdtempSync(join(tmpdir(), 'sentinel-mapkit-')), 'AuthKey.p8');
  writeFileSync(keyFile, privateKey.export({ type: 'pkcs8', format: 'pem' }));
  const tokens = new MapKitTokens({ teamId: 'TEAM123456', keyId: 'KEY1234567', keyFile }, 'https://sentinel.example.org');
  assert.ok(tokens.configured);
  const [header, payload, signature] = tokens.issue(1_700_000_000_000)!.split('.') as [string, string, string];
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url').toString()), { alg: 'ES256', kid: 'KEY1234567', typ: 'JWT' });
  const claims = JSON.parse(Buffer.from(payload, 'base64url').toString());
  assert.equal(claims.iss, 'TEAM123456');
  assert.equal(claims.origin, 'https://sentinel.example.org');
  assert.equal(claims.exp - claims.iat, 1800);
  assert.ok(verify('sha256', Buffer.from(`${header}.${payload}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature, 'base64url')));
});

test('Route: Linienzug wird entpackt', () => {
  // Bekanntes Beispiel des Polyline-Verfahrens, hier mit sechs Nachkommastellen kodiert.
  assert.deepEqual(decodePolyline6('_izlhA~rlgdF_{geC~ywl@_kwzCn`{nI'), [[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]]);
});

test('Route: Sonderrechte ignorieren Einbahnstraßen und Abbiegeverbote, aber keine Zufahrtssperren', async () => {
  const special = costingFor({ sonderrechte: true, zuFuss: false }).costing_options.auto as Record<string, unknown>;
  assert.equal(special.ignore_oneways, true);
  assert.equal(special.ignore_restrictions, true);
  assert.equal('ignore_access' in special, false, 'Poller und andere Sperren bleiben beachtet');
  assert.deepEqual(costingFor({ sonderrechte: false, zuFuss: false }).costing_options, {});
  assert.equal(costingFor({ sonderrechte: true, zuFuss: true }).costing, 'pedestrian');

  let sent: any;
  const ok = (async (_url: string, init: RequestInit) => {
    sent = JSON.parse(init.body as string);
    return new Response(JSON.stringify({ trip: { summary: { length: 0.76, time: 105 }, legs: [{ shape: '_izlhA~rlgdF_{geC~ywl@', maneuvers: [{ instruction: 'Links abbiegen.', length: 0.2 }] }] } }));
  }) as typeof fetch;
  const result = await new RouteService('http://valhalla', ok).route({ lat: 53.55, lon: 9.99 }, { lat: 53.56, lon: 10 }, { sonderrechte: true, zuFuss: false });
  assert.equal(sent.costing_options.auto.ignore_oneways, true);
  assert.equal(sent.directions_options.language, 'de-DE');
  assert.equal(result?.meter, 760);
  assert.equal(result?.sekunden, 70, 'mit Sonderrechten rund 50 % schneller als die 105 s des Wegenetzes');
  assert.equal(result?.anweisungen[0]?.text, 'Links abbiegen.');
  assert.equal(result?.sonderrechte, true);
  assert.equal(await new RouteService('', ok).route({ lat: 1, lon: 1 }, { lat: 2, lon: 2 }, { sonderrechte: false, zuFuss: false }), null);
});

test('Navigation: gegen die Einbahnstraße nur, wenn es wirklich Zeit spart', async () => {
  // Innenkurve auf einer Straße mit Mittelstreifen: 10 s Ersparnis lohnen den Gegenverkehr nicht.
  assert.equal(sonderrechteLohnen(300, 290), false);
  // Echte Abkürzung durch eine Einbahnstraße: zwei Minuten schneller.
  assert.equal(sonderrechteLohnen(600, 480), true);
  // Lange Fahrt: 45 s reichen nicht, es müssen auch 12 % sein.
  assert.equal(sonderrechteLohnen(1800, 1750), false);

  const sent: any[] = [];
  const valhalla = (dauerNormal: number, dauerSchnell: number) =>
    (async (_url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      sent.push(body);
      const schnell = body.costing_options?.auto?.ignore_oneways === true;
      return new Response(JSON.stringify({ routes: [{ duration: schnell ? dauerSchnell : dauerNormal, legs: [{ duration: schnell ? dauerSchnell : dauerNormal, steps: [{ duration: 30 }] }] }] }));
    }) as typeof fetch;
  const anfrage = { costing: 'auto', locations: [{ lat: 53.55, lon: 9.99 }, { lat: 53.56, lon: 10 }], format: 'osrm' };

  const knapp = await new RouteService('http://valhalla', valhalla(300, 290)).navigation(anfrage, true);
  assert.equal(knapp?.sonderrechte, false, 'kaum schneller: regelkonforme Route');
  assert.equal(sent.length, 2, 'beide Varianten werden gerechnet');
  assert.equal(sent[0].directions_options.language, 'de-DE');
  assert.equal((knapp?.antwort as any).routes[0].duration, 200, 'Tempo mit Sonderrechten gilt trotzdem');

  const lohnend = await new RouteService('http://valhalla', valhalla(600, 450)).navigation(anfrage, true);
  assert.equal(lohnend?.sonderrechte, true);
  assert.equal((lohnend?.antwort as any).routes[0].duration, 300);

  sent.length = 0;
  const normal = await new RouteService('http://valhalla', valhalla(600, 450)).navigation(anfrage, false);
  assert.equal(normal?.sonderrechte, false);
  assert.equal(sent.length, 1, 'ohne Sonderrechte nur eine Anfrage');
  assert.equal((normal?.antwort as any).routes[0].duration, 600);
});

test('ÖPNV: Routen aus OpenStreetMap werden zu Linien mit geordneten Halten', () => {
  const node = (id: number, lat: number, name: string) => ({ type: 'node' as const, id, lat, lon: 10, tags: { name } });
  const lines = parseRoutes([
    node(1, 53.50, 'Start'), node(2, 53.5001, 'Start'), node(3, 53.51, 'Mitte'), node(4, 53.52, 'Ende'),
    { type: 'relation', id: 99, tags: { ref: 'U3', route: 'subway', to: 'Ende' }, members: [
      { type: 'node', ref: 1, role: 'stop' }, { type: 'node', ref: 2, role: 'platform' }, { type: 'node', ref: 3, role: 'stop' }, { type: 'node', ref: 4, role: 'stop_exit_only' }, { type: 'way', ref: 7, role: '' },
    ] },
    { type: 'relation', id: 100, tags: { route: 'bus' }, members: [] },
  ]);
  assert.equal(lines.length, 1);
  assert.deepEqual(lines[0]!.halte.map((h) => h.name), ['Start', 'Mitte', 'Ende']);
  assert.equal(lines[0]!.nach, 'Ende');
});

test('ÖPNV: nächster Halt ab Standort, Suche nach Linie und in der Nähe', () => {
  const halte = [0, 1, 2, 3].map((i) => ({ lat: 53.5 + i * 0.01, lon: 10 }));
  assert.equal(nextStopIndex(halte, { lat: 53.5, lon: 10 }), 1);
  assert.equal(nextStopIndex(halte, { lat: 53.515, lon: 10.0005 }), 2);
  assert.equal(nextStopIndex(halte, { lat: 53.53, lon: 10 }), 4);
  const store = new OepnvStore(mkdtempSync(join(tmpdir(), 'sentinel-oepnv-')), [53, 9, 54, 11], null);
  (store as unknown as { setLines(l: unknown[]): void }).setLines([
    { id: '1', ref: 'U3', typ: 'subway', von: 'A', nach: 'Barmbek', halte: halte.map((h, i) => ({ ...h, name: `H${i}` })) },
    { id: '2', ref: 'U3', typ: 'subway', von: 'B', nach: 'Wandsbek', halte: [...halte].reverse().map((h, i) => ({ ...h, name: `H${i}` })) },
    { id: '3', ref: '269', typ: 'bus', von: 'C', nach: 'Ort', halte: [{ name: 'X', lat: 54, lon: 11 }, { name: 'Y', lat: 54.01, lon: 11 }] },
  ]);
  assert.deepEqual(store.search('u 3', null).map((r) => r.richtung), ['Barmbek', 'Wandsbek']);
  assert.deepEqual(store.search('', { lat: 53.5, lon: 10 }).map((r) => r.id).sort(), ['1', '2']);
  assert.deepEqual(store.upcoming('1', { lat: 53.515, lon: 10 }, 5).map((h) => h.name), ['H2', 'H3']);
  // Haltestellen nach Namen: gleichnamige Steige zusammengefasst, mit den dort haltenden Linien.
  const stops = store.searchStops('h1', { lat: 53.5, lon: 10 });
  assert.ok(stops.length >= 1);
  assert.ok(stops[0]!.linien.some((l) => l.ref === 'U3'));
  assert.deepEqual(store.searchStops('a', null), []);
});

test('Dateityp wird am Inhalt erkannt', () => {
  assert.equal(sniffMime(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0])), 'image/jpeg');
  assert.equal(sniffMime(Buffer.from('%PDF-1.7')), 'application/pdf');
  assert.equal(sniffMime(Buffer.concat([Buffer.from([0, 0, 0, 0x20]), Buffer.from('ftypM4A '), Buffer.alloc(8)])), 'audio/mp4');
  assert.equal(sniffMime(Buffer.from('<html>')), 'application/octet-stream');
});

test('SinoTrack: Befehl für das Sendeintervall', () => {
  assert.equal(intervalCommand('9170123456', 30, new Date(Date.UTC(2026, 10, 15, 12, 5, 9))), '*HQ,9170123456,S71,120509,22,30#');
});

test('Route: Manöver tragen ihre Position im Linienzug', async () => {
  const ok = (async () =>
    new Response(JSON.stringify({ trip: { summary: { length: 1, time: 60 }, legs: [{ shape: '_izlhA~rlgdF_{geC~ywl@', maneuvers: [{ instruction: 'Los', length: 0.5, begin_shape_index: 0 }, { instruction: 'Rechts', length: 0.5, begin_shape_index: 1 }] }] } }))) as typeof fetch;
  const result = await new RouteService('http://v', ok).route({ lat: 1, lon: 1 }, { lat: 2, lon: 2 }, { sonderrechte: false, zuFuss: false });
  assert.deepEqual(result?.anweisungen.map((a) => a.index), [0, 1]);
});

test('ÖPNV-Fluchtraum: entlang der Linien statt Kreis, als zusammenhängende Umrisse', async () => {
  const { transitCircles, unionOutlines } = await import('../src/reach/transit.js');
  // U-Bahn nach Osten ab dem Start, Bus nach Norden ab dem dritten Halt (Umsteigen).
  const u = { id: 'u', typ: 'subway', halte: [0, 1, 2, 3, 4, 5].map((i) => ({ lat: 53.55, lon: 10 + i * 0.01 })) };
  const bus = { id: 'b', typ: 'bus', halte: [0, 1, 2, 3].map((i) => ({ lat: 53.55 + i * 0.008, lon: 10.02 })) };
  const fern = { id: 'f', typ: 'bus', halte: [{ lat: 54, lon: 11 }, { lat: 54.01, lon: 11 }] };
  const circles = transitCircles([u, bus, fern], { lat: 53.55, lon: 10 }, 20);
  assert.ok(circles.length > 3, 'Start und erreichte Halte');
  assert.ok(circles.some((c) => c.center.lon >= 10.04), 'mit der U-Bahn weiter nach Osten');
  assert.ok(circles.some((c) => c.center.lat >= 53.555), 'nach dem Umsteigen mit dem Bus nach Norden');
  assert.ok(!circles.some((c) => c.center.lat > 53.9), 'unerreichbare Linie bleibt außen vor');
  const rings = unionOutlines(circles);
  assert.ok(rings.length >= 1);
  for (const ring of rings) assert.ok(ring.length >= 8 && ring.every(([lat, lon]) => Number.isFinite(lat) && Number.isFinite(lon)));
  // Zwei getrennte Kreise ergeben zwei Umrisse.
  assert.equal(unionOutlines([{ center: { lat: 53.5, lon: 10 }, radius: 100 }, { center: { lat: 53.6, lon: 10 }, radius: 100 }]).length, 2);
});

test('ÖPNV: Fahrweg aus den Wegen der Linie, Farbe aus OpenStreetMap', async () => {
  const { stitchWays } = await import('../src/oepnv.js');
  // Zweiter Weg liegt verkehrt herum und wird angeschlossen.
  const path = stitchWays([
    [{ lat: 53.5, lon: 10 }, { lat: 53.501, lon: 10 }],
    [{ lat: 53.503, lon: 10.002 }, { lat: 53.502, lon: 10.001 }, { lat: 53.501, lon: 10 }],
  ]);
  assert.deepEqual(path[0], [53.5, 10]);
  assert.deepEqual(path.at(-1), [53.503, 10.002]);
  const lines = parseRoutes([
    { type: 'relation', id: 9, tags: { route: 'subway', ref: 'U1', colour: '#0072bc' }, members: [
      { type: 'node', ref: 1, role: 'stop' }, { type: 'node', ref: 2, role: 'stop' }, { type: 'way', ref: 5, role: '' },
    ] },
    { type: 'node', id: 1, lat: 53.5, lon: 10, tags: { name: 'A' } },
    { type: 'node', id: 2, lat: 53.51, lon: 10, tags: { name: 'B' } },
    { type: 'way', id: 5, geometry: [{ lat: 53.5, lon: 10 }, { lat: 53.505, lon: 10.003 }, { lat: 53.51, lon: 10 }] },
  ]);
  assert.equal(lines[0]?.farbe, '#0072BC');
  assert.equal(lines[0]?.weg?.length, 3);
});

test('Transitous: Linienzüge, Verkehrsarten und fahrende Fahrzeuge', async () => {
  const { decodePolyline, normalizeMode, TransitousClient } = await import('../src/transit/transitous.js');
  // Bekanntes Beispiel aus der Google-Dokumentation (Genauigkeit 5).
  assert.deepEqual(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), [[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]]);
  assert.equal(normalizeMode('AIRPLANE'), null);
  assert.equal(normalizeMode('HIGHSPEED_RAIL'), 'RAIL');
  assert.equal(normalizeMode('BUS'), 'BUS');
  const now = Date.now();
  const fake = (async () => new Response(JSON.stringify([
    { mode: 'BUS', trips: [{ tripId: 't1', displayName: '4' }], from: { name: 'A', stopId: 'a', lat: 53.55, lon: 9.99 }, to: { name: 'B', stopId: 'b', lat: 53.56, lon: 10 },
      departure: new Date(now).toISOString(), arrival: new Date(now + 120_000).toISOString(), scheduledDeparture: new Date(now - 60_000).toISOString(), realTime: true, polyline: '_p~iF~ps|U' },
    { mode: 'AIRPLANE', trips: [{ tripId: 'f1' }], from: {}, to: {}, departure: '', arrival: '' },
  ]))) as unknown as typeof fetch;
  const client = new TransitousClient('https://example.invalid', fake);
  const segments = await client.liveSegments({ lat: 53.5, lon: 9.9 }, { lat: 53.6, lon: 10.1 }, 14);
  assert.equal(segments.length, 1);
  assert.equal(segments[0]!.name, '4');
  assert.equal(segments[0]!.delay, 60);
  assert.equal(segments[0]!.path.length, 1);
});
