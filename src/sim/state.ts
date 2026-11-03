import { RESOURCE_IDS, STARTING_STOCK, type ResourceId } from '../content/resources';
import { CRUISE_SPEED_C } from '../content/stars';
import { SYSTEM_DEFS, SYSTEM_IDS, type SystemId } from '../content/systems';
import { initialRngStates, streamRng, type RngStates } from './rng';
import { distanceLy, generateStars, pickHopTarget, type Star } from './stars';
import type { Warp } from './time';

export const SCHEMA_VERSION = 1;

export type Phase = 'transit' | 'arrival' | 'planetside' | 'replicate' | 'launch';

export interface SystemState {
  /** 0 to 100. */
  integrity: number;
  /** Which alert thresholds this system has already crossed (so each fires once). */
  alerted: number[];
}

export interface Transit {
  fromStarId: number;
  toStarId: number;
  distanceLy: number;
  traveledLy: number;
  /** Fraction of c. */
  speedC: number;
}

export type AlertLevel = 'info' | 'warn' | 'critical';

export interface Alert {
  id: number;
  vesselId: number;
  time: number;
  level: AlertLevel;
  text: string;
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
  nextVesselId: number;
  nextAlertId: number;
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

/** A new galaxy: star map from the galaxy stream, Vessel 1 already under way on its first hop. */
export function createGalaxy(seed: number): GalaxyState {
  const rng = initialRngStates(seed);
  const stars = generateStars(streamRng(rng, 'galaxy'));
  const home = stars[0]!;
  const target = pickHopTarget(stars, home.id);
  const transit: Transit | null = target
    ? { fromStarId: home.id, toStarId: target.id, distanceLy: distanceLy(home, target), traveledLy: 0, speedC: CRUISE_SPEED_C }
    : null;
  const root: Vessel = {
    id: 1,
    name: 'Vessel 1',
    parentId: null,
    phase: transit ? 'transit' : 'arrival',
    starId: transit ? null : home.id,
    transit,
    systems: freshSystems(),
    stock: freshStock(),
    log: [],
  };
  appendLog(root, 0, transit ? `Launched from ${home.name} toward ${target!.name}, ${transit.distanceLy.toFixed(1)} ly.` : `Holding at ${home.name}.`);
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
    nextVesselId: 2,
    nextAlertId: 1,
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
  return state.stars[id] && state.stars[id]!.id === id ? state.stars[id] : state.stars.find((s) => s.id === id);
}

/** Baseline wear for a system, exposed for the ledger and the UI tooltips. */
export function wearPerHour(id: SystemId): number {
  return SYSTEM_DEFS[id].wearPerHour;
}
