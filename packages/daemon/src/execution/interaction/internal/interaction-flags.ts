import type { DaemonResponse } from '@agent-device/kernel/contracts';
import type { CommandFlags } from '@agent-device/contracts/command';
import type { EnvMap } from '@agent-device/kernel/source-value';
import type { SettleParams } from '@agent-device/contracts/interaction';
import { interactionErrorResponse } from './interaction-response.ts';

export function settleFlagGuardResponse(
  command: string,
  flags: CommandFlags | undefined,
): DaemonResponse | null {
  if (!flags || flags.settle === true) return null;
  const orphaned: string[] = [];
  if (flags.settleQuietMs !== undefined) orphaned.push('--settle-quiet');
  if (orphaned.length === 0) return null;
  return interactionErrorResponse(
    'INVALID_ARGS',
    `${command}: ${orphaned.join(', ')} require${orphaned.length === 1 ? 's' : ''} --settle.`,
  );
}

const ADAPTIVE_SETTLE_ENV = 'AGENT_DEVICE_SETTLE_ADAPTIVE';

/**
 * The settle request a command carries. `env` is the daemon host environment; it selects the
 * internal adaptive confirmation prototype and nothing else.
 */
export function readSettleRequest(
  flags: CommandFlags | undefined,
  env?: Readonly<EnvMap>,
): SettleParams | undefined {
  if (flags?.settle !== true) return undefined;
  return {
    ...(flags.settleQuietMs !== undefined ? { quietMs: flags.settleQuietMs } : {}),
    ...(flags.timeoutMs !== undefined ? { timeoutMs: flags.timeoutMs } : {}),
    ...(env?.[ADAPTIVE_SETTLE_ENV] === '1' ? { confirmation: 'adaptive' as const } : {}),
  };
}
