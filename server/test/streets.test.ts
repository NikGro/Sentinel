import assert from 'node:assert/strict';
import { test } from 'node:test';
import { findIntersections } from '../src/oepnv.js';
import { bestStreetMatches, streetSimilarity } from '../src/streets.js';

const names = ['Heegbarg', 'Wentzelplatz', 'Saseler Damm', 'Mönckebergstraße', 'Steinstraße', 'Hegholt', 'Wellingsbütteler Landstraße'];

test('Straßennamen mit Tipp- und Hörfehlern werden zugeordnet', () => {
  assert.deepEqual(bestStreetMatches('Hegbark', names).slice(0, 1), ['Heegbarg']);
  assert.deepEqual(bestStreetMatches('Wenzelplatz', names).slice(0, 1), ['Wentzelplatz']);
  assert.deepEqual(bestStreetMatches('Mönckebergstr.', names).slice(0, 1), ['Mönckebergstraße']);
  assert.deepEqual(bestStreetMatches('Monckeberg', names).slice(0, 1), ['Mönckebergstraße']);
  assert.ok(streetSimilarity('Saseler Damm', 'Saseler Damm') === 1);
  assert.deepEqual(bestStreetMatches('Bahnhofstraße', names), [], 'Nichts Unplausibles');
});

test('Kreuzung: genauer Name zuerst, sonst die ähnlichsten Straßen der Umgebung', async () => {
  const queries: string[] = [];
  const overpass = {
    async query(ql: string) {
      queries.push(ql);
      if (ql.includes('out tags')) {
        if (ql.includes('around:25')) return { elements: [{ tags: { name: 'Heegbarg' } }, { tags: { name: 'Wentzelplatz' } }] };
        return { elements: names.map((name) => ({ tags: { name } })) };
      }
      // Kreuzung nur mit den echten Namen.
      if (ql.includes('^Heegbarg$') && ql.includes('^Wentzelplatz$')) return { elements: [{ type: 'node', id: 1, lat: 53.65, lon: 10.09 }] };
      return { elements: [] };
    },
  };
  const result = await findIntersections(overpass, 'Hegbark', 'Wenzelplatz', { lat: 53.65, lon: 10.09 });
  assert.equal(result.punkte.length, 1);
  assert.equal(result.a, 'Heegbarg');
  assert.equal(result.b, 'Wentzelplatz');
});
