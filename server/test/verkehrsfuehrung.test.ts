import assert from 'node:assert/strict';
import { test } from 'node:test';
import { destination, type GeoPoint } from '../src/geo.js';
import { durchfahrtspunkte, plausibel, Verkehrsfuehrung, verkehrsfaktor, wenden } from '../src/reach/verkehrsfuehrung.js';

/** Gerade Strecke nach Osten, ein Punkt je 50 m. */
function strecke(start: GeoPoint, meter: number, richtung = 90): GeoPoint[] {
  const punkte: GeoPoint[] = [];
  for (let m = 0; m <= meter; m += 50) punkte.push(destination(start, richtung, m));
  return punkte;
}

const route = (distance: number, duration: number, uturns = 0) => ({
  routes: [{ distance, duration, legs: [{ steps: Array.from({ length: uturns }, () => ({ maneuver: { type: 'turn', modifier: 'uturn' } })) }] }],
});

test('Durchfahrtspunkte alle 1200 m mit Fahrtrichtung, nicht am Ende', () => {
  const pfad = strecke({ lat: 53.55, lon: 10 }, 5000);
  const vias = durchfahrtspunkte(pfad, pfad);
  assert.equal(vias.length, 3);
  assert.equal(vias[0]!.type, 'through');
  assert.equal(vias[0]!.heading, 90);
});

test('Abweichung vom direkten Weg bekommt einen eigenen Punkt', () => {
  const direkt = strecke({ lat: 53.55, lon: 10 }, 1500);
  // Umweg: 300 m nach Norden versetzt in der Mitte
  const pfad = direkt.map((p, i) => (i > 10 && i < 20 ? destination(p, 0, 300) : p));
  const vias = durchfahrtspunkte(pfad, direkt);
  assert.equal(vias.length, 1);
  assert.ok((vias[0]!.lat as number) > 53.551);
});

test('Plausibilität: Umweg nur, wenn TomTom selbst einen fährt; keine zusätzlichen Wenden', () => {
  const weg = { pfad: [], meter: 5000, sekunden: 600 };
  assert.ok(plausibel(route(5050, 500), route(5000, 480), weg));
  assert.ok(!plausibel(route(5050, 500, 1), route(5000, 480), weg));
  assert.ok(!plausibel(route(7000, 700), route(5000, 480), weg));
  assert.ok(plausibel(route(6000, 560), route(5000, 480), { ...weg, meter: 6100 }));
});

test('Verkehrsfaktor begrenzt auf 1 bis 3', () => {
  assert.equal(verkehrsfaktor(route(1, 100), { pfad: [], meter: 1, sekunden: 150 }), 1.5);
  assert.equal(verkehrsfaktor(route(1, 100), { pfad: [], meter: 1, sekunden: 50 }), 1);
  assert.equal(verkehrsfaktor(route(1, 100), null), 1);
  assert.equal(wenden(route(1, 1, 2)), 2);
});

test('TomTom-Antwort wird gelesen und kurz zwischengespeichert', async () => {
  let aufrufe = 0;
  const fetchFn = (async (url: string) => {
    aufrufe++;
    assert.ok(url.includes('traffic=true'));
    return new Response(JSON.stringify({
      routes: [{ summary: { lengthInMeters: 1000, travelTimeInSeconds: 120 }, legs: [{ points: [{ latitude: 53, longitude: 10 }, { latitude: 53.01, longitude: 10 }] }] }],
    }));
  }) as unknown as typeof fetch;
  const f = new Verkehrsfuehrung(() => 'k', fetchFn);
  const weg = await f.weg({ lat: 53, lon: 10 }, { lat: 53.01, lon: 10 });
  assert.equal(weg?.sekunden, 120);
  await f.weg({ lat: 53, lon: 10 }, { lat: 53.01, lon: 10 });
  assert.equal(aufrufe, 1);
  assert.equal(await new Verkehrsfuehrung(() => null, fetchFn).weg({ lat: 1, lon: 1 }, { lat: 2, lon: 2 }), null);
});
