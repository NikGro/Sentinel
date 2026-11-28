import assert from 'node:assert/strict';
import { test } from 'node:test';
import { kartenstil } from '../src/karte/stil.js';

const ids = (s: Record<string, unknown>) => (s.layers as { id: string }[]).map((l) => l.id);

test('Kartenstil: 3D-Gebäude nur ohne „flach“', () => {
  assert.ok(ids(kartenstil('hell', 'https://s')).includes('gebaeude-3d'));
  assert.ok(!ids(kartenstil('hell', 'https://s', { gebaeude3d: false })).includes('gebaeude-3d'));
});

test('Kartenstil Luftbild: Satellitenbild statt Flächen, Beschriftung und Lage bleiben', () => {
  const s = kartenstil('dunkel', 'https://s', { luftbild: true });
  const l = ids(s);
  assert.equal(l[1], 'luftbild');
  assert.ok(!l.includes('wasser') && !l.includes('wald'));
  assert.ok(l.includes('strassen-name') && l.includes('ort-stadt'));
  assert.ok(l.some((id) => id.startsWith('lage-')));
  const quellen = s.sources as Record<string, { tiles?: string[] }>;
  assert.equal(quellen.luftbild?.tiles?.[0], 'https://s/karte/luftbild/{z}/{x}/{y}.jpg');
  assert.ok(!('luftbild' in (kartenstil('hell', 'https://s').sources as object)));
});
