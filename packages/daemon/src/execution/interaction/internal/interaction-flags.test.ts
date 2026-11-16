import assert from 'node:assert/strict';
import { test } from 'vitest';
import { readSettleRequest } from './interaction-flags.ts';

test('the host environment opts a settle request into the adaptive confirmation', () => {
  assert.deepEqual(readSettleRequest({ settle: true }, { AGENT_DEVICE_SETTLE_ADAPTIVE: '1' }), {
    confirmation: 'adaptive',
  });
});

test('a settle request without the opt-in keeps the quiet window rule', () => {
  assert.deepEqual(
    readSettleRequest({ settle: true }, { AGENT_DEVICE_SETTLE_ADAPTIVE: 'true' }),
    {},
  );
  assert.deepEqual(readSettleRequest({ settle: true }, {}), {});
});

test('the opt-in alone requests no settle', () => {
  assert.equal(readSettleRequest({}, { AGENT_DEVICE_SETTLE_ADAPTIVE: '1' }), undefined);
});
