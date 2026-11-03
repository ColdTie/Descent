import { describe, expect, it } from 'vitest';
import { alertCountFor, flattenLineage, lineageTree } from './lineage';
import { createGalaxy, freshStock, freshSystems, type Vessel } from './state';

function copy(id: number, parentId: number | null): Vessel {
  return { id, name: `Vessel ${id}`, parentId, phase: 'planetside', starId: 0, transit: null, survey: null, worldId: null, systems: freshSystems(), stock: freshStock(), log: [] };
}

describe('lineage', () => {
  it('nests copies under their parent and flattens depth-first', () => {
    const g = createGalaxy(1);
    g.vessels[2] = copy(2, 1);
    g.vessels[3] = copy(3, 1);
    g.vessels[4] = copy(4, 2);
    const roots = lineageTree(g);
    expect(roots.map((r) => r.vessel.id)).toEqual([1]);
    expect(roots[0]!.children.map((c) => c.vessel.id)).toEqual([2, 3]);
    expect(flattenLineage(roots).map((n) => `${n.depth}:${n.vessel.id}`)).toEqual(['0:1', '1:2', '2:4', '1:3']);
  });

  it('treats a Vessel with a missing parent as a root', () => {
    const g = createGalaxy(1);
    g.vessels[9] = copy(9, 42);
    expect(lineageTree(g).map((r) => r.vessel.id)).toEqual([1, 9]);
  });

  it('counts alerts per Vessel', () => {
    const g = createGalaxy(1);
    g.alerts.push({ id: 1, vesselId: 1, time: 0, level: 'info', text: 'a' }, { id: 2, vesselId: 7, time: 0, level: 'info', text: 'b' });
    expect(alertCountFor(g, 1)).toBe(1);
    expect(alertCountFor(g, 7)).toBe(1);
    expect(alertCountFor(g, 3)).toBe(0);
  });
});
