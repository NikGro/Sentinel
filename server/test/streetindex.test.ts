import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { StreetIndex } from '../src/streetindex.js';

/** Kleines Netz: Heegbarg kreuzt Wentzelplatz (Knoten 2) und Tangstedter Landstraße (Knoten 3). */
function index(): StreetIndex {
  const dir = mkdtempSync(join(tmpdir(), 'sentinel-strassen-'));
  writeFileSync(join(dir, 'strassen.json'), JSON.stringify({
    names: ['Heegbarg', 'Wentzelplatz', 'Tangstedter Landstraße'],
    ways: [[0, [1, 2, 3]], [1, [4, 2]], [2, [5, 3, 6]]],
    nodes: { 1: [53.65, 10.08], 2: [53.651, 10.081], 3: [53.652, 10.083], 4: [53.6515, 10.0805], 5: [53.653, 10.084], 6: [53.6525, 10.0835] },
  }));
  return new StreetIndex(dir, [53.3, 9.5, 53.9, 10.5], null);
}

test('Straßenverzeichnis: Querstraßen und Kreuzungen ohne Overpass, auch mit Tippfehlern', () => {
  const streets = index();
  assert.equal(streets.ready, true);
  const near = { lat: 53.651, lon: 10.081 };
  const crossings = streets.crossingStreets('Heegbarg', near);
  assert.deepEqual(crossings?.strassen.map((s) => s.name), ['Wentzelplatz', 'Tangstedter Landstraße']);
  // Tippfehler in beiden Namen, „Str.“ abgekürzt.
  const hit = streets.intersection('Hegbark', 'Tangstedter Landstr.', near);
  assert.equal(hit?.a, 'Heegbarg');
  assert.equal(hit?.b, 'Tangstedter Landstraße');
  assert.equal(hit?.punkte[0]?.lat, 53.652);
  assert.equal(streets.intersection('Hegbark', 'Wenzelplatz', near)?.b, 'Wentzelplatz');
});

test('Parallel-Modus: Meidepunkte nur auf der Straße des Ziels und nur voraus', () => {
  const streets = index();
  // Ziel kurz hinter Knoten 1 auf dem Heegbarg, Richtung Nordost.
  const ahead = streets.pointsAhead({ lat: 53.6501, lon: 10.0801 }, 35, 600);
  assert.equal(ahead?.strasse, 'Heegbarg');
  assert.ok((ahead?.punkte.length ?? 0) >= 1);
  // Alle Punkte liegen zwischen Knoten des Heegbargs, keiner auf einer Kreuzung.
  for (const p of ahead!.punkte) assert.ok(p.lat > 53.65 && p.lat < 53.652);
  // In Gegenrichtung liegt nichts voraus.
  assert.equal(streets.pointsAhead({ lat: 53.6519, lon: 10.0829 }, 35 + 180, 600)?.punkte.filter((p) => p.lat > 53.652).length, 0);
  // Weit weg von jeder Straße: keine Angabe.
  assert.equal(streets.pointsAhead({ lat: 53.7, lon: 10.2 }, 0, 600), null);
});
