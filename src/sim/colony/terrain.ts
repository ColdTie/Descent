import { WORLD_SIZE } from '../../content/colony';
import { createRng, hashString } from '../rng';

export interface Terrain {
  size: number;
  /** Height 0 to 1 per cell, row-major. */
  height: Float32Array;
  /** Cells robots cannot enter (ridges). */
  blocked: Uint8Array;
}

export const BLOCKED_ABOVE = 0.8;
/** Steps steeper than this between neighbours are impassable. */
export const MAX_STEP = 0.12;

const cache = new Map<number, Terrain>();

export function worldSeed(galaxySeed: number, starId: number, bodyId: number): number {
  return (galaxySeed ^ hashString(`world:${starId}:${bodyId}`)) >>> 0;
}

export const cellIndex = (size: number, x: number, y: number): number => y * size + x;
export const cellX = (size: number, i: number): number => i % size;
export const cellY = (size: number, i: number): number => Math.floor(i / size);

/**
 * Value-noise heightmap, three octaves, with a flattened landing pad at the centre.
 * A pure function of the seed, so it is never saved: every view and the pathfinder rebuild it.
 */
export function terrainFor(seed: number, size = WORLD_SIZE): Terrain {
  const key = (seed ^ size) >>> 0;
  const hit = cache.get(key);
  if (hit) return hit;
  const rng = createRng(seed);
  const height = new Float32Array(size * size);
  const octaves = [
    { cells: 4, amp: 0.6 },
    { cells: 8, amp: 0.28 },
    { cells: 16, amp: 0.12 },
  ];
  for (const o of octaves) {
    const g = o.cells + 1;
    const lattice = Array.from({ length: g * g }, () => rng.next());
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const fx = (x / (size - 1)) * o.cells;
        const fy = (y / (size - 1)) * o.cells;
        const x0 = Math.min(o.cells - 1, Math.floor(fx));
        const y0 = Math.min(o.cells - 1, Math.floor(fy));
        const tx = fx - x0;
        const ty = fy - y0;
        const sx = tx * tx * (3 - 2 * tx);
        const sy = ty * ty * (3 - 2 * ty);
        const a = lattice[y0 * g + x0]!;
        const b = lattice[y0 * g + x0 + 1]!;
        const c = lattice[(y0 + 1) * g + x0]!;
        const d = lattice[(y0 + 1) * g + x0 + 1]!;
        height[y * size + x]! += o.amp * (a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy);
      }
    }
  }
  // Landing pad: blend the centre towards a mid height so the Vessel always sits on open ground.
  const c = (size - 1) / 2;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const d = Math.hypot(x - c, y - c);
      if (d < 6) {
        const w = d < 3 ? 1 : (6 - d) / 3;
        height[y * size + x] = height[y * size + x]! * (1 - w) + 0.4 * w;
      }
    }
  }
  const blocked = new Uint8Array(size * size);
  for (let i = 0; i < blocked.length; i++) blocked[i] = height[i]! > BLOCKED_ABOVE ? 1 : 0;
  const t = { size, height, blocked };
  cache.set(key, t);
  return t;
}

export function centerCell(size: number): number {
  const c = Math.floor(size / 2);
  return cellIndex(size, c, c);
}
