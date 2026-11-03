import { cellIndex, cellX, cellY, MAX_STEP, type Terrain } from './terrain';

const NEIGHBOURS: ReadonlyArray<readonly [number, number, number]> = [
  [1, 0, 1],
  [-1, 0, 1],
  [0, 1, 1],
  [0, -1, 1],
  [1, 1, Math.SQRT2],
  [1, -1, Math.SQRT2],
  [-1, 1, Math.SQRT2],
  [-1, -1, Math.SQRT2],
];

/** Cost to move from cell a to its neighbour b, or Infinity when the step is a cliff or a ridge. */
export function edgeCost(t: Terrain, a: number, b: number, base: number): number {
  if (t.blocked[b]) return Infinity;
  const dh = Math.abs(t.height[b]! - t.height[a]!);
  if (dh > MAX_STEP) return Infinity;
  return base * (1 + dh * 8);
}

/** A* over the grid. Returns the cells after `from` up to and including `to`, or null when unreachable. */
export function findPath(t: Terrain, from: number, to: number): number[] | null {
  if (from === to) return [];
  if (t.blocked[to]) return null;
  const n = t.size * t.size;
  const g = new Float64Array(n).fill(Infinity);
  const came = new Int32Array(n).fill(-1);
  const closed = new Uint8Array(n);
  const tx = cellX(t.size, to);
  const ty = cellY(t.size, to);
  const h = (i: number): number => {
    const dx = Math.abs(cellX(t.size, i) - tx);
    const dy = Math.abs(cellY(t.size, i) - ty);
    return Math.max(dx, dy) + (Math.SQRT2 - 1) * Math.min(dx, dy);
  };
  // Small binary heap keyed on f = g + h; ties broken by cell index for determinism.
  const heap: number[] = [];
  const f = new Float64Array(n).fill(Infinity);
  const less = (a: number, b: number): boolean => f[a]! < f[b]! || (f[a] === f[b] && a < b);
  const push = (i: number): void => {
    heap.push(i);
    let k = heap.length - 1;
    while (k > 0) {
      const p = (k - 1) >> 1;
      if (!less(heap[k]!, heap[p]!)) break;
      [heap[k], heap[p]] = [heap[p]!, heap[k]!];
      k = p;
    }
  };
  const pop = (): number => {
    const top = heap[0]!;
    const last = heap.pop()!;
    if (heap.length) {
      heap[0] = last;
      let k = 0;
      for (;;) {
        const l = 2 * k + 1;
        const r = l + 1;
        let m = k;
        if (l < heap.length && less(heap[l]!, heap[m]!)) m = l;
        if (r < heap.length && less(heap[r]!, heap[m]!)) m = r;
        if (m === k) break;
        [heap[k], heap[m]] = [heap[m]!, heap[k]!];
        k = m;
      }
    }
    return top;
  };
  g[from] = 0;
  f[from] = h(from);
  push(from);
  while (heap.length) {
    const cur = pop();
    if (closed[cur]) continue;
    if (cur === to) break;
    closed[cur] = 1;
    const cx = cellX(t.size, cur);
    const cy = cellY(t.size, cur);
    for (const [dx, dy, base] of NEIGHBOURS) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (nx < 0 || ny < 0 || nx >= t.size || ny >= t.size) continue;
      const nb = cellIndex(t.size, nx, ny);
      if (closed[nb]) continue;
      const cost = edgeCost(t, cur, nb, base);
      if (cost === Infinity) continue;
      const ng = g[cur]! + cost;
      if (ng < g[nb]!) {
        g[nb] = ng;
        f[nb] = ng + h(nb);
        came[nb] = cur;
        push(nb);
      }
    }
  }
  if (came[to] === -1) return null;
  const path: number[] = [];
  for (let c = to; c !== from; c = came[c]!) path.push(c);
  return path.reverse();
}

/** Cells reachable from `from`, as a mask; used to place buildings and nodes only where robots can go. */
export function reachable(t: Terrain, from: number): Uint8Array {
  const seen = new Uint8Array(t.size * t.size);
  const queue = [from];
  seen[from] = 1;
  while (queue.length) {
    const cur = queue.shift()!;
    const cx = cellX(t.size, cur);
    const cy = cellY(t.size, cur);
    for (const [dx, dy, base] of NEIGHBOURS) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (nx < 0 || ny < 0 || nx >= t.size || ny >= t.size) continue;
      const nb = cellIndex(t.size, nx, ny);
      if (seen[nb] || edgeCost(t, cur, nb, base) === Infinity) continue;
      seen[nb] = 1;
      queue.push(nb);
    }
  }
  return seen;
}
