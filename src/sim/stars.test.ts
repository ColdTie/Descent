import { describe, expect, it } from 'vitest';
import { HOP_MAX_LY, HOP_MIN_LY, STAR_COUNT_MAX, STAR_COUNT_MIN, STAR_MAP_RADIUS_LY } from '../content/stars';
import { createRng } from './rng';
import { distanceLy, generateStars, pickHopTarget } from './stars';

describe('star map', () => {
  it('makes 30 to 60 stars inside 50 ly with home at the origin, for many seeds', () => {
    for (let seed = 1; seed <= 40; seed++) {
      const stars = generateStars(createRng(seed));
      expect(stars.length).toBeGreaterThanOrEqual(STAR_COUNT_MIN);
      expect(stars.length).toBeLessThanOrEqual(STAR_COUNT_MAX);
      expect(stars[0]).toMatchObject({ id: 0, x: 0, y: 0, z: 0 });
      for (const s of stars) expect(Math.hypot(s.x, s.y, s.z)).toBeLessThanOrEqual(STAR_MAP_RADIUS_LY);
      expect(new Set(stars.map((s) => s.id)).size).toBe(stars.length);
    }
  });

  it('is deterministic for a seed', () => {
    expect(generateStars(createRng(5))).toEqual(generateStars(createRng(5)));
  });

  it('picks the nearest hop inside 5 to 15 ly when one exists', () => {
    for (let seed = 1; seed <= 40; seed++) {
      const stars = generateStars(createRng(seed));
      const target = pickHopTarget(stars, 0);
      expect(target).not.toBeNull();
      const d = distanceLy(stars[0]!, target!);
      const inBand = stars.filter((s) => s.id !== 0).map((s) => distanceLy(stars[0]!, s)).filter((x) => x >= HOP_MIN_LY && x <= HOP_MAX_LY);
      if (inBand.length > 0) expect(d).toBeCloseTo(Math.min(...inBand), 10);
    }
  });

  it('returns null for an unknown origin', () => {
    expect(pickHopTarget(generateStars(createRng(1)), 999)).toBeNull();
  });
});
