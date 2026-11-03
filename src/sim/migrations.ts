import { SCHEMA_VERSION, type GalaxyState } from './state';

type Migration = (raw: Record<string, unknown>) => Record<string, unknown>;

/** Index N upgrades a save at schemaVersion N to N + 1. Add one entry per bump; never edit an old one. */
export const MIGRATIONS: Record<number, Migration> = {};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Takes parsed JSON and returns a current GalaxyState, or null with a reason when the save cannot be used.
 * A newer save than this build is refused rather than guessed at (CLAUDE.md rule 5).
 */
export function migrate(raw: unknown): { state: GalaxyState | null; reason: string } {
  if (!isRecord(raw)) return { state: null, reason: 'save is not an object' };
  const version = raw.schemaVersion;
  if (typeof version !== 'number' || !Number.isInteger(version) || version < 1) return { state: null, reason: 'save has no schemaVersion' };
  if (version > SCHEMA_VERSION) return { state: null, reason: `save is schema ${version}, this build reads up to ${SCHEMA_VERSION}` };
  let data: Record<string, unknown> = raw;
  for (let v = version; v < SCHEMA_VERSION; v++) {
    const step = MIGRATIONS[v];
    if (!step) return { state: null, reason: `no migration from schema ${v}` };
    data = { ...step(data), schemaVersion: v + 1 };
  }
  if (!isRecord(data.vessels) || !Array.isArray(data.stars) || typeof data.time !== 'number' || !isRecord(data.rng)) {
    return { state: null, reason: 'save is missing galaxy fields' };
  }
  return { state: data as unknown as GalaxyState, reason: '' };
}

export function serialize(state: GalaxyState): string {
  return JSON.stringify(state);
}

export function deserialize(text: string): { state: GalaxyState | null; reason: string } {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return { state: null, reason: 'save is not valid JSON' };
  }
  return migrate(raw);
}
