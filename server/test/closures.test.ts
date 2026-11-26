import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ClosureService, istVollsperrung, sperrpunkt } from '../src/reach/closures.js';
import { RouteService } from '../src/reach/route.js';

const line = { type: 'LineString', coordinates: [[10.0, 53.5], [10.0, 53.51], [10.0, 53.52]] as [number, number][] };

test('Sperrungen: nur aktuelle Vollsperrungen zählen, Meidepunkt mittig mit Fahrtrichtung', () => {
  assert.equal(istVollsperrung({ impact: { symbols: ['SEPARATE', 'CLOSED', 'BORDER_RIGHT', 'CLOSED'] } }), true);
  assert.equal(istVollsperrung({ impact: { symbols: ['SEPARATE', 'CLOSED', 'BORDER_RIGHT', 'CLOSED'] }, future: true }), false);
  assert.equal(istVollsperrung({ impact: { symbols: ['CLOSED', 'ARROW_UP'] } }), false);
  assert.equal(istVollsperrung({ impact: { symbols: [] } }), false);
  const punkt = sperrpunkt({ geometry: line, title: 'A7' });
  assert.ok(punkt && Math.abs(punkt.punkt.lat - 53.51) < 0.0005);
  assert.ok(punkt && (punkt.kurs < 1 || punkt.kurs > 359));
});

test('Sperrungen: im Umfeld der Strecke, nicht weit entfernt', async () => {
  const service = new ClosureService(false);
  service.replace([
    { titel: 'nah', punkt: { lat: 53.55, lon: 10.0 }, kurs: 90 },
    { titel: 'fern', punkt: { lat: 48.1, lon: 11.5 }, kurs: 0 },
  ]);
  const near = service.near([{ lat: 53.5, lon: 9.9 }, { lat: 53.6, lon: 10.1 }]);
  assert.equal(near.length, 1);
  assert.equal(near[0]!.heading, 90);
});

test('Sperrungen laden: Autobahn-Dienst, Fahrstreifen-Einengungen bleiben', async () => {
  const fetchFn = (async (url: string) => {
    const body = url.endsWith('/autobahn/')
      ? { roads: ['A7', 'Hamburg'] }
      : { closure: [
          { title: 'voll', impact: { symbols: ['SEPARATE', 'CLOSED'] }, geometry: line },
          { title: 'eng', impact: { symbols: ['CLOSED', 'LANE'] }, geometry: line },
        ] };
    return new Response(JSON.stringify(body));
  }) as typeof fetch;
  const service = new ClosureService(true, fetchFn);
  await service.refresh();
  assert.equal(service.count, 1);
});

test('Navigation: Meidepunkte gehen an Valhalla, ohne Weg damit gilt die Route ohne', async () => {
  const bodies: Record<string, unknown>[] = [];
  const fetchFn = (async (_url: string, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    bodies.push(body);
    if (body.exclude_locations) return new Response('kein Weg', { status: 400 });
    return new Response(JSON.stringify({ routes: [{ duration: 100, distance: 1000 }] }));
  }) as typeof fetch;
  const routes = new RouteService('http://valhalla', fetchFn);
  const anfrage = { costing: 'auto', locations: [{ lat: 53.5, lon: 10 }, { lat: 53.6, lon: 10.1 }] };
  const result = await routes.navigation(anfrage, false, [{ lat: 53.55, lon: 10.05, radius: 5 }]);
  assert.equal(result?.gemieden, false);
  assert.ok(bodies.some((b) => Array.isArray(b.exclude_locations)));
  assert.ok(bodies.some((b) => !b.exclude_locations));
});
