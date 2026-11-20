import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseMaxspeed } from '../src/reach/speedlimit.js';

test('Tempoangaben aus OpenStreetMap', () => {
  assert.equal(parseMaxspeed('50'), 50);
  assert.equal(parseMaxspeed('DE:urban'), 50);
  assert.equal(parseMaxspeed('DE:rural'), 100);
  assert.equal(parseMaxspeed('30 mph'), 48);
  assert.equal(parseMaxspeed('none'), null);
  assert.equal(parseMaxspeed(undefined), null);
});
