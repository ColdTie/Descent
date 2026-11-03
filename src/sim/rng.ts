/**
 * Deterministic PRNG (mulberry32). Every bit of sim randomness goes through here.
 * The galaxy carries one named stream per concern; each stream's cursor is plain state
 * so a save and load lands on exactly the next number.
 */
export interface Rng {
  /** Uniform float in [0, 1). */
  next(): number;
  /** Uniform integer in [0, maxExclusive). */
  int(maxExclusive: number): number;
  /** Uniform float in [min, max). */
  range(min: number, max: number): number;
  /** Current cursor; feed it back to createRng to resume the sequence. */
  state(): number;
}

function mulberry32(s: number): number {
  s = (s + 0x6d2b79f5) >>> 0;
  let t = s;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

export function createRng(seed: number): Rng {
  let s = seed >>> 0;
  const next = (): number => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    int: (maxExclusive) => Math.floor(next() * maxExclusive),
    range: (min, max) => min + next() * (max - min),
    state: () => s,
  };
}

/** FNV-1a over a string, for deriving stream seeds from names. */
export function hashString(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

export const STREAM_NAMES = ['galaxy', 'worlds', 'events'] as const;
export type StreamName = (typeof STREAM_NAMES)[number];
export type RngStates = Record<StreamName, number>;

export function initialRngStates(seed: number): RngStates {
  const states = {} as RngStates;
  for (const name of STREAM_NAMES) states[name] = (seed ^ hashString(name)) >>> 0;
  return states;
}

/**
 * An Rng that draws from, and writes its cursor back to, `states[name]`.
 * Pass the galaxy's `rng` object so every draw is captured by the next save.
 */
export function streamRng(states: RngStates, name: StreamName): Rng {
  const next = (): number => {
    const s = (states[name] + 0x6d2b79f5) >>> 0;
    states[name] = s;
    return mulberry32(s - 0x6d2b79f5);
  };
  return {
    next,
    int: (maxExclusive) => Math.floor(next() * maxExclusive),
    range: (min, max) => min + next() * (max - min),
    state: () => states[name],
  };
}
