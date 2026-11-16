import assert from 'node:assert/strict';
import { test } from 'vitest';
import { makeSession } from '../../../__tests__/support/session-factories.ts';
import { activateCompleteRefFrame, expireRefFrame } from '../../../core/ref-frame.ts';
import { readSettleRequest } from './interaction-flags.ts';

const OPT_IN = { AGENT_DEVICE_SETTLE_ADAPTIVE: '1' };

test('the host environment opts a settle request into the adaptive confirmation', () => {
  const session = makeSession('default');
  activateCompleteRefFrame(session);

  assert.deepEqual(readSettleRequest({ settle: true }, { env: OPT_IN, session }), {
    confirmation: 'adaptive',
    refFrameCurrent: true,
  });
});

test('a ref frame a side effect crossed is not current for the adaptive confirmation', () => {
  const session = makeSession('default');
  activateCompleteRefFrame(session);
  expireRefFrame(session);

  assert.equal(
    readSettleRequest({ settle: true }, { env: OPT_IN, session })?.refFrameCurrent,
    false,
  );
});

test('a settle request without the opt-in keeps the quiet window rule', () => {
  const session = makeSession('default');
  const env = { AGENT_DEVICE_SETTLE_ADAPTIVE: 'true' };

  assert.deepEqual(readSettleRequest({ settle: true }, { env, session }), {});
  assert.deepEqual(readSettleRequest({ settle: true }), {});
});

test('the opt-in alone requests no settle', () => {
  assert.equal(readSettleRequest({}, { env: OPT_IN, session: makeSession('default') }), undefined);
});
