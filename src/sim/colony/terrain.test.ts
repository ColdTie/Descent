import { describe, expect, it } from 'vitest';
import { findPath, reachable } from './path';
import { centerCell, terrainFor } from './terrain';

describe('terrain', () => {
  it('is deterministic, in range, and flat at the landing pad', () => {
    const a = terrainFor(42);
    const b = terrainFor(42, a.size);
    expect(Array.from(a.height)).toEqual(Array.from(b.height));
    for (const h of a.height) {
      expect(h).toBeGreaterThanOrEqual(0);
      expect(h).toBeLessThanOrEqual(1.01);
    }
    expect(a.blocked[centerCell(a.size)]).toBe(0);
  });

  it('leaves most of the map reachable from the pad for many seeds', () => {
    for (let s = 1; s <= 30; s++) {
      const t = terrainFor(s * 977);
      const r = reachable(t, centerCell(t.size));
      const count = r.reduce((n, v) => n + v, 0);
      expect(count, `seed ${s}`).toBeGreaterThan(t.size * t.size * 0.3);
    }
  });
});

describe('A*', () => {
  it('finds a path to a reachable cell and none into a ridge', () => {
    const t = terrainFor(7);
    const r = reachable(t, centerCell(t.size));
    const target = Array.from(r).lastIndexOf(1);
    const p = findPath(t, centerCell(t.size), target)!;
    expect(p.at(-1)).toBe(target);
    for (const c of p) expect(t.blocked[c]).toBe(0);
    const ridge = Array.from(t.blocked).indexOf(1);
    if (ridge >= 0) expect(findPath(t, centerCell(t.size), ridge)).toBeNull();
    expect(findPath(t, 5, 5)).toEqual([]);
  });
});
