import { isBusyIndicatorNode } from '@agent-device/kernel/snapshot';
import type { SnapshotState } from '@agent-device/contracts/snapshot-model';
import type { SurfaceScopedNodes } from '@agent-device/contracts/interaction';
import { withoutSettleChrome } from '@agent-device/capture-kit/snapshot-chrome';
import {
  stableCaptureSignal,
  stableCaptureSignalsEqual,
  type StableCaptureSignal,
} from './stable-capture-signal.ts';

/**
 * Internal prototype (`SettleParams.confirmation: 'adaptive'`): a capture that differs from a fresh
 * pre-action baseline, and that one short confirmation capture agrees with, settles before the
 * quiet window. Every other case keeps the quiet window: no capture has differed yet (a no-op, a
 * toggle that has not rendered, a late effect), the confirmation disagrees, a busy indicator is on
 * screen, the producer or the presented surface changed, the broad-replacement floor is in force,
 * the capture still holds the baseline screen beside a new one, or the baseline may predate a side
 * effect. One failed check disarms the rule for the rest of the
 * run.
 *
 * Two equal captures ~110 ms apart cannot exclude a later stage nothing marks: a toast standing in
 * for navigation, a plateau between transition stages, a late value write. That is the trade this
 * prototype measures.
 */
export const ADAPTIVE_CONFIRMATION_GAP_MS = 110;

export type AdaptiveConfirmation = ReturnType<typeof createAdaptiveConfirmation>;

export function createAdaptiveConfirmation(params: {
  baseline: SurfaceScopedNodes | undefined;
  baselineFresh: boolean;
  appBundleId: string | undefined;
}) {
  const { baseline, appBundleId } = params;
  let armed = params.baselineFresh && baseline !== undefined && baseline.nodes.length > 0;
  let candidate: { signal: StableCaptureSignal; snapshot: SnapshotState } | undefined;
  const disarm = () => {
    armed = false;
    candidate = undefined;
  };
  return {
    /**
     * Folds one capture in. `settle`: this capture confirmed the previous one. `confirm`: take the
     * next capture after the short gap. `none`: the quiet window decides.
     */
    observe(input: {
      snapshot: SnapshotState;
      signal: StableCaptureSignal;
      /** The broad-replacement floor raised this capture's window above the producer's own. */
      floorInForce: boolean;
    }): 'settle' | 'confirm' | 'none' {
      if (!armed || !baseline) return 'none';
      const { snapshot, signal } = input;
      if (
        input.floorInForce ||
        hasBusyIndicator(snapshot) ||
        isTransitionalUnion(baseline, snapshot, appBundleId) ||
        presentedSurfaceChanged(baseline, snapshot)
      ) {
        disarm();
        return 'none';
      }
      if (candidate) {
        const confirmed =
          sameProvenance(candidate.snapshot, snapshot) &&
          stableCaptureSignalsEqual(candidate.signal, signal);
        disarm();
        return confirmed ? 'settle' : 'none';
      }
      if (!differsFromBaseline(baseline, snapshot, appBundleId)) return 'none';
      candidate = { signal, snapshot };
      return 'confirm';
    },
    /** A private-AX recovery re-read the screen through another backend. */
    disarm,
  };
}

/**
 * A navigation transition can publish both screens at once, and that union can hold still across
 * two captures. A capture that keeps most of the baseline while adding half as much again is that
 * union, not a settled screen.
 */
const UNION_RETAINED_RATIO = 0.8;
const UNION_GROWTH_RATIO = 0.5;

function isTransitionalUnion(
  baseline: SurfaceScopedNodes,
  snapshot: SnapshotState,
  appBundleId: string | undefined,
): boolean {
  const before = projectedIdentities(snapshot, baseline.nodes, appBundleId);
  const after = projectedIdentities(snapshot, snapshot.nodes, appBundleId);
  if (before.length === 0) return false;
  const remaining = new Map<string, number>();
  for (const identity of before) remaining.set(identity, (remaining.get(identity) ?? 0) + 1);
  let shared = 0;
  for (const identity of after) {
    const left = remaining.get(identity) ?? 0;
    if (left === 0) continue;
    shared += 1;
    remaining.set(identity, left - 1);
  }
  return (
    shared / before.length >= UNION_RETAINED_RATIO &&
    (after.length - shared) / before.length >= UNION_GROWTH_RATIO
  );
}

function projectedIdentities(
  snapshot: SnapshotState,
  nodes: SnapshotState['nodes'],
  appBundleId: string | undefined,
): string[] {
  return stableCaptureSignal({
    ...snapshot,
    nodes: withoutSettleChrome(nodes, appBundleId),
  }).nodes.map((node) => node.identity);
}

function differsFromBaseline(
  baseline: SurfaceScopedNodes,
  snapshot: SnapshotState,
  appBundleId: string | undefined,
): boolean {
  // Both sides take the capture's provenance so visibility filtering applies alike, and both drop
  // the keyboard chrome the settle diff collapses: a keyboard alone is not the action's effect.
  const project = (nodes: SnapshotState['nodes']) =>
    stableCaptureSignal({ ...snapshot, nodes: withoutSettleChrome(nodes, appBundleId) });
  return !stableCaptureSignalsEqual(project(baseline.nodes), project(snapshot.nodes));
}

function hasBusyIndicator(snapshot: SnapshotState): boolean {
  return snapshot.nodes.some(isBusyIndicatorNode);
}

function presentedSurfaceChanged(baseline: SurfaceScopedNodes, snapshot: SnapshotState): boolean {
  const before = baseline.presentedSurface;
  const after = snapshot.presentedSurface;
  return before !== undefined && after !== undefined && before !== after;
}

function sameProvenance(left: SnapshotState, right: SnapshotState): boolean {
  return (
    left.producer === right.producer &&
    left.backend === right.backend &&
    left.presentedSurface === right.presentedSurface
  );
}
