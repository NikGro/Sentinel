import assert from 'node:assert/strict';
import { test } from 'node:test';
import { IncidentService, istGesperrt, linien, meidepunkte } from '../src/reach/incidents.js';

const strasse = { type: 'LineString', coordinates: [[10.0, 53.55], [10.0, 53.552], [10.0, 53.554]] };

test('TomTom: nur Sperrungen zählen, Baustellen nur mit Sperrvermerk', () => {
  assert.equal(istGesperrt({ properties: { iconCategory: 8 } }), true);
  assert.equal(istGesperrt({ properties: { iconCategory: 9, magnitudeOfDelay: 4 } }), true);
  assert.equal(istGesperrt({ properties: { iconCategory: 9, magnitudeOfDelay: 1 } }), false);
  assert.equal(istGesperrt({ properties: { iconCategory: 6, events: [{ iconCategory: 8 }] } }), true);
  assert.equal(linien({ geometry: strasse }).length, 1);
  assert.equal(linien({ geometry: { type: 'MultiLineString', coordinates: [strasse.coordinates, strasse.coordinates] } }).length, 2);
});

test('TomTom: Meidepunkte entlang des Abschnitts, mit Fahrtrichtung, nicht an den Enden', () => {
  const punkte = meidepunkte(linien({ geometry: strasse })[0]!);
  // gut 440 m: Punkte etwa alle 80 m.
  assert.ok(punkte.length >= 4 && punkte.length <= 6, `${punkte.length}`);
  assert.ok(punkte.every((p) => p.heading === 0 && p.lat > 53.5501 && p.lat < 53.5539));
  // Sehr kurz: ein Punkt in der Mitte.
  assert.equal(meidepunkte([{ lat: 53.55, lon: 10 }, { lat: 53.5503, lon: 10 }]).length, 1);
});

test('TomTom: Abfrage nur mit Schlüssel und nur für das Rechteck, Meidepunkte im Umfeld der Strecke', async () => {
  const urls: string[] = [];
  const fetchFn = (async (url: string) => {
    urls.push(url);
    return new Response(JSON.stringify({ incidents: [
      { geometry: strasse, properties: { iconCategory: 8, events: [{ description: 'Gesperrt' }], from: 'A', to: 'B' } },
      { geometry: strasse, properties: { iconCategory: 9, magnitudeOfDelay: 1 } },
    ] }));
  }) as typeof fetch;
  let key: string | null = null;
  const service = new IncidentService([53.3, 9.5, 53.9, 10.5], () => key, fetchFn);
  await service.refresh();
  assert.equal(urls.length, 0, 'ohne Schlüssel keine Abfrage');
  key = 'test-schluessel-123';
  await service.refresh();
  assert.equal(service.count, 1);
  assert.ok(urls[0]!.includes('bbox=9.5,53.3,10.5,53.9'));
  assert.ok(service.near([{ lat: 53.549, lon: 10 }, { lat: 53.56, lon: 10.01 }]).length > 0);
  assert.equal(service.near([{ lat: 48.1, lon: 11.5 }, { lat: 48.2, lon: 11.6 }]).length, 0);
});
