export const BODY_KINDS = ['molten', 'rocky', 'icy', 'gasGiant'] as const;
export type BodyKind = (typeof BODY_KINDS)[number];

export const HAZARDS = ['none', 'heat', 'quakes', 'radiation', 'storms', 'cold'] as const;
export type Hazard = (typeof HAZARDS)[number];

export interface BodyKindDef {
  name: string;
  landable: boolean;
  /** Ranges the profile is drawn from. */
  ore: readonly [number, number];
  ice: readonly [number, number];
  gravity: readonly [number, number];
  hazards: readonly Hazard[];
}

export const BODY_DEFS: Record<BodyKind, BodyKindDef> = {
  molten: { name: 'Molten world', landable: true, ore: [0.5, 1], ice: [0, 0.05], gravity: [0.4, 1.2], hazards: ['heat', 'quakes'] },
  rocky: { name: 'Rocky world', landable: true, ore: [0.3, 0.9], ice: [0, 0.4], gravity: [0.2, 1.4], hazards: ['none', 'none', 'quakes', 'radiation', 'storms'] },
  icy: { name: 'Ice world', landable: true, ore: [0.05, 0.4], ice: [0.5, 1], gravity: [0.05, 0.8], hazards: ['none', 'cold', 'cold', 'storms'] },
  gasGiant: { name: 'Gas giant', landable: false, ore: [0, 0], ice: [0, 0], gravity: [1.5, 3], hazards: ['storms', 'radiation'] },
};

export const HAZARD_NAMES: Record<Hazard, string> = {
  none: 'none',
  heat: 'surface heat',
  quakes: 'quakes',
  radiation: 'radiation',
  storms: 'storms',
  cold: 'deep cold',
};

export const BODY_COUNT_MIN = 2;
export const BODY_COUNT_MAX = 6;
/** Game days to survey one body with healthy sensors; weak sensors take twice as long. */
export const SURVEY_DAYS = 30;
export const WEAK_SENSORS_SURVEY_MULT = 2;
/** Fuel for the landing burn; each unit short costs this much Hull. */
export const LANDING_FUEL = 10;
export const LANDING_HULL_PER_FUEL_SHORT = 3;
