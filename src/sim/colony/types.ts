import type { BuildingType, JobCategory, RobotType, StockResource } from '../../content/colony';

export interface ColonyNode {
  id: number;
  cell: number;
  kind: 'ore' | 'ice';
  /** Multiplies the miner rate. */
  richness: number;
  revealed: boolean;
}

export interface Building {
  id: number;
  type: BuildingType;
  /** -1 until a site is found (a miner waiting for a surveyed node). */
  cell: number;
  nodeId: number | null;
  /** Costs are paid from the stockpile when construction can start. */
  paid: boolean;
  /** Queued by Expand rather than by the player; only spends what the player's queue does not need. */
  auto: boolean;
  /** 0 to 1; 1 means built. */
  progress: number;
  input: number;
  output: number;
  /** Ran this step (had power, input and room). */
  working: boolean;
}

export type Job =
  | { kind: 'survey'; target: number }
  | { kind: 'build'; buildingId: number }
  | {
      kind: 'haul';
      category: 'mine' | 'haul';
      resource: StockResource;
      /** Building id, or 0 for the landed Vessel. */
      from: number;
      to: number;
      amount: number;
      loaded: boolean;
    };

export interface Robot {
  id: number;
  type: RobotType;
  cell: number;
  /** Cells still to walk, next first. */
  path: number[];
  /** Fraction of the way into path[0]. */
  edge: number;
  job: Job | null;
  carrying: number;
}

export interface Colony {
  /** Terrain and nodes are pure functions of this. */
  seed: number;
  size: number;
  priorities: Record<JobCategory, number>;
  /** Robot counts the Fabricator builds up to. */
  quotas: Record<RobotType, number>;
  nodes: ColonyNode[];
  buildings: Building[];
  robots: Robot[];
  /** 1 where the map has been surveyed, row-major. */
  revealed: number[];
  /** Building ids in the order the player queued them; built ones drop out. */
  queue: number[];
  robotBuild: { type: RobotType; remainingHours: number } | null;
  nextId: number;
  power: { supply: number; demand: number };
  /** Lifetime output, and output per game hour over the last step. */
  made: Partial<Record<StockResource, number>>;
  rates: Partial<Record<StockResource, number>>;
  fabricatorOnline: boolean;
}
