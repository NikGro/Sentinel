import assert from 'node:assert/strict';
import { test } from 'node:test';
import { crossStreetsFromWays } from '../src/reach/crossings.js';

// Route nach Osten entlang der Hauptstraße (lat 53.5), etwa 1,3 km.
const route = [
  { lat: 53.5, lon: 10.0 },
  { lat: 53.5, lon: 10.02 },
];
const way = (name: string, geometry: { lat: number; lon: number }[]) => ({ type: 'way', tags: { name }, geometry });

test('Querstraßen: kreuzende und einmündende Straßen, nicht die eigene', () => {
  const streets = crossStreetsFromWays(route, [
    way('Hauptstraße', [{ lat: 53.5, lon: 9.999 }, { lat: 53.5, lon: 10.01 }]),
    way('Hauptstraße', [{ lat: 53.5, lon: 10.01 }, { lat: 53.5, lon: 10.021 }]),
    // Kreuzt bei etwa 330 m.
    way('Querweg', [{ lat: 53.499, lon: 10.005 }, { lat: 53.501, lon: 10.005 }]),
    // Mündet bei etwa 990 m von Norden ein (endet auf der Route).
    way('Nordring', [{ lat: 53.502, lon: 10.015 }, { lat: 53.5, lon: 10.015 }]),
    // Liegt daneben.
    way('Fernweg', [{ lat: 53.51, lon: 10.0 }, { lat: 53.51, lon: 10.02 }]),
  ]);
  assert.deepEqual(streets.map((s) => s.name), ['Querweg', 'Nordring']);
  assert.ok(Math.abs(streets[0]!.meter - 331) < 10);
  assert.ok(Math.abs(streets[1]!.meter - 992) < 10);
});
