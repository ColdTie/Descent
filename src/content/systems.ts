/** The five Vessel systems and their baseline wear. Rates are per game hour (CLAUDE.md rule 4). */
export const SYSTEM_IDS = ['power', 'drive', 'hull', 'fabricator', 'sensors'] as const;
export type SystemId = (typeof SYSTEM_IDS)[number];

export interface SystemDef {
  name: string;
  /** Integrity points lost per game hour while the Vessel is in transit. */
  wearPerHour: number;
}

// Tuned so a 30 game-year hop costs each system roughly 25 to 50 points before repairs.
export const SYSTEM_DEFS: Record<SystemId, SystemDef> = {
  power: { name: 'Power', wearPerHour: 0.00012 },
  drive: { name: 'Drive', wearPerHour: 0.0002 },
  hull: { name: 'Hull', wearPerHour: 0.0001 },
  fabricator: { name: 'Fabricator', wearPerHour: 0.00008 },
  sensors: { name: 'Sensors', wearPerHour: 0.00015 },
};

/** Integrity thresholds that raise an alert the first time a system drops below them. */
export const SYSTEM_ALERT_THRESHOLDS = [50, 25, 10] as const;
