import { describe, expect, it } from 'vitest';
import { SYSTEM_DEFS, SYSTEM_IDS } from '../content/systems';
import { stepLedger, transitEtaSeconds } from './ledger';
import { createGalaxy, focusedVessel } from './state';
import { SECONDS_PER_HOUR, SECONDS_PER_YEAR } from './time';

describe('ledger', () => {
  it('advances game time by the step', () => {
    const g = createGalaxy(3);
    stepLedger(g, 60);
    expect(g.time).toBe(60);
  });

  it('wears each system at its per-hour rate while in transit', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    stepLedger(g, SECONDS_PER_HOUR * 10);
    for (const id of SYSTEM_IDS) expect(v.systems[id].integrity).toBeCloseTo(100 - SYSTEM_DEFS[id].wearPerHour * 10, 9);
  });

  it('moves the Vessel along its hop at 0.2c and stops at the target distance', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    const t = v.transit!;
    stepLedger(g, SECONDS_PER_YEAR);
    expect(t.traveledLy).toBeCloseTo(0.2, 9);
    stepLedger(g, SECONDS_PER_YEAR * 1000);
    expect(t.traveledLy).toBe(t.distanceLy);
  });

  it('reports an ETA that shrinks as the hop progresses', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    const eta0 = transitEtaSeconds(v);
    expect(eta0).toBeCloseTo((v.transit!.distanceLy / 0.2) * SECONDS_PER_YEAR, 3);
    stepLedger(g, SECONDS_PER_YEAR);
    expect(transitEtaSeconds(v)).toBeCloseTo(eta0 - SECONDS_PER_YEAR, 3);
  });

  it('raises each integrity alert exactly once and clamps at zero', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    let raised = 0;
    for (let i = 0; i < 400; i++) raised += stepLedger(g, SECONDS_PER_YEAR).alerts.length;
    for (const id of SYSTEM_IDS) expect(v.systems[id].integrity).toBe(0);
    expect(raised).toBe(SYSTEM_IDS.length * 3);
    expect(g.alerts).toHaveLength(SYSTEM_IDS.length * 3);
    expect(g.alerts.every((a) => a.vesselId === v.id)).toBe(true);
    expect(v.log.some((l) => l.text.includes('Drive integrity below 50'))).toBe(true);
  });

  it('leaves Vessels that are not in transit alone', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    v.phase = 'planetside';
    stepLedger(g, SECONDS_PER_YEAR);
    expect(v.systems.hull.integrity).toBe(100);
  });
});
