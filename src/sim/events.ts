import { EVENT_DEFS, EVENT_KINDS, EVENT_RATE_PER_YEAR, type ChoiceDef, type EventEffect, type EventKind } from '../content/events';
import { SYSTEM_IDS } from '../content/systems';
import { WEAK_SENSORS_BELOW, WEAK_SENSORS_DAMAGE_MULT } from '../content/transit';
import { streamRng } from './rng';
import { appendLog, type GalaxyState, type PendingEvent, type Vessel } from './state';
import { SECONDS_PER_YEAR } from './time';

function clampIntegrity(n: number): number {
  return Math.max(0, Math.min(100, n));
}

/** Rolls at most one event for a Vessel in transit. All draws come from the events stream, whose cursor lives in state. */
export function rollEvent(state: GalaxyState, vessel: Vessel, dtSeconds: number): PendingEvent | null {
  const rng = streamRng(state.rng, 'events');
  const years = dtSeconds / SECONDS_PER_YEAR;
  const p = 1 - Math.exp(-EVENT_RATE_PER_YEAR * years);
  const roll = rng.next();
  if (roll >= p || !vessel.transit) return null;
  const eligible = EVENT_KINDS.filter((k) => !EVENT_DEFS[k].coastOnly || vessel.transit!.burn === 'coast');
  const total = eligible.reduce((sum, k) => sum + EVENT_DEFS[k].weight, 0);
  let pick = rng.next() * total;
  let kind: EventKind = eligible[eligible.length - 1]!;
  for (const k of eligible) {
    pick -= EVENT_DEFS[k].weight;
    if (pick < 0) {
      kind = k;
      break;
    }
  }
  const def = EVENT_DEFS[kind];
  let damage = 0;
  if (def.system) {
    const [lo, hi] = def.damage;
    damage = Math.round(rng.range(lo, hi));
    if (kind === 'micrometeoroid' && vessel.systems.sensors.integrity < WEAK_SENSORS_BELOW) damage = Math.round(damage * WEAK_SENSORS_DAMAGE_MULT);
    const sys = vessel.systems[def.system];
    const before = sys.integrity;
    sys.integrity = clampIntegrity(sys.integrity - damage);
    damage = before - sys.integrity;
  }
  const event: PendingEvent = { id: state.nextEventId++, vesselId: vessel.id, kind, time: state.time, damage: Math.round(damage * 100) / 100 };
  state.events.push(event);
  appendLog(vessel, state.time, `${def.title}. ${def.text(Math.round(damage))}`);
  return event;
}

export function choicesFor(event: PendingEvent): ChoiceDef[] {
  return EVENT_DEFS[event.kind].choices;
}

/** Why a choice cannot be taken right now, or '' when it can. */
export function choiceBlocker(vessel: Vessel, effect: EventEffect): string {
  if (effect.parts && effect.parts < 0 && vessel.stock.parts < -effect.parts) return `needs ${-effect.parts} Parts`;
  if (effect.fuel && effect.fuel < 0 && vessel.stock.fuel < -effect.fuel) return `needs ${-effect.fuel} Fuel`;
  return '';
}

/** Short cost and outcome text for a choice, e.g. "−3 Parts · Hull +7". */
export function describeEffect(event: PendingEvent, effect: EventEffect): string {
  const parts: string[] = [];
  const sign = (n: number): string => (n > 0 ? `+${n}` : `−${-n}`);
  if (effect.parts) parts.push(`${sign(effect.parts)} Parts`);
  if (effect.fuel) parts.push(`${sign(effect.fuel)} Fuel`);
  const def = EVENT_DEFS[event.kind];
  if (effect.repairOccurrence && def.system && event.damage > 0) parts.push(`${capital(def.system)} +${Math.round(event.damage)}`);
  for (const id of SYSTEM_IDS) {
    const n = effect.systems?.[id];
    if (n) parts.push(`${capital(id)} ${sign(n)}`);
  }
  if (effect.distanceLy) parts.push(`+${effect.distanceLy} ly`);
  return parts.length ? parts.join(' · ') : 'no cost';
}

function capital(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** Applies a choice to its Vessel. Assumes the caller checked choiceBlocker. */
export function applyChoice(state: GalaxyState, vessel: Vessel, event: PendingEvent, choice: ChoiceDef): void {
  const e = choice.effect;
  if (e.parts) vessel.stock.parts = Math.max(0, vessel.stock.parts + e.parts);
  if (e.fuel) vessel.stock.fuel = Math.max(0, vessel.stock.fuel + e.fuel);
  const def = EVENT_DEFS[event.kind];
  if (e.repairOccurrence && def.system) {
    const sys = vessel.systems[def.system];
    sys.integrity = clampIntegrity(sys.integrity + event.damage);
  }
  for (const id of SYSTEM_IDS) {
    const n = e.systems?.[id];
    if (n) vessel.systems[id].integrity = clampIntegrity(vessel.systems[id].integrity + n);
  }
  if (e.distanceLy && vessel.transit) vessel.transit.distanceLy += e.distanceLy;
  appendLog(vessel, state.time, `${def.title}: ${choice.label.toLowerCase()} (${describeEffect(event, e)}).`);
}
