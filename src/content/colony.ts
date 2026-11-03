import type { Hazard } from './bodies';
import type { ResourceId } from './resources';

export const BUILDING_TYPES = ['solar', 'oreMiner', 'iceMiner', 'refinery', 'cracker', 'fabricator', 'depot', 'shipyard'] as const;
export type BuildingType = (typeof BUILDING_TYPES)[number];

export type StockResource = Exclude<ResourceId, 'power'>;

export interface BuildingDef {
  name: string;
  /** Paid from the stockpile when construction starts. */
  cost: Partial<Record<StockResource, number>>;
  /** Builder-hours of work at a healthy site. */
  buildHours: number;
  /** Power generated (solar) or drawn while working. */
  powerSupply?: number;
  powerDraw?: number;
  /** Sits on a node of this kind. */
  node?: 'ore' | 'ice';
  /** Raw output per game hour for miners (times node richness). */
  mineRate?: number;
  /** Converters: input per hour turns into output per hour. */
  input?: StockResource;
  inputRate?: number;
  output?: StockResource;
  outputRate?: number;
  /** Haulers drop stock here. */
  depot?: boolean;
  /** Not queueable yet (Phase 7). */
  locked?: boolean;
}

export const BUILDING_DEFS: Record<BuildingType, BuildingDef> = {
  solar: { name: 'Solar array', cost: { parts: 2 }, buildHours: 24, powerSupply: 5 },
  oreMiner: { name: 'Ore miner', cost: { parts: 2 }, buildHours: 36, powerDraw: 2, node: 'ore', mineRate: 3, output: 'ore' },
  iceMiner: { name: 'Ice miner', cost: { parts: 2 }, buildHours: 36, powerDraw: 2, node: 'ice', mineRate: 3, output: 'volatiles' },
  refinery: { name: 'Refinery', cost: { parts: 3 }, buildHours: 48, powerDraw: 3, input: 'ore', inputRate: 2, output: 'metal', outputRate: 1 },
  cracker: { name: 'Cracker', cost: { parts: 2, metal: 10 }, buildHours: 48, powerDraw: 3, input: 'volatiles', inputRate: 2, output: 'fuel', outputRate: 1 },
  fabricator: { name: 'Fabricator', cost: { parts: 4, metal: 30 }, buildHours: 72, powerDraw: 4, input: 'metal', inputRate: 2, output: 'parts', outputRate: 0.5 },
  depot: { name: 'Depot', cost: { metal: 10 }, buildHours: 24, depot: true },
  shipyard: { name: 'Shipyard', cost: { metal: 400, parts: 120, fuel: 60 }, buildHours: 300, powerDraw: 6, locked: true },
};

/** Input and output buffers on each building, in units. */
export const BUFFER_CAP = 20;
/** Power from the landed Vessel's own reactor, scaled by its Power integrity. */
export const LANDER_POWER = 4;

export const ROBOT_TYPES = ['surveyor', 'builder', 'hauler'] as const;
export type RobotType = (typeof ROBOT_TYPES)[number];

export interface RobotDef {
  name: string;
  /** Grid cells per game hour on flat ground at 1 g. */
  speed: number;
}

export const ROBOT_DEFS: Record<RobotType, RobotDef> = {
  surveyor: { name: 'Surveyor', speed: 3 },
  builder: { name: 'Builder', speed: 2 },
  hauler: { name: 'Hauler', speed: 2.5 },
};

/** Robots the Vessel brings down with it. */
export const STARTING_ROBOTS: Record<RobotType, number> = { surveyor: 1, builder: 2, hauler: 2 };
export const HAULER_CAPACITY = 10;
/** The Fabricator builds robots from Parts. */
export const ROBOT_PARTS = 5;
export const ROBOT_BUILD_HOURS = 24;

export const JOB_CATEGORIES = ['survey', 'mine', 'build', 'haul', 'expand'] as const;
export type JobCategory = (typeof JOB_CATEGORIES)[number];
export const JOB_NAMES: Record<JobCategory, string> = { survey: 'Survey', mine: 'Mine', build: 'Build', haul: 'Haul', expand: 'Expand' };
export const PRIORITY_MAX = 5;
export const DEFAULT_PRIORITIES: Record<JobCategory, number> = { survey: 3, mine: 3, build: 4, haul: 3, expand: 2 };

/** Grid cells per side of a world map. */
export const WORLD_SIZE = 40;
/** Radius around the landing site that is known on landing; a surveyor reveals this far on each trip. */
export const START_REVEAL = 5;
export const SURVEY_REVEAL = 4;

/** Hazard effects per severity step. */
export const HAZARD_EFFECTS: Record<Hazard, { solar?: number; speed?: number; build?: number; fabricator?: number }> = {
  none: {},
  heat: { speed: 0.1 },
  cold: { speed: 0.1 },
  storms: { solar: 0.2 },
  quakes: { build: 0.15 },
  radiation: { fabricator: 0.15 },
};
