import {
  HOP_MAX_LY,
  HOP_MIN_LY,
  SPECTRAL_CLASSES,
  SPECTRAL_WEIGHTS,
  STAR_COUNT_MAX,
  STAR_COUNT_MIN,
  STAR_MAP_RADIUS_LY,
  type SpectralClass,
} from '../content/stars';
import type { Rng } from './rng';

export interface Star {
  id: number;
  /** Placeholder names until LORE.md says otherwise. */
  name: string;
  x: number;
  y: number;
  z: number;
  spectral: SpectralClass;
}

function pickSpectral(rng: Rng): SpectralClass {
  const total = SPECTRAL_CLASSES.reduce((sum, c) => sum + SPECTRAL_WEIGHTS[c], 0);
  let roll = rng.next() * total;
  for (const c of SPECTRAL_CLASSES) {
    roll -= SPECTRAL_WEIGHTS[c];
    if (roll < 0) return c;
  }
  return 'M';
}

const MIN_SEPARATION_LY = 2;

/**
 * 30 to 60 stars inside a 50 ly sphere, grown as a chain: each new star sits 5 to 15 ly from a
 * star already placed, so every star has a hop-length neighbour and the map is connected.
 * Star 0 is home at the origin.
 */
export function generateStars(rng: Rng): Star[] {
  const count = STAR_COUNT_MIN + rng.int(STAR_COUNT_MAX - STAR_COUNT_MIN + 1);
  const stars: Star[] = [{ id: 0, name: 'Home', x: 0, y: 0, z: 0, spectral: 'G' }];
  while (stars.length < count) {
    const anchor = stars[rng.int(stars.length)]!;
    let placed: Star | null = null;
    for (let attempt = 0; attempt < 24 && !placed; attempt++) {
      const d = rng.range(HOP_MIN_LY, HOP_MAX_LY);
      const z = rng.range(-1, 1);
      const theta = rng.range(0, Math.PI * 2);
      const s = Math.sqrt(1 - z * z);
      const candidate: Star = {
        id: stars.length,
        name: `Star ${stars.length}`,
        x: anchor.x + d * s * Math.cos(theta),
        y: anchor.y + d * s * Math.sin(theta),
        z: anchor.z + d * z,
        spectral: 'M',
      };
      if (Math.hypot(candidate.x, candidate.y, candidate.z) > STAR_MAP_RADIUS_LY) continue;
      if (stars.some((o) => distanceLy(o, candidate) < MIN_SEPARATION_LY)) continue;
      placed = candidate;
    }
    if (!placed) continue;
    placed.spectral = pickSpectral(rng);
    stars.push(placed);
  }
  return stars;
}

export function distanceLy(a: Star, b: Star): number {
  return Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
}

/** Nearest star 5 to 15 ly away; if none, the nearest star at all. Null only when the map has one star. */
export function pickHopTarget(stars: readonly Star[], fromId: number): Star | null {
  const from = stars.find((s) => s.id === fromId);
  if (!from) return null;
  let best: Star | null = null;
  let bestD = Infinity;
  let nearest: Star | null = null;
  let nearestD = Infinity;
  for (const s of stars) {
    if (s.id === fromId) continue;
    const d = distanceLy(from, s);
    if (d < nearestD) {
      nearest = s;
      nearestD = d;
    }
    if (d >= HOP_MIN_LY && d <= HOP_MAX_LY && d < bestD) {
      best = s;
      bestD = d;
    }
  }
  return best ?? nearest;
}
