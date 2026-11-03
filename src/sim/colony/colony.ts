import { BODY_DEFS } from '../../content/bodies';
import {
  BUFFER_CAP,
  BUILDING_DEFS,
  DEFAULT_PRIORITIES,
  HAULER_CAPACITY,
  HAZARD_EFFECTS,
  LANDER_POWER,
  ROBOT_BUILD_HOURS,
  ROBOT_DEFS,
  ROBOT_PARTS,
  ROBOT_TYPES,
  START_REVEAL,
  STARTING_ROBOTS,
  SURVEY_REVEAL,
  WORLD_SIZE,
  type BuildingType,
  type RobotType,
  type StockResource,
} from '../../content/colony';
import { createRng } from '../rng';
import type { Alert, GalaxyState, Vessel, World } from '../state';
import type { BodyProfile } from '../system';
import { findPath, reachable } from './path';
import { cellIndex, cellX, cellY, centerCell, terrainFor, worldSeed, type Terrain } from './terrain';
import type { Building, Colony, ColonyNode, Job, Robot } from './types';

/** The landed Vessel is depot 0 at the centre of the map. */
export const LANDER_ID = 0;

const round2 = (n: number): number => Math.round(n * 100) / 100;
const reachCache = new Map<string, Uint8Array>();

export function colonyTerrain(c: Colony): Terrain {
  return terrainFor(c.seed, c.size);
}

function reachMask(c: Colony): Uint8Array {
  const key = `${c.seed}:${c.size}`;
  let m = reachCache.get(key);
  if (!m) {
    const t = colonyTerrain(c);
    m = reachable(t, centerCell(t.size));
    reachCache.set(key, m);
  }
  return m;
}

function dist(size: number, a: number, b: number): number {
  return Math.hypot(cellX(size, a) - cellX(size, b), cellY(size, a) - cellY(size, b));
}

function reveal(c: Colony, around: number, radius: number): void {
  const cx = cellX(c.size, around);
  const cy = cellY(c.size, around);
  for (let y = Math.max(0, cy - radius); y <= Math.min(c.size - 1, cy + radius); y++) {
    for (let x = Math.max(0, cx - radius); x <= Math.min(c.size - 1, cx + radius); x++) {
      if (Math.hypot(x - cx, y - cy) <= radius) c.revealed[cellIndex(c.size, x, y)] = 1;
    }
  }
  for (const n of c.nodes) if (!n.revealed && c.revealed[n.cell]) n.revealed = true;
}

function makeNodes(c: Colony, profile: BodyProfile): ColonyNode[] {
  const rng = createRng((c.seed ^ 0x5bd1e995) >>> 0);
  const mask = reachMask(c);
  const centre = centerCell(c.size);
  const nodes: ColonyNode[] = [];
  const want: Array<['ore' | 'ice', number]> = [
    ['ore', 2 + Math.round(profile.ore * 4)],
    ['ice', 1 + Math.round(profile.ice * 4)],
  ];
  let id = 1;
  for (const [kind, count] of want) {
    let placed = 0;
    for (let attempt = 0; attempt < 400 && placed < count; attempt++) {
      const cell = rng.int(c.size * c.size);
      const d = dist(c.size, cell, centre);
      if (!mask[cell] || d < 4 || d > 18) continue;
      if (nodes.some((n) => dist(c.size, n.cell, cell) < 3)) continue;
      const base = kind === 'ore' ? profile.ore : profile.ice;
      nodes.push({ id: id++, cell, kind, richness: round2(rng.range(0.5, 1.5) * (0.5 + base)), revealed: false });
      placed++;
    }
  }
  return nodes;
}

/** A colony for a fresh landing: the Vessel's robots on the pad, the area around it known. */
export function createColony(galaxySeed: number, world: World, profile: BodyProfile): Colony {
  const seed = worldSeed(galaxySeed, world.starId, world.bodyId);
  const size = WORLD_SIZE;
  const c: Colony = {
    seed,
    size,
    priorities: { ...DEFAULT_PRIORITIES },
    quotas: { ...STARTING_ROBOTS },
    nodes: [],
    buildings: [],
    robots: [],
    revealed: new Array<number>(size * size).fill(0),
    queue: [],
    robotBuild: null,
    nextId: 1,
    power: { supply: 0, demand: 0 },
    made: {},
    rates: {},
    fabricatorOnline: false,
  };
  c.nodes = makeNodes(c, profile);
  const centre = centerCell(size);
  for (const type of ROBOT_TYPES) {
    for (let i = 0; i < STARTING_ROBOTS[type]; i++) c.robots.push({ id: c.nextId++, type, cell: centre, path: [], edge: 0, job: null, carrying: 0 });
  }
  reveal(c, centre, START_REVEAL);
  return c;
}

export function profileFor(state: GalaxyState, world: World): BodyProfile | undefined {
  return state.starSystems[world.starId]?.bodies[world.bodyId]?.profile;
}

/** The colony for a Vessel's world, creating it for saves that landed before Phase 5. */
export function ensureColony(state: GalaxyState, vessel: Vessel): Colony | null {
  if (vessel.worldId === null) return null;
  const world = state.worlds[vessel.worldId];
  if (!world) return null;
  if (world.colony) return world.colony;
  const profile = profileFor(state, world);
  if (!profile) return null;
  world.colony = createColony(state.seed, world, profile);
  return world.colony;
}

function hazardMult(profile: BodyProfile | undefined, key: 'solar' | 'speed' | 'build' | 'fabricator'): number {
  if (!profile) return 1;
  const per = HAZARD_EFFECTS[profile.hazard][key] ?? 0;
  return Math.max(0.2, 1 - per * profile.severity);
}

// ---- placement and the queue --------------------------------------------

function occupied(c: Colony): Set<number> {
  const s = new Set<number>([centerCell(c.size)]);
  for (const b of c.buildings) if (b.cell >= 0) s.add(b.cell);
  return s;
}

/** Nearest free node of the right kind for a miner, or nearest open revealed ground for anything else. */
function findSite(c: Colony, type: BuildingType): { cell: number; nodeId: number | null } | null {
  const def = BUILDING_DEFS[type];
  const centre = centerCell(c.size);
  const taken = occupied(c);
  if (def.node) {
    const used = new Set(c.buildings.map((b) => b.nodeId).filter((n) => n !== null));
    const free = c.nodes.filter((n) => n.kind === def.node && n.revealed && !used.has(n.id) && !taken.has(n.cell));
    free.sort((a, b) => dist(c.size, a.cell, centre) - dist(c.size, b.cell, centre) || a.id - b.id);
    const n = free[0];
    return n ? { cell: n.cell, nodeId: n.id } : null;
  }
  const mask = reachMask(c);
  const t = colonyTerrain(c);
  const nodeCells = new Set(c.nodes.map((n) => n.cell));
  let best = -1;
  let bestD = Infinity;
  for (let i = 0; i < c.size * c.size; i++) {
    if (!mask[i] || !c.revealed[i] || t.blocked[i] || nodeCells.has(i) || taken.has(i)) continue;
    let crowded = false;
    for (const o of taken) if (Math.max(Math.abs(cellX(c.size, o) - cellX(c.size, i)), Math.abs(cellY(c.size, o) - cellY(c.size, i))) < 2) crowded = true;
    if (crowded) continue;
    const d = dist(c.size, i, centre);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best >= 0 ? { cell: best, nodeId: null } : null;
}

export function addToQueue(c: Colony, type: BuildingType, auto = false): Building {
  const b: Building = { id: c.nextId++, type, cell: -1, nodeId: null, paid: false, auto, progress: 0, input: 0, output: 0, working: false };
  c.buildings.push(b);
  c.queue.push(b.id);
  return b;
}

export function canAfford(stock: Vessel['stock'], type: BuildingType): boolean {
  const cost = BUILDING_DEFS[type].cost;
  return Object.entries(cost).every(([r, n]) => stock[r as StockResource] >= (n ?? 0));
}

function pay(stock: Vessel['stock'], type: BuildingType, sign = -1): void {
  for (const [r, n] of Object.entries(BUILDING_DEFS[type].cost)) stock[r as StockResource] += sign * (n ?? 0);
}

/** Removes a queued building. Refunds the cost in full if no work was done on it yet. */
export function cancelBuilding(c: Colony, stock: Vessel['stock'], buildingId: number): boolean {
  const b = c.buildings.find((x) => x.id === buildingId);
  if (!b || b.progress >= 1) return false;
  if (b.paid && b.progress === 0) pay(stock, b.type, +1);
  c.buildings = c.buildings.filter((x) => x.id !== buildingId);
  c.queue = c.queue.filter((id) => id !== buildingId);
  for (const r of c.robots) if (r.job?.kind === 'build' && r.job.buildingId === buildingId) dropJob(r);
  return true;
}

/** The chain that makes Parts. Until a Fabricator runs, Expand and converter feeding keep its cost in hand. */
const FIRST_CHAIN: BuildingType[] = ['oreMiner', 'refinery', 'fabricator'];

/**
 * Stock that must not be spent on Expand's buildings or fed into converters: the costs of the
 * player's unpaid buildings, plus, until a Fabricator runs, any missing link of the Parts chain.
 */
export function reservations(c: Colony): Partial<Record<StockResource, number>> {
  const reserved: Partial<Record<StockResource, number>> = {};
  const add = (type: BuildingType): void => {
    for (const [r, n] of Object.entries(BUILDING_DEFS[type].cost)) reserved[r as StockResource] = (reserved[r as StockResource] ?? 0) + (n ?? 0);
  };
  for (const b of c.buildings) if (!b.paid && !b.auto && b.progress < 1) add(b.type);
  if (!c.fabricatorOnline) {
    for (const type of FIRST_CHAIN) {
      if (!c.buildings.some((b) => b.type === type && (b.paid || !b.auto))) add(type);
    }
  }
  return reserved;
}

// Placement is retried only when something it depends on changed (map knowledge or buildings).
const placementKey = new WeakMap<Colony, string>();

function serviceQueue(c: Colony, stock: Vessel['stock']): void {
  const reserved = reservations(c);
  const spare = (type: BuildingType): boolean =>
    Object.entries(BUILDING_DEFS[type].cost).every(([r, n]) => stock[r as StockResource] - (reserved[r as StockResource] ?? 0) >= (n ?? 0));
  const key = `${c.revealed.reduce((a, b) => a + b, 0)}:${c.buildings.length}:${c.buildings.filter((b) => b.cell >= 0).length}`;
  const tryPlace = placementKey.get(c) !== key;
  for (const id of c.queue) {
    const b = c.buildings.find((x) => x.id === id);
    if (!b || b.progress >= 1) continue;
    if (b.cell < 0 && tryPlace) {
      const site = findSite(c, b.type);
      if (site) {
        b.cell = site.cell;
        b.nodeId = site.nodeId;
      }
    }
    if (b.cell < 0) continue;
    if (!b.paid && canAfford(stock, b.type) && (!b.auto || spare(b.type))) {
      pay(stock, b.type);
      b.paid = true;
      if (!b.auto) {
        for (const [r, n] of Object.entries(BUILDING_DEFS[b.type].cost)) reserved[r as StockResource] = (reserved[r as StockResource] ?? 0) - (n ?? 0);
      }
    }
  }
  placementKey.set(c, `${c.revealed.reduce((a, b) => a + b, 0)}:${c.buildings.length}:${c.buildings.filter((b) => b.cell >= 0).length}`);
  c.queue = c.queue.filter((id) => c.buildings.some((b) => b.id === id && b.progress < 1));
}

/** Expand: keep a miner on every surveyed node and enough solar for the load. One new site per step. */
function expand(c: Colony): void {
  if (c.priorities.expand <= 0 || c.queue.length >= 8) return;
  // Projected over everything built and queued, so one shortfall queues one array, not one per step.
  const draw = c.buildings.reduce((s, b) => s + (BUILDING_DEFS[b.type].powerDraw ?? 0), 0);
  const supply = LANDER_POWER + c.buildings.reduce((s, b) => s + (BUILDING_DEFS[b.type].powerSupply ?? 0), 0);
  if (supply + 0.01 < draw) {
    addToQueue(c, 'solar', true);
    return;
  }
  const used = new Set(c.buildings.map((b) => b.nodeId));
  const pendingMiners = c.buildings.filter((b) => BUILDING_DEFS[b.type].node && b.cell < 0).length;
  if (pendingMiners > 0) return;
  const wantsIce = c.buildings.some((b) => b.type === 'cracker');
  for (const n of c.nodes) {
    if (!n.revealed || used.has(n.id)) continue;
    // Volatiles only matter once something cracks them.
    if (n.kind === 'ice' && !wantsIce) continue;
    const b = addToQueue(c, n.kind === 'ore' ? 'oreMiner' : 'iceMiner', true);
    b.cell = n.cell;
    b.nodeId = n.id;
    return;
  }
}

// ---- production and power ----------------------------------------------

function built(c: Colony): Building[] {
  return c.buildings.filter((b) => b.progress >= 1);
}

function wantsToRun(c: Colony, b: Building): boolean {
  const def = BUILDING_DEFS[b.type];
  if (!def.powerDraw) return false;
  if (def.mineRate) return b.output < BUFFER_CAP;
  if (def.input) return (b.input > 0 && b.output < BUFFER_CAP) || (b.type === 'fabricator' && c.robotBuild !== null);
  return false;
}

function produce(state: GalaxyState, vessel: Vessel, c: Colony, profile: BodyProfile | undefined, hours: number): Partial<Record<StockResource, number>> {
  const made: Partial<Record<StockResource, number>> = {};
  const done = built(c);
  const powerHealth = Math.max(0, vessel.systems.power.integrity) / 100;
  const supply = LANDER_POWER * powerHealth + done.reduce((s, b) => s + (BUILDING_DEFS[b.type].powerSupply ?? 0), 0) * hazardMult(profile, 'solar');
  const demand = done.filter((b) => wantsToRun(c, b)).reduce((s, b) => s + (BUILDING_DEFS[b.type].powerDraw ?? 0), 0);
  c.power = { supply: round2(supply), demand: round2(demand) };
  const factor = demand > 0 ? Math.min(1, supply / demand) : 1;
  for (const b of done) {
    const def = BUILDING_DEFS[b.type];
    b.working = false;
    if (!wantsToRun(c, b) || factor <= 0) continue;
    if (def.mineRate && def.output) {
      const node = c.nodes.find((n) => n.id === b.nodeId);
      const out = Math.min(BUFFER_CAP - b.output, def.mineRate * (node?.richness ?? 1) * hours * factor);
      b.output += out;
      made[def.output] = (made[def.output] ?? 0) + out;
      b.working = out > 0;
    } else if (def.input && def.output && def.inputRate && def.outputRate) {
      const ratio = def.outputRate / def.inputRate;
      const mult = b.type === 'fabricator' ? hazardMult(profile, 'fabricator') : 1;
      const room = (BUFFER_CAP - b.output) / (ratio * mult);
      const used = Math.min(b.input, def.inputRate * hours * factor, room);
      const out = used * ratio * mult;
      b.input -= used;
      b.output += out;
      made[def.output] = (made[def.output] ?? 0) + out;
      b.working = used > 0 || b.working;
    }
  }
  // The Fabricator also builds robots, one at a time, up to the quotas.
  const fab = done.find((b) => b.type === 'fabricator');
  if (fab) {
    if (!c.robotBuild) {
      const type = ROBOT_TYPES.find((t) => c.robots.filter((r) => r.type === t).length < c.quotas[t]);
      if (type && vessel.stock.parts >= ROBOT_PARTS) {
        vessel.stock.parts -= ROBOT_PARTS;
        c.robotBuild = { type, remainingHours: ROBOT_BUILD_HOURS };
      }
    }
    if (c.robotBuild) {
      c.robotBuild.remainingHours -= hours * factor;
      fab.working = true;
      if (c.robotBuild.remainingHours <= 0) {
        c.robots.push({ id: c.nextId++, type: c.robotBuild.type, cell: fab.cell, path: [], edge: 0, job: null, carrying: 0 });
        logColony(state, vessel, `Fabricator built a ${ROBOT_DEFS[c.robotBuild.type].name.toLowerCase()}.`);
        c.robotBuild = null;
      }
    }
  }
  return made;
}

// ---- robots -------------------------------------------------------------

function depots(c: Colony): Array<{ id: number; cell: number }> {
  return [{ id: LANDER_ID, cell: centerCell(c.size) }, ...built(c).filter((b) => BUILDING_DEFS[b.type].depot).map((b) => ({ id: b.id, cell: b.cell }))];
}

function cellOf(c: Colony, id: number): number {
  if (id === LANDER_ID) return centerCell(c.size);
  return c.buildings.find((b) => b.id === id)?.cell ?? -1;
}


function dropJob(r: Robot): void {
  r.job = null;
  r.path = [];
  r.edge = 0;
}

interface Option {
  score: number;
  job: Job;
  target: number;
}

/** What every robot's job choice reads, built once per slice and updated as robots take jobs. */
interface SliceCtx {
  built: Building[];
  byId: Map<number, Building>;
  nearestDepot: Map<number, { id: number; cell: number }>;
  claimedOut: Map<number, number>;
  claimedIn: Map<number, number>;
  /** Stock already promised to loaded-at-depot hauls, per resource. */
  claimedStock: Partial<Record<StockResource, number>>;
  surveyTargets: Set<number>;
  reserved: Partial<Record<StockResource, number>>;
  /** Resources a built converter is waiting for. */
  demand: Set<StockResource>;
}

function claim(ctx: SliceCtx, job: Job): void {
  if (job.kind === 'survey') ctx.surveyTargets.add(job.target);
  if (job.kind !== 'haul') return;
  if (!job.loaded) {
    ctx.claimedOut.set(job.from, (ctx.claimedOut.get(job.from) ?? 0) + job.amount);
    if (job.from === LANDER_ID || ctx.byId.get(job.from)?.type === 'depot') ctx.claimedStock[job.resource] = (ctx.claimedStock[job.resource] ?? 0) + job.amount;
  }
  ctx.claimedIn.set(job.to, (ctx.claimedIn.get(job.to) ?? 0) + job.amount);
}

function sliceCtx(c: Colony): SliceCtx {
  const done = built(c);
  const deps = depots(c);
  const ctx: SliceCtx = {
    built: done,
    byId: new Map(c.buildings.map((b) => [b.id, b])),
    nearestDepot: new Map(),
    claimedOut: new Map(),
    claimedIn: new Map(),
    claimedStock: {},
    surveyTargets: new Set(),
    reserved: reservations(c),
    demand: new Set(),
  };
  for (const b of done) {
    let best = deps[0]!;
    for (const d of deps) if (dist(c.size, d.cell, b.cell) < dist(c.size, best.cell, b.cell)) best = d;
    ctx.nearestDepot.set(b.id, best);
    const def = BUILDING_DEFS[b.type];
    if (def.input && BUFFER_CAP - b.input >= 5) ctx.demand.add(def.input);
  }
  for (const r of c.robots) if (r.job) claim(ctx, r.job);
  return ctx;
}

function pickJob(c: Colony, r: Robot, stock: Vessel['stock'], ctx: SliceCtx): Option | null {
  const p = c.priorities;
  let best: Option | null = null;
  const offer = (o: Option): void => {
    if (!best || o.score > best.score || (o.score === best.score && o.target < best.target)) best = o;
  };
  const d = (cell: number): number => dist(c.size, r.cell, cell);
  const spareStock = (res: StockResource): number => stock[res] - (ctx.reserved[res] ?? 0) - (ctx.claimedStock[res] ?? 0);
  if (r.type === 'surveyor' && p.survey > 0) {
    const mask = reachMask(c);
    let cell = -1;
    let bestD = Infinity;
    for (let i = 0; i < c.size * c.size; i++) {
      if (c.revealed[i] || !mask[i] || ctx.surveyTargets.has(i)) continue;
      const di = d(i);
      if (di < bestD) {
        bestD = di;
        cell = i;
      }
    }
    if (cell >= 0) offer({ score: p.survey * 1000 - bestD, job: { kind: 'survey', target: cell }, target: cell });
  }
  if (r.type === 'builder' && p.build > 0) {
    c.queue.forEach((id, qi) => {
      const b = ctx.byId.get(id);
      if (!b || !b.paid || b.progress >= 1 || b.cell < 0) return;
      offer({ score: p.build * 1000 - d(b.cell) - qi * 2, job: { kind: 'build', buildingId: b.id }, target: b.cell });
    });
  }
  if (r.type === 'hauler') {
    for (const b of ctx.built) {
      const def = BUILDING_DEFS[b.type];
      const depot = ctx.nearestDepot.get(b.id)!;
      if (def.output) {
        const category = def.mineRate ? 'mine' : 'haul';
        const avail = b.output - (ctx.claimedOut.get(b.id) ?? 0);
        if (p[category] > 0 && avail >= 5 - 1e-9) {
          // Urgency: fuller buffers first; a resource a converter is waiting for and the stock lacks goes ahead of
          // raw material already piled up at home.
          let urgency = b.output * (def.mineRate ? 5 : 10);
          if (ctx.demand.has(def.output) && spareStock(def.output) < 10) urgency += 300;
          else if (def.mineRate && spareStock(def.output) > 100) urgency -= 400;
          offer({ score: p[category] * 1000 + urgency - d(b.cell), job: { kind: 'haul', category, resource: def.output, from: b.id, to: depot.id, amount: Math.min(HAULER_CAPACITY, avail), loaded: false }, target: b.cell });
        }
      }
      if (def.input && p.haul > 0) {
        const room = BUFFER_CAP - b.input - (ctx.claimedIn.get(b.id) ?? 0);
        // Only stock nobody else needs: the player's unpaid buildings keep their share.
        const have = spareStock(def.input);
        if (room >= 5 && have >= 1) {
          const urgency = (BUFFER_CAP - b.input) * 10;
          offer({ score: p.haul * 1000 + urgency - d(depot.cell), job: { kind: 'haul', category: 'haul', resource: def.input, from: depot.id, to: b.id, amount: Math.min(HAULER_CAPACITY, room, have), loaded: false }, target: depot.cell });
        }
      }
    }
  }
  return best;
}

function speedOf(r: Robot, profile: BodyProfile | undefined): number {
  const g = profile?.gravity ?? 1;
  return (ROBOT_DEFS[r.type].speed / Math.max(0.5, Math.sqrt(g))) * hazardMult(profile, 'speed');
}

/** Walks the path; returns hours left over. */
function walk(c: Colony, r: Robot, hours: number, speed: number): number {
  let budget = speed * hours;
  while (budget > 1e-12 && r.path.length) {
    const next = r.path[0]!;
    const diag = cellX(c.size, next) !== cellX(c.size, r.cell) && cellY(c.size, next) !== cellY(c.size, r.cell);
    const len = diag ? Math.SQRT2 : 1;
    const rem = len * (1 - r.edge);
    if (budget >= rem) {
      budget -= rem;
      r.cell = next;
      r.path.shift();
      r.edge = 0;
    } else {
      r.edge += budget / len;
      budget = 0;
    }
  }
  return budget / speed;
}

function routeTo(c: Colony, r: Robot, cell: number): boolean {
  const p = findPath(colonyTerrain(c), r.cell, cell);
  if (!p) return false;
  r.path = p;
  r.edge = 0;
  return true;
}

function logColony(state: GalaxyState, vessel: Vessel, text: string): void {
  vessel.log.push({ time: state.time, text });
  if (vessel.log.length > 200) vessel.log.splice(0, vessel.log.length - 200);
}

function runRobot(state: GalaxyState, vessel: Vessel, c: Colony, r: Robot, hours: number, profile: BodyProfile | undefined, alerts: Alert[], ctx: SliceCtx): void {
  const speed = speedOf(r, profile);
  let h = hours;
  for (let guard = 0; guard < 24 && h > 1e-9; guard++) {
    if (!r.job) {
      const opt = pickJob(c, r, vessel.stock, ctx);
      if (!opt) return;
      if (!routeTo(c, r, opt.target)) {
        // Unreachable target: survey marks it known so it is not chosen again; other jobs wait.
        if (opt.job.kind === 'survey') c.revealed[opt.target] = 1;
        return;
      }
      r.job = opt.job;
      claim(ctx, opt.job);
    }
    if (r.path.length) {
      h = walk(c, r, h, speed);
      if (r.path.length) return;
    }
    const job = r.job;
    if (job.kind === 'survey') {
      reveal(c, r.cell, SURVEY_REVEAL);
      dropJob(r);
    } else if (job.kind === 'build') {
      const b = c.buildings.find((x) => x.id === job.buildingId);
      if (!b || b.progress >= 1) {
        dropJob(r);
        continue;
      }
      const rate = hazardMult(profile, 'build') / BUILDING_DEFS[b.type].buildHours;
      const need = (1 - b.progress) / rate;
      const spend = Math.min(h, need);
      b.progress = Math.min(1, b.progress + spend * rate);
      h -= spend;
      if (b.progress >= 1) {
        b.progress = 1;
        logColony(state, vessel, `${BUILDING_DEFS[b.type].name} built.`);
        if (b.type === 'fabricator' && !c.fabricatorOnline) {
          c.fabricatorOnline = true;
          const alert: Alert = { id: state.nextAlertId++, vesselId: vessel.id, time: state.time, level: 'info', text: 'Fabricator online. This world can make Parts and robots.' };
          state.alerts.push(alert);
          alerts.push(alert);
        }
        dropJob(r);
      }
    } else {
      if (!job.loaded) {
        if (job.from === LANDER_ID || BUILDING_DEFS[c.buildings.find((x) => x.id === job.from)?.type ?? 'solar'].depot) {
          const take = Math.min(job.amount, vessel.stock[job.resource]);
          vessel.stock[job.resource] -= take;
          r.carrying = take;
        } else {
          const src = c.buildings.find((x) => x.id === job.from);
          const take = Math.min(job.amount, src?.output ?? 0);
          if (src) src.output -= take;
          r.carrying = take;
        }
        if (r.carrying <= 1e-9) {
          r.carrying = 0;
          dropJob(r);
          continue;
        }
        job.loaded = true;
        job.amount = r.carrying;
        const dest = cellOf(c, job.to);
        if (dest < 0 || !routeTo(c, r, dest)) {
          vessel.stock[job.resource] += r.carrying;
          r.carrying = 0;
          dropJob(r);
          return;
        }
      } else {
        const dest = c.buildings.find((x) => x.id === job.to);
        if (job.to === LANDER_ID || (dest && BUILDING_DEFS[dest.type].depot)) {
          vessel.stock[job.resource] += r.carrying;
        } else if (dest) {
          const fit = Math.min(r.carrying, BUFFER_CAP - dest.input);
          dest.input += fit;
          vessel.stock[job.resource] += r.carrying - fit;
        } else {
          vessel.stock[job.resource] += r.carrying;
        }
        r.carrying = 0;
        dropJob(r);
      }
    }
  }
}

/** Longest slice a colony integrates at once. Chains of handoffs (mine, haul, refine) need it at day-long warp steps. */
export const COLONY_SUBSTEP_HOURS = 2;

/**
 * One fixed step of a landed colony. Long steps are cut into slices of at most two game hours so a
 * chain of handoffs moves at the same pace at 10M warp as at 1x (CLAUDE.md rule 4).
 */
export function stepColony(state: GalaxyState, vessel: Vessel, c: Colony, dtSeconds: number, alerts: Alert[]): void {
  const total = dtSeconds / 3600;
  const slices = Math.max(1, Math.ceil(total / COLONY_SUBSTEP_HOURS - 1e-9));
  const made: Partial<Record<StockResource, number>> = {};
  for (let i = 0; i < slices; i++) {
    const m = sliceColony(state, vessel, c, total / slices, alerts);
    for (const [k, v] of Object.entries(m)) made[k as StockResource] = (made[k as StockResource] ?? 0) + v;
  }
  // Lifetime totals stay unrounded so they do not depend on step size; views round for display.
  for (const [k, v] of Object.entries(made)) c.made[k as StockResource] = (c.made[k as StockResource] ?? 0) + v;
  c.rates = {};
  for (const [k, v] of Object.entries(made)) c.rates[k as StockResource] = round2(v / Math.max(total, 1e-9));
  vessel.stock.power = round2(c.power.supply - c.power.demand);
}

function sliceColony(state: GalaxyState, vessel: Vessel, c: Colony, hours: number, alerts: Alert[]): Partial<Record<StockResource, number>> {
  const world = vessel.worldId === null ? undefined : state.worlds[vessel.worldId];
  const profile = world ? profileFor(state, world) : undefined;
  expand(c);
  serviceQueue(c, vessel.stock);
  const made = produce(state, vessel, c, profile, hours);
  const ctx = sliceCtx(c);
  for (const r of c.robots) runRobot(state, vessel, c, r, hours, profile, alerts, ctx);
  return made;
}

export function isLandable(kind: keyof typeof BODY_DEFS): boolean {
  return BODY_DEFS[kind].landable;
}

export function robotCount(c: Colony, type: RobotType): number {
  return c.robots.filter((r) => r.type === type).length;
}
