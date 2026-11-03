import { describe, expect, it } from 'vitest';
import { runSteps } from './game';
import { deserialize, migrate, MIGRATIONS, serialize } from './migrations';
import { createGalaxy, SCHEMA_VERSION } from './state';

describe('save and load', () => {
  it('round-trips a played galaxy exactly', () => {
    const g = runSteps(createGalaxy(11), 200, 86400);
    const text = serialize(g);
    const back = deserialize(text);
    expect(back.state).not.toBeNull();
    expect(serialize(back.state!)).toBe(text);
  });

  it('continues identically after a load (RNG cursors included)', () => {
    const a = runSteps(createGalaxy(12), 50, 3600);
    const loaded = deserialize(serialize(a)).state!;
    runSteps(a, 50, 3600);
    runSteps(loaded, 50, 3600);
    expect(serialize(loaded)).toBe(serialize(a));
  });

  it('refuses junk, missing versions and saves from the future', () => {
    expect(deserialize('not json').state).toBeNull();
    expect(migrate(null).state).toBeNull();
    expect(migrate({ time: 0 }).reason).toContain('schemaVersion');
    expect(migrate({ schemaVersion: SCHEMA_VERSION + 1 }).reason).toContain('this build reads up to');
    expect(migrate({ schemaVersion: SCHEMA_VERSION, time: 0 }).reason).toContain('save has a bad');
  });

  it('refuses saves the sim could not run, naming the bad field', () => {
    const good = JSON.parse(serialize(createGalaxy(3)));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any -- tests poke arbitrary JSON
    const broken: Array<[string, (d: any) => void]> = [
      ['vessels', (d) => (d.vessels = {})],
      ['warp', (d) => (d.warp = 7)],
      ['warp', (d) => delete d.warp],
      ['paused', (d) => delete d.paused],
      ['rng.events', (d) => delete d.rng.events],
      ['focusedVesselId', (d) => (d.focusedVesselId = 99)],
      ['vessel 1', (d) => (d.vessels['1'].id = 2)],
      ['vessel 1 transit stars', (d) => (d.vessels['1'].transit.toStarId = 9999)],
      ['time', (d) => (d.time = -5)],
      ['alerts', (d) => delete d.alerts],
      ['nextAlertId', (d) => (d.alerts = [{ id: 4, vesselId: 1, time: 0, level: 'info', text: 'x' }])],
      ['events', (d) => (d.events = [{ id: 1, vesselId: 1, kind: 'nope', time: 0, damage: 0 }])],
      ['vessel 1 hull', (d) => (d.vessels['1'].systems.hull.integrity = null)],
      ['vessel 1 log', (d) => d.vessels['1'].log.push(null)],
      ['vessel 1 log', (d) => d.vessels['1'].log.push({ time: 'x', text: 1 })],
      ['alerts', (d) => { d.alerts = [{ id: 1, vesselId: 1, time: 0, level: 'loud', text: 'x' }]; d.nextAlertId = 2; }],
    ];
    for (const [field, breakIt] of broken) {
      const d = structuredClone(good);
      breakIt(d);
      expect(migrate(d).reason, field).toContain(field);
    }
    expect(migrate(good).state).not.toBeNull();
  });

  it('upgrades a schema 1 save: a cruising Vessel keeps cruising and no events are pending', () => {
    const v2 = JSON.parse(serialize(createGalaxy(4)));
    const t = v2.vessels['1'].transit;
    const v1 = { ...v2, schemaVersion: 1 };
    delete v1.events;
    delete v1.nextEventId;
    v1.vessels = { 1: { ...v2.vessels['1'], transit: { fromStarId: t.fromStarId, toStarId: t.toStarId, distanceLy: t.distanceLy, traveledLy: 2, speedC: 0.2 } } };
    const r = migrate(v1);
    expect(r.reason).toBe('');
    expect(r.state!.schemaVersion).toBe(SCHEMA_VERSION);
    expect(r.state!.events).toEqual([]);
    expect(r.state!.vessels[1]!.transit).toMatchObject({ burn: 'coast', cruiseC: 0.2, speedC: 0.2, traveledLy: 2, dryBurn: false });
  });

  it('has a migration for every past schema version', () => {
    for (let v = 1; v < SCHEMA_VERSION; v++) expect(typeof MIGRATIONS[v]).toBe('function');
    expect(serialize(createGalaxy(1))).toContain(`"schemaVersion":${SCHEMA_VERSION}`);
  });
});
