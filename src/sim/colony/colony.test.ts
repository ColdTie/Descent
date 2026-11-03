import { describe, expect, it } from 'vitest';
import { BODY_DEFS } from '../../content/bodies';
import { BUFFER_CAP, BUILDING_DEFS, ROBOT_PARTS, STARTING_ROBOTS } from '../../content/colony';
import { applyCommand, colonyOf } from '../commands';
import { stepLedger } from '../ledger';
import { deserialize, migrate, serialize } from '../migrations';
import { createGalaxy, focusedVessel, type GalaxyState } from '../state';
import { SECONDS_PER_DAY, SECONDS_PER_HOUR } from '../time';
import { LANDER_ID } from './colony';
import { centerCell } from './terrain';
import type { Colony } from './types';

const quiet = { events: false } as const;

/** A galaxy whose Vessel has just landed on its first landable body (by most ore). */
function landed(seed: number): { g: GalaxyState; c: Colony } {
  const g = createGalaxy(seed);
  const v = focusedVessel(g);
  for (let i = 0; i < 365 * 300 && v.phase === 'transit'; i++) stepLedger(g, SECONDS_PER_DAY, quiet);
  if (v.phase !== 'arrival') throw new Error(`seed ${seed} did not arrive`);
  const sys = g.starSystems[v.starId!]!;
  const body = sys.bodies.filter((b) => BODY_DEFS[b.kind].landable).sort((a, b) => b.profile.ore - a.profile.ore)[0]!;
  body.surveyed = true;
  expect(applyCommand(g, { type: 'land', vesselId: 1, bodyId: body.id }).ok).toBe(true);
  return { g, c: colonyOf(g, v)! };
}

function hours(g: GalaxyState, n: number, step = SECONDS_PER_HOUR): void {
  for (let i = 0; i < (n * SECONDS_PER_HOUR) / step; i++) stepLedger(g, step, quiet);
}

describe('a new colony', () => {
  it('lands the starting robots on the pad, knows the area around it, and has ore and ice nodes', () => {
    const { c } = landed(3);
    expect(c.robots.map((r) => r.type).sort()).toEqual(['builder', 'builder', 'hauler', 'hauler', 'surveyor']);
    expect(c.robots.every((r) => r.cell === centerCell(c.size))).toBe(true);
    expect(c.revealed[centerCell(c.size)]).toBe(1);
    expect(c.nodes.filter((n) => n.kind === 'ore').length).toBeGreaterThanOrEqual(2);
    expect(c.nodes.filter((n) => n.kind === 'ice').length).toBeGreaterThanOrEqual(1);
    expect(Object.values(STARTING_ROBOTS).reduce((a, b) => a + b)).toBe(c.robots.length);
  });

  it('is the same colony for the same galaxy', () => {
    expect(serialize(landed(3).g)).toBe(serialize(landed(3).g));
  });
});

describe('survey and expansion', () => {
  it('the surveyor reveals nodes, and Expand queues miners on them by itself', () => {
    const { g, c } = landed(3);
    const before = c.revealed.reduce((a, b) => a + b, 0);
    hours(g, 24 * 10);
    expect(c.revealed.reduce((a, b) => a + b, 0)).toBeGreaterThan(before);
    expect(c.nodes.some((n) => n.revealed)).toBe(true);
    expect(c.buildings.some((b) => b.type === 'oreMiner')).toBe(true);
  });

  it('does nothing in a category whose priority is 0', () => {
    const { g, c } = landed(3);
    for (const job of ['survey', 'expand'] as const) applyCommand(g, { type: 'setPriority', vesselId: 1, job, value: 0 });
    const before = c.revealed.reduce((a, b) => a + b, 0);
    hours(g, 24 * 5);
    expect(c.revealed.reduce((a, b) => a + b, 0)).toBe(before);
    expect(c.buildings).toHaveLength(0);
  });
});

describe('building and production', () => {
  it('pays for a queued building, a builder walks to the site and builds it', () => {
    const { g, c } = landed(3);
    const v = focusedVessel(g);
    applyCommand(g, { type: 'setPriority', vesselId: 1, job: 'expand', value: 0 });
    const parts = v.stock.parts;
    applyCommand(g, { type: 'queueBuild', vesselId: 1, building: 'solar' });
    hours(g, 1);
    const b = c.buildings[0]!;
    expect(b.paid).toBe(true);
    expect(v.stock.parts).toBe(parts - BUILDING_DEFS.solar.cost.parts!);
    expect(b.cell).not.toBe(centerCell(c.size));
    hours(g, 48);
    expect(b.progress).toBe(1);
    expect(c.power.supply).toBeGreaterThan(5);
  });

  it('refunds a cancelled building that no one has worked on', () => {
    const { g, c } = landed(3);
    const v = focusedVessel(g);
    applyCommand(g, { type: 'setPriority', vesselId: 1, job: 'build', value: 0 });
    applyCommand(g, { type: 'setPriority', vesselId: 1, job: 'expand', value: 0 });
    const parts = v.stock.parts;
    applyCommand(g, { type: 'queueBuild', vesselId: 1, building: 'refinery' });
    hours(g, 1);
    expect(v.stock.parts).toBe(parts - 3);
    expect(applyCommand(g, { type: 'cancelBuild', vesselId: 1, buildingId: c.buildings[0]!.id }).ok).toBe(true);
    expect(v.stock.parts).toBe(parts);
    expect(c.buildings).toHaveLength(0);
  });

  it('refuses locked buildings, bad priorities and commands for a Vessel with no colony', () => {
    const { g } = landed(3);
    expect(applyCommand(g, { type: 'queueBuild', vesselId: 1, building: 'shipyard' }).ok).toBe(false);
    expect(applyCommand(g, { type: 'setPriority', vesselId: 1, job: 'mine', value: 9 }).ok).toBe(false);
    const h = createGalaxy(1);
    expect(applyCommand(h, { type: 'queueBuild', vesselId: 1, building: 'solar' }).reason).toContain('no colony');
  });

  it('a miner fills its buffer and haulers carry the ore to the Vessel', () => {
    const { g, c } = landed(3);
    const v = focusedVessel(g);
    hours(g, 24 * 30);
    const miner = c.buildings.find((b) => b.type === 'oreMiner' && b.progress >= 1);
    expect(miner).toBeDefined();
    expect(c.made.ore ?? 0).toBeGreaterThan(20);
    expect(v.stock.ore).toBeGreaterThan(0);
    expect(miner!.output).toBeLessThanOrEqual(BUFFER_CAP);
  });

  it('runs every building slower when power demand outruns supply', () => {
    const { g, c } = landed(3);
    applyCommand(g, { type: 'setPriority', vesselId: 1, job: 'expand', value: 0 });
    const v = focusedVessel(g);
    v.systems.power.integrity = 0;
    hours(g, 24 * 25);
    // No solar, no reactor: nothing that draws power can run.
    expect(c.power.supply).toBe(0);
    expect(c.made.ore ?? 0).toBe(0);
  });
});

describe('Phase 5 exit: a working Fabricator with no manual robot control', () => {
  it('from landing, queues four buildings and lets the robots do the rest, for several seeds', () => {
    let worked = 0;
    for (const seed of [1, 2, 3, 4, 5, 6]) {
      let ctx: { g: GalaxyState; c: Colony };
      try {
        ctx = landed(seed);
      } catch {
        continue;
      }
      const { g, c } = ctx;
      for (const building of ['solar', 'oreMiner', 'refinery', 'fabricator'] as const) applyCommand(g, { type: 'queueBuild', vesselId: 1, building });
      let day = 0;
      for (; day < 365 && !((c.made.parts ?? 0) > 0); day++) hours(g, 24);
      const fab = c.buildings.find((b) => b.type === 'fabricator');
      expect(fab?.progress, `seed ${seed}`).toBe(1);
      expect(c.fabricatorOnline).toBe(true);
      expect(c.made.parts ?? 0, `seed ${seed}`).toBeGreaterThan(0);
      expect(g.alerts.some((a) => a.text.startsWith('Fabricator online'))).toBe(true);
      worked++;
    }
    expect(worked).toBeGreaterThanOrEqual(4);
  });

  it('reaches the same milestone at day steps (10M warp) as at hour steps', () => {
    const run = (step: number): number => {
      const { g, c } = landed(3);
      for (const building of ['solar', 'oreMiner', 'refinery', 'fabricator'] as const) applyCommand(g, { type: 'queueBuild', vesselId: 1, building });
      let t = 0;
      while (!((c.made.parts ?? 0) > 0) && t < 365 * SECONDS_PER_DAY) {
        stepLedger(g, step, quiet);
        t += step;
      }
      return t / SECONDS_PER_DAY;
    };
    const fine = run(SECONDS_PER_HOUR);
    const coarse = run(SECONDS_PER_DAY);
    expect(fine).toBeLessThan(365);
    expect(Math.abs(coarse - fine) / fine).toBeLessThan(0.15);
  });

  it('builds robots up to the quota once the Fabricator runs', () => {
    const { g, c } = landed(3);
    const v = focusedVessel(g);
    for (const building of ['solar', 'oreMiner', 'refinery', 'fabricator'] as const) applyCommand(g, { type: 'queueBuild', vesselId: 1, building });
    for (let day = 0; day < 365 && !c.fabricatorOnline; day++) hours(g, 24);
    v.stock.parts += ROBOT_PARTS * 2;
    applyCommand(g, { type: 'setQuota', vesselId: 1, quota: 'hauler', value: 3 });
    hours(g, 24 * 3);
    expect(c.robots.filter((r) => r.type === 'hauler')).toHaveLength(3);
  });
});

describe('colony saves', () => {
  it('round-trip mid-game and continue identically', () => {
    const { g } = landed(3);
    hours(g, 24 * 20);
    const loaded = deserialize(serialize(g));
    expect(loaded.reason).toBe('');
    hours(g, 24 * 5);
    hours(loaded.state!, 24 * 5);
    expect(serialize(loaded.state!)).toBe(serialize(g));
  });

  it('upgrades a schema 3 save that had already landed by building its colony at load', () => {
    const { g } = landed(4);
    const raw = JSON.parse(serialize(g));
    raw.schemaVersion = 3;
    for (const w of Object.values(raw.worlds) as Array<Record<string, unknown>>) delete w.colony;
    const r = migrate(raw);
    expect(r.reason).toBe('');
    expect(colonyOf(r.state!, focusedVessel(r.state!))).not.toBeNull();
  });

  it('refuses a broken colony', () => {
    const { g } = landed(3);
    const good = JSON.parse(serialize(g));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any -- tests poke arbitrary JSON
    const cases: Array<[string, (d: any) => void]> = [
      ['colony robots', (d) => (d.worlds['1'].colony.robots[0].cell = -4)],
      ['colony buildings', (d) => d.worlds['1'].colony.buildings.push({ id: 99, type: 'castle' })],
      ['colony revealed', (d) => d.worlds['1'].colony.revealed.pop()],
      ['colony priorities', (d) => delete d.worlds['1'].colony.priorities.mine],
      ['colony nextId', (d) => (d.worlds['1'].colony.nextId = 1)],
    ];
    for (const [field, breakIt] of cases) {
      const d = structuredClone(good);
      breakIt(d);
      expect(migrate(d).reason, field).toContain(field);
    }
    expect(LANDER_ID).toBe(0);
  });
});

describe('Phase 5 review regressions', () => {
  it('Expand never spends the Parts the first Fabricator chain needs, even if the player waits', () => {
    const { g, c } = landed(3);
    hours(g, 24 * 10);
    for (const building of ['refinery', 'fabricator'] as const) applyCommand(g, { type: 'queueBuild', vesselId: 1, building });
    for (let day = 0; day < 200 && !c.fabricatorOnline; day++) hours(g, 24);
    expect(c.fabricatorOnline).toBe(true);
  });

  it('keeps Metal for a building queued after the Fabricator runs instead of feeding it all in', () => {
    const { g, c } = landed(3);
    for (const building of ['solar', 'oreMiner', 'refinery', 'fabricator'] as const) applyCommand(g, { type: 'queueBuild', vesselId: 1, building });
    for (let day = 0; day < 200 && !c.fabricatorOnline; day++) hours(g, 24);
    hours(g, 24 * 10);
    applyCommand(g, { type: 'queueBuild', vesselId: 1, building: 'depot' });
    const depot = c.buildings.at(-1)!;
    for (let day = 0; day < 60 && depot.progress < 1; day++) hours(g, 24);
    expect(depot.progress).toBe(1);
  });

  it('feeds the Cracker: Volatiles get hauled even with full Ore miners closer to home', () => {
    const { g, c } = landed(3);
    for (const building of ['solar', 'oreMiner', 'refinery', 'fabricator', 'cracker'] as const) applyCommand(g, { type: 'queueBuild', vesselId: 1, building });
    for (let day = 0; day < 120 && !((c.made.fuel ?? 0) > 5); day++) hours(g, 24);
    expect(c.made.fuel ?? 0).toBeGreaterThan(5);
  });

  it('a big colony steps a game day in a few milliseconds', () => {
    const { g, c } = landed(3);
    const v = focusedVessel(g);
    v.stock.parts = 5000;
    v.stock.metal = 5000;
    for (const t of ['solar', 'refinery', 'fabricator', 'cracker', 'depot', 'solar', 'refinery'] as const) applyCommand(g, { type: 'queueBuild', vesselId: 1, building: t });
    for (const quota of ['surveyor', 'builder', 'hauler'] as const) applyCommand(g, { type: 'setQuota', vesselId: 1, quota, value: 20 });
    for (let d = 0; d < 120; d++) hours(g, 24, SECONDS_PER_DAY);
    expect(c.robots.length).toBeGreaterThan(30);
    const t0 = performance.now();
    for (let d = 0; d < 30; d++) stepLedger(g, SECONDS_PER_DAY, quiet);
    const ms = (performance.now() - t0) / 30;
    // About 6 ms on a dev box; the bound catches an O(n²) regression without flaking on slow CI runners.
    expect(ms).toBeLessThan(25);
  });
});
