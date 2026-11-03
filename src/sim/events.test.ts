import { describe, expect, it } from 'vitest';
import { EVENT_DEFS, EVENT_KINDS } from '../content/events';
import { REPAIR_PARTS } from '../content/transit';
import { applyCommand, repairBlocker, repairGain } from './commands';
import { choiceBlocker, describeEffect, rollEvent } from './events';
import { stepLedger } from './ledger';
import { createGalaxy, focusedVessel, type GalaxyState } from './state';
import { SECONDS_PER_DAY } from './time';

function firstEvent(seed: number): GalaxyState {
  const g = createGalaxy(seed);
  for (let i = 0; i < 365 * 200 && g.events.length === 0; i++) stepLedger(g, SECONDS_PER_DAY);
  return g;
}

describe('event content', () => {
  it('gives every event two or three choices with at least one free choice', () => {
    for (const k of EVENT_KINDS) {
      const d = EVENT_DEFS[k];
      expect(d.choices.length).toBeGreaterThanOrEqual(2);
      expect(d.choices.length).toBeLessThanOrEqual(3);
      expect(d.choices.some((c) => !(c.effect.parts! < 0) && !(c.effect.fuel! < 0))).toBe(true);
    }
  });
});

describe('event rolls', () => {
  it('opens an event, damages its system, drops warp and stops the galaxy', () => {
    const g = createGalaxy(5);
    g.warp = 10_000_000;
    let ev = null;
    for (let i = 0; i < 365 * 200 && !ev; i++) ev = stepLedger(g, SECONDS_PER_DAY).events[0] ?? null;
    expect(ev).not.toBeNull();
    expect(g.warp).toBe(1);
    const t = g.time;
    stepLedger(g, SECONDS_PER_DAY);
    expect(g.time).toBe(t);
    const def = EVENT_DEFS[ev!.kind];
    if (def.system) expect(ev!.damage).toBeGreaterThan(0);
    expect(focusedVessel(g).log.at(-1)!.text).toContain(def.title);
  });

  it('is deterministic for a seed', () => {
    const a = firstEvent(9);
    const b = firstEvent(9);
    expect(a.events).toEqual(b.events);
    expect(a.time).toBe(b.time);
  });

  it('only rolls a signal while coasting', () => {
    const g = createGalaxy(2);
    const v = focusedVessel(g);
    v.transit!.burn = 'decel';
    const seen = new Set<string>();
    for (let i = 0; i < 4000; i++) {
      const e = rollEvent(g, v, SECONDS_PER_DAY * 30);
      if (e) seen.add(e.kind);
      g.events = [];
    }
    expect(seen.has('signal')).toBe(false);
    expect(seen.size).toBeGreaterThan(1);
  });
});

describe('resolveEvent', () => {
  it('applies a paid repair choice and clears the event', () => {
    const g = createGalaxy(1);
    const v = focusedVessel(g);
    v.systems.hull.integrity = 90;
    g.events.push({ id: 7, vesselId: 1, kind: 'micrometeoroid', time: 0, damage: 8 });
    g.nextEventId = 8;
    expect(applyCommand(g, { type: 'resolveEvent', eventId: 7, choice: 0 }).ok).toBe(true);
    expect(v.systems.hull.integrity).toBe(98);
    expect(v.stock.parts).toBe(17);
    expect(g.events).toHaveLength(0);
  });

  it('refuses a choice the Vessel cannot afford and keeps the event open', () => {
    const g = createGalaxy(1);
    const v = focusedVessel(g);
    v.stock.parts = 1;
    g.events.push({ id: 3, vesselId: 1, kind: 'driveFault', time: 0, damage: 8 });
    g.nextEventId = 4;
    const r = applyCommand(g, { type: 'resolveEvent', eventId: 3, choice: 1 });
    expect(r.ok).toBe(false);
    expect(r.reason).toContain('needs 4 Parts');
    expect(g.events).toHaveLength(1);
    expect(choiceBlocker(v, EVENT_DEFS.driveFault.choices[0]!.effect)).toBe('');
  });

  it('extends the hop on a detour', () => {
    const g = createGalaxy(1);
    const v = focusedVessel(g);
    const d0 = v.transit!.distanceLy;
    g.events.push({ id: 1, vesselId: 1, kind: 'signal', time: 0, damage: 0 });
    g.nextEventId = 2;
    applyCommand(g, { type: 'resolveEvent', eventId: 1, choice: 1 });
    expect(v.transit!.distanceLy).toBeCloseTo(d0 + 0.5, 9);
    expect(v.stock.fuel).toBe(92);
    expect(v.stock.parts).toBe(26);
  });

  it('describes costs and outcomes in words', () => {
    const e = { id: 1, vesselId: 1, kind: 'micrometeoroid' as const, time: 0, damage: 7 };
    expect(describeEffect(e, EVENT_DEFS.micrometeoroid.choices[0]!.effect)).toBe('−3 Parts · Hull +7');
    expect(describeEffect(e, EVENT_DEFS.micrometeoroid.choices[1]!.effect)).toBe('no cost');
  });
});

describe('repair', () => {
  it('spends Parts through the Fabricator, scaled by its integrity', () => {
    const g = createGalaxy(1);
    const v = focusedVessel(g);
    v.systems.hull.integrity = 50;
    v.systems.fabricator.integrity = 50;
    expect(repairGain(v, 'hull')).toBe(5);
    expect(applyCommand(g, { type: 'repair', vesselId: 1, system: 'hull' }).ok).toBe(true);
    expect(v.systems.hull.integrity).toBe(55);
    expect(v.stock.parts).toBe(20 - REPAIR_PARTS);
  });

  it('refuses when the Fabricator is offline, Parts are short or the system is whole', () => {
    const g = createGalaxy(1);
    const v = focusedVessel(g);
    expect(repairBlocker(v, 'hull')).toBe('already at 100');
    v.systems.hull.integrity = 40;
    v.stock.parts = 1;
    expect(applyCommand(g, { type: 'repair', vesselId: 1, system: 'hull' }).reason).toContain('needs 2 Parts');
    v.stock.parts = 10;
    v.systems.fabricator.integrity = 0;
    expect(applyCommand(g, { type: 'repair', vesselId: 1, system: 'hull' }).reason).toContain('Fabricator is offline');
    expect(v.systems.hull.integrity).toBe(40);
  });
});
