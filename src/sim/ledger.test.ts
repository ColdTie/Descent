import { describe, expect, it } from 'vitest';
import { SYSTEM_DEFS, SYSTEM_IDS } from '../content/systems';
import { ACCEL_C_PER_YEAR, BURN_FUEL_PER_YEAR, CRUISE_SPEED_C } from '../content/transit';
import { stepLedger, transitEtaSeconds, transitSummary } from './ledger';
import { createGalaxy, focusedVessel, type GalaxyState } from './state';
import { SECONDS_PER_DAY, SECONDS_PER_HOUR, SECONDS_PER_YEAR } from './time';

const quiet = { events: false } as const;

/** Steps day by day until the predicate holds or the day budget runs out. */
function until(g: GalaxyState, pred: () => boolean, days = 200 * 365): number {
  let n = 0;
  while (!pred() && n < days) {
    stepLedger(g, SECONDS_PER_DAY, quiet);
    n++;
  }
  return n;
}

describe('ledger: time and wear', () => {
  it('advances game time by the step', () => {
    const g = createGalaxy(3);
    stepLedger(g, 60, quiet);
    expect(g.time).toBe(60);
  });

  it('wears each system at its per-hour rate while in transit', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    stepLedger(g, SECONDS_PER_HOUR * 10, quiet);
    for (const id of SYSTEM_IDS) expect(v.systems[id].integrity).toBeCloseTo(100 - SYSTEM_DEFS[id].wearPerHour * 10, 9);
  });

  it('doubles wear on the other systems while the reactor is dead', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    v.systems.power.integrity = 0;
    stepLedger(g, SECONDS_PER_HOUR * 10, quiet);
    expect(v.systems.hull.integrity).toBeCloseTo(100 - SYSTEM_DEFS.hull.wearPerHour * 20, 9);
  });

  it('leaves Vessels that are not in transit alone', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    v.phase = 'planetside';
    stepLedger(g, SECONDS_PER_YEAR, quiet);
    expect(v.systems.hull.integrity).toBe(100);
  });
});

describe('ledger: burns', () => {
  it('launch burn reaches cruise after a year, covering 0.1 ly and burning 30 fuel', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    const t = v.transit!;
    expect(t.burn).toBe('accel');
    until(g, () => t.burn !== 'accel');
    expect(t.speedC).toBeCloseTo(CRUISE_SPEED_C, 9);
    expect(t.traveledLy).toBeCloseTo(CRUISE_SPEED_C ** 2 / (2 * ACCEL_C_PER_YEAR), 2);
    expect(v.stock.fuel).toBeCloseTo(100 - BURN_FUEL_PER_YEAR, 0);
    expect(g.time).toBeCloseTo(SECONDS_PER_YEAR, -6);
  });

  it('coasts, brakes for the last 0.1 ly and arrives with about 40 fuel left', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    const target = v.transit!.toStarId;
    until(g, () => v.transit?.burn === 'decel');
    expect(v.transit!.distanceLy - v.transit!.traveledLy).toBeLessThanOrEqual(0.1 + 1e-6);
    until(g, () => v.phase !== 'transit');
    expect(v.phase).toBe('arrival');
    expect(v.starId).toBe(target);
    expect(v.transit).toBeNull();
    expect(v.stock.fuel).toBeGreaterThan(35);
    expect(v.stock.fuel).toBeLessThan(45);
    expect(g.alerts.some((a) => a.text.startsWith('Arrived at'))).toBe(true);
    expect(g.warp).toBe(1);
  });

  it('takes hull damage when braking with no fuel, and raises that alert once', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    until(g, () => v.transit?.burn === 'decel');
    v.stock.fuel = 0;
    const hull0 = v.systems.hull.integrity;
    until(g, () => v.phase !== 'transit');
    expect(v.phase).toBe('arrival');
    expect(hull0 - v.systems.hull.integrity).toBeGreaterThan(45);
    expect(g.alerts.filter((a) => a.text.includes('Out of fuel mid-braking'))).toHaveLength(1);
  });

  it('loses the Vessel when the hull reaches zero', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    until(g, () => v.transit?.burn === 'decel');
    v.stock.fuel = 0;
    v.systems.hull.integrity = 10;
    until(g, () => v.phase !== 'transit');
    expect(v.phase).toBe('lost');
    expect(g.alerts.some((a) => a.text.includes('lost'))).toBe(true);
    const t = g.time;
    stepLedger(g, SECONDS_PER_DAY, quiet);
    expect(g.time).toBe(t + SECONDS_PER_DAY);
    expect(v.phase).toBe('lost');
  });

  it('cuts the launch burn short when fuel runs out and coasts at the speed reached', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    v.stock.fuel = 15;
    until(g, () => v.transit?.burn !== 'accel');
    expect(v.transit!.speedC).toBeLessThan(CRUISE_SPEED_C);
    expect(v.transit!.speedC).toBeGreaterThan(0.08);
  });
});

describe('ledger: ETA and summary', () => {
  it('estimates the whole burn plan and stays close to the real arrival time', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    const eta0 = transitEtaSeconds(v);
    const start = g.time;
    until(g, () => v.phase !== 'transit');
    expect(Math.abs(g.time - start - eta0) / eta0).toBeLessThan(0.01);
  });

  it('summarises the transit for the readout', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    const s0 = transitSummary(g, v)!;
    expect(s0.fromName).toBe('Home');
    expect(s0.targetName).toMatch(/^Star \d+$/);
    expect(s0.progress).toBe(0);
    expect(s0.burn).toBe('accel');
    until(g, () => v.transit!.traveledLy > 1);
    const s1 = transitSummary(g, v)!;
    expect(s1.burn).toBe('coast');
    expect(s1.remainingLy).toBeCloseTo(s0.distanceLy - v.transit!.traveledLy, 9);
    v.phase = 'planetside';
    v.transit = null;
    expect(transitSummary(g, v)).toBeNull();
  });
});

describe('ledger: alerts', () => {
  it('raises each threshold once per crossing and re-arms after a repair', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    v.systems.hull.integrity = 49;
    stepLedger(g, 60, quiet);
    stepLedger(g, 60, quiet);
    expect(g.alerts.filter((a) => a.text === 'Hull integrity below 50.')).toHaveLength(1);
    v.systems.hull.integrity = 80;
    stepLedger(g, 60, quiet);
    v.systems.hull.integrity = 49;
    stepLedger(g, 60, quiet);
    expect(g.alerts.filter((a) => a.text === 'Hull integrity below 50.')).toHaveLength(2);
  });

  it('drops warp to 1x inside the step that raised the alert', () => {
    const g = createGalaxy(3);
    g.warp = 10_000_000;
    focusedVessel(g).systems.drive.integrity = 49.99999;
    const r = stepLedger(g, SECONDS_PER_DAY, quiet);
    expect(r.alerts).toHaveLength(1);
    expect(g.warp).toBe(1);
  });

  it('holds the whole galaxy still while an event waits for a choice', () => {
    const g = createGalaxy(3);
    g.events.push({ id: 1, vesselId: 1, kind: 'signal', time: 0, damage: 0 });
    g.nextEventId = 2;
    const r = stepLedger(g, SECONDS_PER_DAY);
    expect(r.ran).toBe(false);
    expect(g.time).toBe(0);
  });
});
