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
    expect(migrate({ schemaVersion: SCHEMA_VERSION, time: 0 }).reason).toContain('missing galaxy fields');
  });

  it('has a migration for every past schema version', () => {
    for (let v = 1; v < SCHEMA_VERSION; v++) expect(typeof MIGRATIONS[v]).toBe('function');
    expect(serialize(createGalaxy(1))).toContain(`"schemaVersion":${SCHEMA_VERSION}`);
  });
});
