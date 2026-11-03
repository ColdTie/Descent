import { BUILDING_DEFS, type StockResource } from '../content/colony';
import { RESOURCE_NAMES } from '../content/resources';
import type { Building, Colony } from '../sim/colony/types';
import type { Vessel } from '../sim/state';

/** "2 Parts · 30 Metal" */
export function costText(cost: Partial<Record<StockResource, number>>): string {
  const parts = Object.entries(cost).map(([r, n]) => `${n} ${RESOURCE_NAMES[r as StockResource]}`);
  return parts.length ? parts.join(' · ') : 'free';
}

/** What a queued building is waiting on, in the player's words. */
export function queueState(c: Colony, stock: Vessel['stock'], b: Building): string {
  const def = BUILDING_DEFS[b.type];
  if (b.cell < 0) return def.node ? `needs a surveyed ${def.node} node` : 'needs open surveyed ground';
  if (!b.paid) {
    const short = Object.entries(def.cost)
      .filter(([r, n]) => stock[r as StockResource] < (n ?? 0))
      .map(([r, n]) => `${Math.ceil((n ?? 0) - stock[r as StockResource])} ${RESOURCE_NAMES[r as StockResource]}`);
    return short.length ? `needs ${short.join(', ')}` : b.auto ? 'waiting: your queue comes first' : 'starting';
  }
  const builders = c.robots.filter((r) => r.job?.kind === 'build' && r.job.buildingId === b.id).length;
  const pct = `${Math.round(b.progress * 100)}%`;
  return builders ? `building ${pct} · ${builders} builder${builders > 1 ? 's' : ''}` : b.progress > 0 ? `paused at ${pct}` : 'waiting for a builder';
}

/** "+3.2/h" or "" */
export function rateText(rate: number | undefined): string {
  if (!rate || Math.abs(rate) < 0.05) return '';
  return `${rate > 0 ? '+' : ''}${rate.toFixed(1)}/h`;
}
