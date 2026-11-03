import type { SystemId } from './systems';

export const EVENT_KINDS = ['micrometeoroid', 'driveFault', 'reactorFlicker', 'signal'] as const;
export type EventKind = (typeof EVENT_KINDS)[number];

/** Expected transit events per game year per Vessel. A 25 to 75 year hop sees roughly 4 to 11. */
export const EVENT_RATE_PER_YEAR = 0.15;

export interface EventEffect {
  parts?: number;
  fuel?: number;
  systems?: Partial<Record<SystemId, number>>;
  /** Give back the integrity the event took when it happened. */
  repairOccurrence?: boolean;
  /** Extra light years added to the hop. */
  distanceLy?: number;
}

export interface ChoiceDef {
  label: string;
  effect: EventEffect;
}

export interface EventDef {
  title: string;
  weight: number;
  /** Only rolled while coasting (detours mid-burn would break the burn plan). */
  coastOnly?: boolean;
  /** System the event damages when it happens, and the damage range. */
  system: SystemId | null;
  damage: readonly [number, number];
  text(damage: number): string;
  choices: ChoiceDef[];
}

export const EVENT_DEFS: Record<EventKind, EventDef> = {
  micrometeoroid: {
    title: 'Micrometeoroid strike',
    weight: 3,
    system: 'hull',
    damage: [4, 10],
    text: (d) => `Debris struck the forward lattice. Hull −${d}.`,
    choices: [
      { label: 'Patch it now', effect: { parts: -3, repairOccurrence: true } },
      { label: 'Leave it', effect: {} },
    ],
  },
  driveFault: {
    title: 'Drive fault',
    weight: 2,
    system: 'drive',
    damage: [8, 8],
    text: (d) => `A field coil in the drive failed. Drive −${d}.`,
    choices: [
      { label: 'Reroute through the backup', effect: { fuel: -5, repairOccurrence: true } },
      { label: 'Fabricate a replacement', effect: { parts: -4, repairOccurrence: true } },
      { label: 'Run on what is left', effect: { systems: { drive: -6 } } },
    ],
  },
  reactorFlicker: {
    title: 'Reactor flicker',
    weight: 2,
    system: 'power',
    damage: [6, 6],
    text: (d) => `Reactor output dipped and stayed low. Power −${d}.`,
    choices: [
      { label: 'Shed load from the sensors', effect: { systems: { sensors: -5 }, repairOccurrence: true } },
      { label: 'Repair the regulator', effect: { parts: -2, repairOccurrence: true } },
    ],
  },
  signal: {
    title: 'Signal detected',
    weight: 1,
    coastOnly: true,
    system: null,
    damage: [0, 0],
    text: () => 'Sensors picked up a faint, regular signal off the flight path.',
    choices: [
      { label: 'Log it and keep course', effect: {} },
      // What the signal is stays TBD (docs/LORE.md); the detour only salvages debris near its source.
      { label: 'Detour toward the source', effect: { fuel: -8, distanceLy: 0.5, parts: 6 } },
    ],
  },
};
