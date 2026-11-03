import { describe, expect, it } from 'vitest';
import { BODY_COUNT_MAX, BODY_COUNT_MIN, BODY_DEFS, LANDING_FUEL, SURVEY_DAYS } from '../content/bodies';
import { applyCommand, landBlocker, surveyBlocker } from './commands';
import { stepLedger } from './ledger';
import { deserialize, migrate, serialize } from './migrations';
import { createRng } from './rng';
import { generateStars } from './stars';
import { createGalaxy, focusedVessel, type GalaxyState } from './state';
import { generateSystem } from './system';
import { SECONDS_PER_DAY } from './time';

const quiet = { events: false } as const;

function arrived(seed: number): GalaxyState {
  const g = createGalaxy(seed);
  const v = focusedVessel(g);
  for (let i = 0; i < 365 * 300 && v.phase === 'transit'; i++) stepLedger(g, SECONDS_PER_DAY, quiet);
  expect(v.phase).toBe('arrival');
  return g;
}

function days(g: GalaxyState, n: number): void {
  for (let i = 0; i < n; i++) stepLedger(g, SECONDS_PER_DAY, quiet);
}

describe('star systems', () => {
  it('has 2 to 6 bodies on rising orbits, at least one landable, for many seeds', () => {
    const stars = generateStars(createRng(1));
    for (let seed = 1; seed <= 300; seed++) {
      const sys = generateSystem(createRng(seed), stars[1]!);
      expect(sys.bodies.length).toBeGreaterThanOrEqual(BODY_COUNT_MIN);
      expect(sys.bodies.length).toBeLessThanOrEqual(BODY_COUNT_MAX);
      expect(sys.bodies.some((b) => BODY_DEFS[b.kind].landable)).toBe(true);
      for (let i = 1; i < sys.bodies.length; i++) expect(sys.bodies[i]!.orbitAu).toBeGreaterThanOrEqual(sys.bodies[i - 1]!.orbitAu);
      for (const b of sys.bodies) {
        expect(b.surveyed).toBe(false);
        expect(b.profile.ore).toBeGreaterThanOrEqual(0);
        expect(b.profile.ice).toBeLessThanOrEqual(1);
        expect(b.profile.hazard === 'none').toBe(b.profile.severity === 0);
      }
    }
  });

  it('is generated on arrival from the worlds stream, deterministically', () => {
    const a = arrived(3);
    const b = arrived(3);
    const starId = focusedVessel(a).starId!;
    expect(a.starSystems[starId]).toBeDefined();
    expect(a.starSystems[starId]).toEqual(b.starSystems[starId]);
    expect(a.alerts.at(-1)!.text).toMatch(/bodies in the system/);
  });
});

describe('survey', () => {
  it('takes 30 game days, then reveals the body and raises an alert', () => {
    const g = arrived(3);
    const v = focusedVessel(g);
    const sys = g.starSystems[v.starId!]!;
    expect(applyCommand(g, { type: 'surveyBody', vesselId: 1, bodyId: 0 }).ok).toBe(true);
    days(g, SURVEY_DAYS - 1);
    expect(sys.bodies[0]!.surveyed).toBe(false);
    days(g, 1);
    expect(sys.bodies[0]!.surveyed).toBe(true);
    expect(v.survey).toBeNull();
    expect(g.alerts.at(-1)!.text).toContain('Survey of');
  });

  it('takes twice as long with weak sensors and refuses with dead ones', () => {
    const g = arrived(3);
    const v = focusedVessel(g);
    v.systems.sensors.integrity = 20;
    applyCommand(g, { type: 'surveyBody', vesselId: 1, bodyId: 0 });
    expect(v.survey!.totalSeconds).toBe(SURVEY_DAYS * 2 * SECONDS_PER_DAY);
    v.systems.sensors.integrity = 0;
    expect(surveyBlocker(g, v, 1)).toBe('sensors are offline');
  });

  it('refuses outside orbit, for unknown bodies and for surveyed ones', () => {
    const g = createGalaxy(3);
    const v = focusedVessel(g);
    expect(applyCommand(g, { type: 'surveyBody', vesselId: 1, bodyId: 0 }).reason).toContain('only from orbit');
    const h = arrived(3);
    const w = focusedVessel(h);
    expect(surveyBlocker(h, w, 99)).toBe('no such body');
    h.starSystems[w.starId!]!.bodies[0]!.surveyed = true;
    expect(surveyBlocker(h, w, 0)).toBe('already surveyed');
    expect(v.phase).toBe('transit');
  });
});

describe('landing', () => {
  it('needs a surveyed body with a surface', () => {
    const g = arrived(3);
    const v = focusedVessel(g);
    const sys = g.starSystems[v.starId!]!;
    expect(landBlocker(g, v, 0)).toBe('survey it first');
    const giant = sys.bodies.find((b) => b.kind === 'gasGiant');
    if (giant) {
      giant.surveyed = true;
      expect(landBlocker(g, v, giant.id)).toMatch(/no surface/);
    }
  });

  it('lands on the chosen world, pays the landing burn and enters Planetside', () => {
    const g = arrived(3);
    const v = focusedVessel(g);
    const sys = g.starSystems[v.starId!]!;
    const target = sys.bodies.find((b) => BODY_DEFS[b.kind].landable)!;
    applyCommand(g, { type: 'surveyBody', vesselId: 1, bodyId: target.id });
    days(g, SURVEY_DAYS);
    const fuel = v.stock.fuel;
    expect(applyCommand(g, { type: 'land', vesselId: 1, bodyId: target.id }).ok).toBe(true);
    expect(v.phase).toBe('planetside');
    expect(v.stock.fuel).toBeCloseTo(Math.max(0, fuel - LANDING_FUEL), 9);
    const world = g.worlds[v.worldId!]!;
    expect(world).toMatchObject({ starId: v.starId, bodyId: target.id, vesselId: 1 });
    expect(deserialize(serialize(g)).reason).toBe('');
  });

  it('costs Hull when the landing burn is short of Fuel', () => {
    const g = arrived(3);
    const v = focusedVessel(g);
    const target = g.starSystems[v.starId!]!.bodies.find((b) => BODY_DEFS[b.kind].landable)!;
    target.surveyed = true;
    v.stock.fuel = 4;
    const hull = v.systems.hull.integrity;
    applyCommand(g, { type: 'land', vesselId: 1, bodyId: target.id });
    expect(v.systems.hull.integrity).toBeCloseTo(hull - 18, 9);
    expect(v.stock.fuel).toBe(0);
  });
});

describe('schema 3', () => {
  it('upgrades a schema 2 save and builds the system for a Vessel already in orbit', () => {
    const g = arrived(5);
    const v2 = JSON.parse(serialize(g));
    v2.schemaVersion = 2;
    delete v2.starSystems;
    delete v2.worlds;
    delete v2.nextWorldId;
    for (const v of Object.values(v2.vessels) as Array<Record<string, unknown>>) {
      delete v.survey;
      delete v.worldId;
    }
    const r = migrate(v2);
    expect(r.reason).toBe('');
    const state = r.state!;
    expect(state.starSystems).toEqual({});
    stepLedger(state, 60);
    expect(state.starSystems[focusedVessel(state).starId!]).toBeDefined();
  });

  it('refuses broken systems, worlds and surveys', () => {
    const g = arrived(3);
    const v = focusedVessel(g);
    applyCommand(g, { type: 'surveyBody', vesselId: 1, bodyId: 0 });
    const good = JSON.parse(serialize(g));
    const starKey = String(v.starId);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any -- tests poke arbitrary JSON
    const cases: Array<[string, (d: any) => void]> = [
      ['starSystems', (d) => (d.starSystems[starKey].bodies[0].kind = 'cheese')],
      ['vessel 1 survey', (d) => (d.vessels['1'].survey.bodyId = 99)],
      ['worlds', (d) => delete d.worlds],
      ['vessel 1 worldId', (d) => (d.vessels['1'].worldId = 7)],
      ['vessel 1 worldId', (d) => (d.vessels['1'].phase = 'planetside')],
      ['world 1 body', (d) => { d.worlds = { 1: { id: 1, starId: v.starId, bodyId: 42, vesselId: 1, landedAt: 0 } }; d.nextWorldId = 2; }],
    ];
    for (const [field, breakIt] of cases) {
      const d = structuredClone(good);
      breakIt(d);
      expect(migrate(d).reason, field).toContain(field);
    }
    expect(migrate(good).reason).toBe('');
  });
});
