import type { GalaxyState, Vessel } from './state';

export interface LineageNode {
  vessel: Vessel;
  depth: number;
  children: LineageNode[];
}

/** Root Vessels first, copies nested under their parent, siblings by id. A Vessel whose parent is missing is treated as a root. */
export function lineageTree(state: GalaxyState): LineageNode[] {
  const vessels = Object.values(state.vessels).sort((a, b) => a.id - b.id);
  const nodes = new Map<number, LineageNode>();
  for (const v of vessels) nodes.set(v.id, { vessel: v, depth: 0, children: [] });
  const roots: LineageNode[] = [];
  for (const v of vessels) {
    const node = nodes.get(v.id)!;
    const parent = v.parentId === null ? undefined : nodes.get(v.parentId);
    if (parent && parent !== node) parent.children.push(node);
    else roots.push(node);
  }
  const setDepth = (node: LineageNode, depth: number): void => {
    node.depth = depth;
    for (const c of node.children) setDepth(c, depth + 1);
  };
  for (const r of roots) setDepth(r, 0);
  return roots;
}

/** Depth-first flattening for list rendering. */
export function flattenLineage(roots: LineageNode[]): LineageNode[] {
  const out: LineageNode[] = [];
  const walk = (n: LineageNode): void => {
    out.push(n);
    for (const c of n.children) walk(c);
  };
  for (const r of roots) walk(r);
  return out;
}

export function alertCountFor(state: GalaxyState, vesselId: number): number {
  let n = 0;
  for (const a of state.alerts) if (a.vesselId === vesselId) n++;
  return n;
}
