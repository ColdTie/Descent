import { BODY_KINDS, HAZARDS } from '../content/bodies';
import { BUILDING_TYPES, JOB_CATEGORIES, ROBOT_TYPES } from '../content/colony';
import { ensureColony } from './colony/colony';
import { EVENT_KINDS } from '../content/events';
import { RESOURCE_IDS } from '../content/resources';
import { CRUISE_SPEED_C } from '../content/stars';
import { SYSTEM_IDS } from '../content/systems';
import { STREAM_NAMES } from './rng';
import { BURNS, PHASES, SCHEMA_VERSION, type GalaxyState } from './state';
import { isWarp } from './time';
import { ensureSystem } from './ledger';

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
  // v2 → v3: star systems and worlds. Systems generate lazily, so an arrived v2 Vessel gets its system on first look.
  2: (raw) => {
    const vessels: Raw = {};
    for (const [key, v] of Object.entries(isRecord(raw.vessels) ? raw.vessels : {})) vessels[key] = isRecord(v) ? { ...v, survey: null, worldId: null } : v;
    return { ...raw, vessels, starSystems: {}, worlds: {}, nextWorldId: 1 };
  },
  // v3 → v4: worlds gain a colony. A world landed before Phase 5 gets its colony built at load.
  3: (raw) => {
    const worlds: Raw = {};
    for (const [key, w] of Object.entries(isRecord(raw.worlds) ? raw.worlds : {})) worlds[key] = isRecord(w) ? { ...w, colony: null } : w;
    return { ...raw, worlds };
  },
};

function validateColony(c: unknown, where: string): string {
  if (c === null) return '';
  if (!isRecord(c)) return where;
  if (!int(c.seed) || !int(c.size) || c.size < 8 || c.size > 256) return `${where} size`;
  const cells = c.size * c.size;
  const cellOk = (n: unknown): boolean => int(n) && n >= 0 && n < cells;
  if (!isRecord(c.priorities) || JOB_CATEGORIES.some((k) => !int((c.priorities as Raw)[k]))) return `${where} priorities`;
  if (!isRecord(c.quotas) || ROBOT_TYPES.some((k) => !int((c.quotas as Raw)[k]))) return `${where} quotas`;
  if (!Array.isArray(c.revealed) || c.revealed.length !== cells) return `${where} revealed`;
  if (!Array.isArray(c.nodes) || c.nodes.some((n) => !isRecord(n) || !int(n.id) || !cellOk(n.cell) || (n.kind !== 'ore' && n.kind !== 'ice') || !finite(n.richness) || typeof n.revealed !== 'boolean')) return `${where} nodes`;
  if (!Array.isArray(c.buildings)) return `${where} buildings`;
  const ids = new Set<number>();
  for (const b of c.buildings) {
    if (!isRecord(b) || !int(b.id) || !(BUILDING_TYPES as readonly unknown[]).includes(b.type) || !(b.cell === -1 || cellOk(b.cell))) return `${where} buildings`;
    if (!finite(b.progress) || !finite(b.input) || !finite(b.output) || typeof b.paid !== 'boolean' || typeof b.auto !== 'boolean' || typeof b.working !== 'boolean') return `${where} buildings`;
    if (b.nodeId !== null && !int(b.nodeId)) return `${where} buildings`;
    // Only an unbuilt building may still be waiting for a site.
    if (b.cell === -1 && ((b.progress as number) >= 1 || b.paid)) return `${where} buildings`;
    ids.add(b.id);
  }
  if (!Array.isArray(c.robots)) return `${where} robots`;
  for (const r of c.robots) {
    if (!isRecord(r) || !int(r.id) || !(ROBOT_TYPES as readonly unknown[]).includes(r.type) || !cellOk(r.cell) || !finite(r.edge) || !finite(r.carrying)) return `${where} robots`;
    if (!Array.isArray(r.path) || r.path.some((p) => !cellOk(p))) return `${where} robots`;
    const j = r.job;
    if (j !== null) {
      if (!isRecord(j)) return `${where} robots`;
      if (j.kind === 'survey') {
        if (!cellOk(j.target)) return `${where} robots`;
      } else if (j.kind === 'build') {
        if (!int(j.buildingId)) return `${where} robots`;
      } else if (j.kind === 'haul') {
        if (!(RESOURCE_IDS as readonly unknown[]).includes(j.resource) || j.resource === 'power') return `${where} robots`;
        if ((j.category !== 'mine' && j.category !== 'haul') || !int(j.from) || !int(j.to) || !finite(j.amount) || j.amount < 0 || typeof j.loaded !== 'boolean') return `${where} robots`;
      } else return `${where} robots`;
    }
    ids.add(r.id);
  }
  if (!Array.isArray(c.queue) || c.queue.some((q) => !int(q))) return `${where} queue`;
  if (!int(c.nextId) || [...ids].some((i) => i >= (c.nextId as number))) return `${where} nextId`;
  if (!isRecord(c.power) || !finite(c.power.supply) || !finite(c.power.demand)) return `${where} power`;
  if (!isRecord(c.made) || !isRecord(c.rates) || typeof c.fabricatorOnline !== 'boolean') return `${where} stats`;
  const rb = c.robotBuild;
  if (rb !== null && (!isRecord(rb) || !(ROBOT_TYPES as readonly unknown[]).includes(rb.type) || !finite(rb.remainingHours))) return `${where} robotBuild`;
  return '';
}

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
    for (const e of v.log) if (!isRecord(e) || !finite(e.time) || typeof e.text !== 'string') return `vessel ${key} log`;
    if (v.starId !== null && (!int(v.starId) || !starIds.has(v.starId))) return `vessel ${key} star`;
    const t = v.transit;
    if (t !== null) {
      if (!isRecord(t)) return `vessel ${key} transit`;
      if (!int(t.fromStarId) || !starIds.has(t.fromStarId) || !int(t.toStarId) || !starIds.has(t.toStarId)) return `vessel ${key} transit stars`;
      for (const f of ['distanceLy', 'traveledLy', 'speedC', 'cruiseC'] as const) if (!finite(t[f]) || t[f] < 0) return `vessel ${key} transit ${f}`;
      if (!(BURNS as readonly unknown[]).includes(t.burn) || typeof t.dryBurn !== 'boolean') return `vessel ${key} transit burn`;
    }
    if (v.phase === 'transit' && t === null) return `vessel ${key} transit`;
    const s = v.survey;
    if (s !== null && (!isRecord(s) || !int(s.bodyId) || !finite(s.remainingSeconds) || !finite(s.totalSeconds) || s.remainingSeconds < 0)) return `vessel ${key} survey`;
    if (v.worldId !== null && !int(v.worldId)) return `vessel ${key} worldId`;
  }
  if (!int(d.focusedVesselId) || !isRecord(d.vessels[String(d.focusedVesselId)])) return 'focusedVesselId';
  if (!int(d.nextVesselId) || d.nextVesselId <= maxVessel) return 'nextVesselId';
  if (!Array.isArray(d.alerts)) return 'alerts';
  let maxAlert = 0;
  for (const a of d.alerts) {
    if (!isRecord(a) || !int(a.id) || !int(a.vesselId) || typeof a.text !== 'string' || !finite(a.time)) return 'alerts';
    if (a.level !== 'info' && a.level !== 'warn' && a.level !== 'critical') return 'alerts';
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
  if (!isRecord(d.starSystems)) return 'starSystems';
  for (const [key, sys] of Object.entries(d.starSystems)) {
    if (!isRecord(sys) || !int(sys.starId) || String(sys.starId) !== key || !starIds.has(sys.starId) || !Array.isArray(sys.bodies)) return `starSystems ${key}`;
    for (const [i, b] of sys.bodies.entries()) {
      if (!isRecord(b) || b.id !== i || typeof b.name !== 'string' || !(BODY_KINDS as readonly unknown[]).includes(b.kind) || !finite(b.orbitAu) || typeof b.surveyed !== 'boolean') return `starSystems ${key} body ${i}`;
      const p = b.profile;
      if (!isRecord(p) || !finite(p.ore) || !finite(p.ice) || !finite(p.gravity) || !finite(p.severity) || !(HAZARDS as readonly unknown[]).includes(p.hazard)) return `starSystems ${key} body ${i}`;
    }
  }
  if (!isRecord(d.worlds)) return 'worlds';
  let maxWorld = 0;
  for (const [key, w] of Object.entries(d.worlds)) {
    if (!isRecord(w) || !int(w.id) || String(w.id) !== key || !int(w.vesselId) || !int(w.starId) || !int(w.bodyId) || !finite(w.landedAt)) return `world ${key}`;
    const sys = d.starSystems[String(w.starId)];
    if (!isRecord(sys) || !Array.isArray(sys.bodies) || !sys.bodies[w.bodyId]) return `world ${key} body`;
    if (!('colony' in w)) return `world ${key} colony`;
    const bad = validateColony(w.colony, `world ${key} colony`);
    if (bad) return bad;
    maxWorld = Math.max(maxWorld, w.id);
  }
  if (!int(d.nextWorldId) || d.nextWorldId <= maxWorld) return 'nextWorldId';
  for (const [key, v] of Object.entries(d.vessels)) {
    const vv = v as Raw;
    if (vv.worldId !== null && !isRecord(d.worlds[String(vv.worldId)])) return `vessel ${key} worldId`;
    if (vv.phase === 'planetside' && vv.worldId === null) return `vessel ${key} worldId`;
    if (vv.survey !== null && !(isRecord(d.starSystems[String(vv.starId)]) && Array.isArray((d.starSystems[String(vv.starId)] as Raw).bodies) && ((d.starSystems[String(vv.starId)] as Raw).bodies as unknown[])[(vv.survey as Raw).bodyId as number])) return `vessel ${key} survey`;
  }
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
  const state = data as unknown as GalaxyState;
  // A Vessel in orbit from an older save gets its system now, so a paused resume can survey at once.
  for (const v of Object.values(state.vessels)) {
    if (v.phase === 'arrival' && v.starId !== null) ensureSystem(state, v.starId);
    if (v.phase === 'planetside') ensureColony(state, v);
  }
  return { state, reason: '' };
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
