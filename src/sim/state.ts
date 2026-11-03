import type { EventKind } from '../content/events';
import { RESOURCE_IDS, STARTING_STOCK, type ResourceId } from '../content/resources';
import { CRUISE_SPEED_C } from '../content/stars';
import { SYSTEM_IDS, type SystemId } from '../content/systems';
import { initialRngStates, streamRng, type RngStates } from './rng';
import { distanceLy, generateStars, pickHopTarget, type Star } from './stars';
import type { StarSystem } from './system';
import type { Warp } from './time';

export const SCHEMA_VERSION = 3;

export const PHASES = ['transit', 'arrival', 'planetside', 'replicate', 'launch', 'lost'] as const;
export type Phase = (typeof PHASES)[number];

export interface SystemState {
  /** 0 to 100. */
  integrity: number;
  /** Alert thresholds currently crossed. A threshold re-arms once integrity is back above it. */
  alerted: number[];
}

export const BURNS = ['accel', 'coast', 'decel'] as const;
export type Burn = (typeof BURNS)[number];

export interface Transit {
  fromStarId: number;
  toStarId: number;
  distanceLy: number;
  traveledLy: number;
  /** Current speed, fraction of c. */
  speedC: number;
  /** Speed the launch burn aims for. */
  cruiseC: number;
  burn: Burn;
  /** True once the deceleration burn has run without fuel or drive (raises its alert once). */
  dryBurn: boolean;
}

export type AlertLevel = 'info' | 'warn' | 'critical';

export interface Alert {
  id: number;
  vesselId: number;
  time: number;
  level: AlertLevel;
  text: string;
}

/** A transit event waiting for the player's choice. The galaxy does not step while one is open. */
export interface PendingEvent {
  id: number;
  vesselId: number;
  kind: EventKind;
  time: number;
  /** Integrity the event took from its system when it happened. */
  damage: number;
}

/** A survey in progress. Game time spent in orbit counts it down. */
export interface Survey {
  bodyId: number;
  remainingSeconds: number;
  totalSeconds: number;
}

/** A body a Vessel has landed on. Planetside state (nodes, buildings, robots) arrives in Phase 5. */
export interface World {
  id: number;
  starId: number;
  bodyId: number;
  vesselId: number;
  landedAt: number;
}

export interface LogEntry {
  time: number;
  text: string;
}

export interface Vessel {
  id: number;
  name: string;
  parentId: number | null;
  phase: Phase;
  /** Star the Vessel is at, when not in transit. */
  starId: number | null;
  transit: Transit | null;
  /** Survey under way while in orbit (phase arrival). */
  survey: Survey | null;
  /** World the Vessel has landed on. */
  worldId: number | null;
  systems: Record<SystemId, SystemState>;
  stock: Record<ResourceId, number>;
  log: LogEntry[];
}

export interface GalaxyState {
  schemaVersion: number;
  seed: number;
  /** Game seconds since epoch. */
  time: number;
  warp: Warp;
  paused: boolean;
  rng: RngStates;
  stars: Star[];
  vessels: Record<number, Vessel>;
  focusedVesselId: number;
  alerts: Alert[];
  events: PendingEvent[];
  /** Star systems, generated lazily the first time a Vessel arrives. Keyed by star id. */
  starSystems: Record<number, StarSystem>;
  worlds: Record<number, World>;
  nextWorldId: number;
  nextVesselId: number;
  nextAlertId: number;
  nextEventId: number;
}

export const LOG_CAP = 200;

export function freshSystems(): Record<SystemId, SystemState> {
  const systems = {} as Record<SystemId, SystemState>;
  for (const id of SYSTEM_IDS) systems[id] = { integrity: 100, alerted: [] };
  return systems;
}

export function freshStock(): Record<ResourceId, number> {
  const stock = {} as Record<ResourceId, number>;
  for (const id of RESOURCE_IDS) stock[id] = STARTING_STOCK[id];
  return stock;
}

export function appendLog(vessel: Vessel, time: number, text: string): void {
  vessel.log.push({ time, text });
  if (vessel.log.length > LOG_CAP) vessel.log.splice(0, vessel.log.length - LOG_CAP);
}

export function newTransit(from: Star, to: Star, cruiseC = CRUISE_SPEED_C): Transit {
  return { fromStarId: from.id, toStarId: to.id, distanceLy: distanceLy(from, to), traveledLy: 0, speedC: 0, cruiseC, burn: 'accel', dryBurn: false };
}

/** A new galaxy: star map from the galaxy stream, Vessel 1 starting its launch burn toward the nearest hop. */
export function createGalaxy(seed: number): GalaxyState {
  const rng = initialRngStates(seed);
  const stars = generateStars(streamRng(rng, 'galaxy'));
  const home = stars[0]!;
  const target = pickHopTarget(stars, home.id);
  const transit = target ? newTransit(home, target) : null;
  const root: Vessel = {
    id: 1,
    name: 'Vessel 1',
    parentId: null,
    phase: transit ? 'transit' : 'arrival',
    starId: transit ? null : home.id,
    transit,
    survey: null,
    worldId: null,
    systems: freshSystems(),
    stock: freshStock(),
    log: [],
  };
  appendLog(root, 0, transit ? `Launch burn toward ${target!.name}, ${transit.distanceLy.toFixed(1)} ly.` : `Holding at ${home.name}.`);
  return {
    schemaVersion: SCHEMA_VERSION,
    seed,
    time: 0,
    warp: 1,
    paused: false,
    rng,
    stars,
    vessels: { 1: root },
    focusedVesselId: 1,
    alerts: [],
    events: [],
    starSystems: {},
    worlds: {},
    nextWorldId: 1,
    nextVesselId: 2,
    nextAlertId: 1,
    nextEventId: 1,
  };
}

export function getVessel(state: GalaxyState, id: number): Vessel | undefined {
  return state.vessels[id];
}

export function focusedVessel(state: GalaxyState): Vessel {
  const v = state.vessels[state.focusedVesselId];
  if (v) return v;
  const first = Object.values(state.vessels)[0];
  if (!first) throw new Error('galaxy has no Vessels');
  return first;
}

export function starById(state: GalaxyState, id: number): Star | undefined {
  const direct = state.stars[id];
  return direct && direct.id === id ? direct : state.stars.find((s) => s.id === id);
}
