import { EVENT_KINDS } from '../content/events';
import { RESOURCE_IDS } from '../content/resources';
import { CRUISE_SPEED_C } from '../content/stars';
import { SYSTEM_IDS } from '../content/systems';
import { STREAM_NAMES } from './rng';
import { BURNS, PHASES, SCHEMA_VERSION, type GalaxyState } from './state';
import { isWarp } from './time';

type Raw = Record<string, unknown>;
type Migration = (raw: Raw) => Raw;

function isRecord(value: unknown): value is Raw {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Index N upgrades a save at schemaVersion N to N + 1. Add one entry per bump; never edit an old one. */
export const MIGRATIONS: Record<number, Migration> = {
  // v1 → v2: transits gain a burn plan (a v1 Vessel is already at cruise), pending events arrive.
  1: (raw) => {
    const vessels: Raw = {};
    for (const [key, v] of Object.entries(isRecord(raw.vessels) ? raw.vessels : {})) {
      if (!isRecord(v)) {
        vessels[key] = v;
        continue;
      }
      const t = v.transit;
      vessels[key] = isRecord(t) ? { ...v, transit: { ...t, cruiseC: typeof t.speedC === 'number' ? t.speedC : CRUISE_SPEED_C, burn: 'coast', dryBurn: false } } : v;
    }
    return { ...raw, vessels, events: [], nextEventId: 1 };
  },
};

const finite = (n: unknown): n is number => typeof n === 'number' && Number.isFinite(n);
const int = (n: unknown): n is number => Number.isInteger(n);

/** Checks every field the sim reads. Returns the first problem, or '' when the galaxy is usable. */
export function validateGalaxy(d: Raw): string {
  if (!finite(d.seed)) return 'seed';
  if (!finite(d.time) || d.time < 0) return 'time';
  if (typeof d.warp !== 'number' || !isWarp(d.warp)) return 'warp';
  if (typeof d.paused !== 'boolean') return 'paused';
  if (!isRecord(d.rng)) return 'rng';
  for (const name of STREAM_NAMES) {
    const c = d.rng[name];
    if (!int(c) || c < 0 || c > 0xffffffff) return `rng.${name}`;
  }
  if (!Array.isArray(d.stars) || d.stars.length === 0) return 'stars';
  const starIds = new Set<number>();
  for (const s of d.stars) {
    if (!isRecord(s) || !int(s.id) || !finite(s.x) || !finite(s.y) || !finite(s.z) || typeof s.name !== 'string') return 'stars';
    starIds.add(s.id);
  }
  if (!isRecord(d.vessels) || Object.keys(d.vessels).length === 0) return 'vessels';
  let maxVessel = 0;
  for (const [key, v] of Object.entries(d.vessels)) {
    if (!isRecord(v) || !int(v.id) || String(v.id) !== key) return `vessel ${key}`;
    maxVessel = Math.max(maxVessel, v.id);
    if (typeof v.name !== 'string' || !(PHASES as readonly unknown[]).includes(v.phase)) return `vessel ${key} phase`;
    if (!isRecord(v.systems)) return `vessel ${key} systems`;
    for (const id of SYSTEM_IDS) {
      const s = v.systems[id];
      if (!isRecord(s) || !finite(s.integrity) || !Array.isArray(s.alerted)) return `vessel ${key} ${id}`;
    }
    if (!isRecord(v.stock)) return `vessel ${key} stock`;
    for (const id of RESOURCE_IDS) if (!finite(v.stock[id])) return `vessel ${key} ${id}`;
    if (!Array.isArray(v.log)) return `vessel ${key} log`;
    if (v.starId !== null && (!int(v.starId) || !starIds.has(v.starId))) return `vessel ${key} star`;
    const t = v.transit;
    if (t !== null) {
      if (!isRecord(t)) return `vessel ${key} transit`;
      if (!int(t.fromStarId) || !starIds.has(t.fromStarId) || !int(t.toStarId) || !starIds.has(t.toStarId)) return `vessel ${key} transit stars`;
      for (const f of ['distanceLy', 'traveledLy', 'speedC', 'cruiseC'] as const) if (!finite(t[f]) || t[f] < 0) return `vessel ${key} transit ${f}`;
      if (!(BURNS as readonly unknown[]).includes(t.burn) || typeof t.dryBurn !== 'boolean') return `vessel ${key} transit burn`;
    }
    if (v.phase === 'transit' && t === null) return `vessel ${key} transit`;
  }
  if (!int(d.focusedVesselId) || !isRecord(d.vessels[String(d.focusedVesselId)])) return 'focusedVesselId';
  if (!int(d.nextVesselId) || d.nextVesselId <= maxVessel) return 'nextVesselId';
  if (!Array.isArray(d.alerts)) return 'alerts';
  let maxAlert = 0;
  for (const a of d.alerts) {
    if (!isRecord(a) || !int(a.id) || !int(a.vesselId) || typeof a.text !== 'string') return 'alerts';
    maxAlert = Math.max(maxAlert, a.id);
  }
  if (!int(d.nextAlertId) || d.nextAlertId <= maxAlert) return 'nextAlertId';
  if (!Array.isArray(d.events)) return 'events';
  let maxEvent = 0;
  for (const e of d.events) {
    if (!isRecord(e) || !int(e.id) || !int(e.vesselId) || !isRecord(d.vessels[String(e.vesselId)])) return 'events';
    if (!(EVENT_KINDS as readonly unknown[]).includes(e.kind) || !finite(e.damage) || !finite(e.time)) return 'events';
    maxEvent = Math.max(maxEvent, e.id);
  }
  if (!int(d.nextEventId) || d.nextEventId <= maxEvent) return 'nextEventId';
  return '';
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
  let data: Raw = raw;
  for (let v = version; v < SCHEMA_VERSION; v++) {
    const step = MIGRATIONS[v];
    if (!step) return { state: null, reason: `no migration from schema ${v}` };
    data = { ...step(data), schemaVersion: v + 1 };
  }
  const problem = validateGalaxy(data);
  if (problem) return { state: null, reason: `save has a bad ${problem}` };
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
