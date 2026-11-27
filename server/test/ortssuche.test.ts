import assert from 'node:assert/strict';
import { test } from 'node:test';
import { hausnummerNachHinten, kreuzungTeilen, Ortssuche, photonTreffer } from '../src/suche/ortssuche.js';

test('Hausnummer zuerst wird umgestellt', () => {
  assert.equal(hausnummerNachHinten('12 Musterstraße'), 'Musterstraße 12');
  assert.equal(hausnummerNachHinten('Musterstraße 12'), 'Musterstraße 12');
  assert.equal(hausnummerNachHinten('3a Heegbarg'), 'Heegbarg 3a');
});

test('Kreuzungen werden erkannt, Hausnummern nicht', () => {
  assert.deepEqual(kreuzungTeilen('Heegbarg Ecke Wentzelplatz'), ['Heegbarg', 'Wentzelplatz']);
  assert.deepEqual(kreuzungTeilen('Mönckebergstraße / Steinstraße'), ['Mönckebergstraße', 'Steinstraße']);
  assert.equal(kreuzungTeilen('Musterstraße 12'), null);
  assert.equal(kreuzungTeilen('A / 12'), null);
});

test('Photon-Anschrift wird übersetzt und als exakt erkannt', () => {
  const t = photonTreffer(
    { geometry: { coordinates: [10.05, 53.6] }, properties: { osm_type: 'N', osm_id: 1, housenumber: '12', street: 'Musterstraße', postcode: '22391', city: 'Hamburg', type: 'house' } },
    '12 Musterstr.',
  );
  assert.equal(t?.art, 'adresse');
  assert.equal(t?.titel, 'Musterstraße 12');
  assert.equal(t?.untertitel, '22391 Hamburg');
  assert.equal(t?.exakt, true);
});

test('Suche: Kreuzung zuerst, dann Photon-Treffer nach Art', async () => {
  const fetchFn = (async () =>
    new Response(
      JSON.stringify({
        features: [
          { geometry: { coordinates: [10, 53.5] }, properties: { osm_key: 'amenity', name: 'Heegbarg-Café', street: 'Heegbarg', city: 'Hamburg' } },
          { geometry: { coordinates: [10.1, 53.6] }, properties: { osm_key: 'highway', type: 'street', name: 'Heegbarg', city: 'Hamburg' } },
        ],
      }),
    )) as typeof fetch;
  const suche = new Ortssuche('http://photon', { intersection: () => ({ punkte: [{ lat: 53.65, lon: 10.09 }], a: 'Heegbarg', b: 'Wentzelplatz' }) }, fetchFn);
  const treffer = await suche.suche('Heegbarg / Wentzelplatz', { lat: 53.6, lon: 10 });
  assert.deepEqual(treffer.map((t) => t.art), ['kreuzung', 'strasse', 'poi']);
});
