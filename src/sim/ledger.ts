import { SYSTEM_ALERT_THRESHOLDS, SYSTEM_DEFS, SYSTEM_IDS } from '../content/systems';
import {
  ACCEL_C_PER_YEAR,
  BURN_FUEL_PER_YEAR,
  DRY_DECEL_HULL_PER_YEAR,
  MIN_SPEED_C,
  POWER_OUT_WEAR_MULT,
  WEAK_DRIVE_BELOW,
  WEAK_DRIVE_FUEL_MULT,
  WEAK_SENSORS_BELOW,
} from '../content/transit';
import { BODY_DEFS, WEAK_SENSORS_SURVEY_MULT } from '../content/bodies';
import { rollEvent } from './events';
import { streamRng } from './rng';
import { generateSystem, type StarSystem } from './system';
import { appendLog, starById, type Alert, type Burn, type GalaxyState, type PendingEvent, type Vessel } from './state';
import { SECONDS_PER_DAY, SECONDS_PER_HOUR, SECONDS_PER_YEAR } from './time';

export interface StepReport {
  /** Alerts raised during this step, already appended to state.alerts. */
  alerts: Alert[];
  /** Events opened during this step, already appended to state.events. */
  events: PendingEvent[];
  /** False when the step did not run because an event is waiting for a choice. */
  ran: boolean;
}

export interface StepOptions {
  /** Roll transit events. Tests switch this off to isolate kinematics and wear. */
  events?: boolean;
}

function raiseAlert(state: GalaxyState, vessel: Vessel, level: Alert['level'], text: string, report: StepReport): void {
  const alert: Alert = { id: state.nextAlertId++, vesselId: vessel.id, time: state.time, level, text };
  state.alerts.push(alert);
  appendLog(vessel, state.time, text);
  report.alerts.push(alert);
}

/** Alert level for a crossed threshold; matches the gauge colours (amber below 50, red below 25). */
export function alertLevelFor(threshold: number): Alert['level'] {
  return threshold <= 25 ? 'critical' : 'warn';
}

/** Raises each threshold once per crossing; a threshold re-arms when integrity climbs back to it. */
function checkThresholds(state: GalaxyState, vessel: Vessel, report: StepReport): void {
  for (const id of SYSTEM_IDS) {
    const sys = vessel.systems[id];
    sys.alerted = sys.alerted.filter((t) => sys.integrity < t);
    for (const threshold of SYSTEM_ALERT_THRESHOLDS) {
      if (sys.integrity < threshold && !sys.alerted.includes(threshold)) {
        sys.alerted.push(threshold);
        raiseAlert(state, vessel, alertLevelFor(threshold), `${SYSTEM_DEFS[id].name} integrity below ${threshold}.`, report);
      }
    }
  }
}

function wear(vessel: Vessel, hours: number): void {
  const powerOut = vessel.systems.power.integrity <= 0;
  for (const id of SYSTEM_IDS) {
    const sys = vessel.systems[id];
    const mult = powerOut && id !== 'power' ? POWER_OUT_WEAR_MULT : 1;
    sys.integrity = Math.max(0, sys.integrity - SYSTEM_DEFS[id].wearPerHour * hours * mult);
  }
}

function setBurn(state: GalaxyState, vessel: Vessel, burn: Burn, text: string): void {
  vessel.transit!.burn = burn;
  appendLog(vessel, state.time, text);
}

/** Braking for `years`: slows the Vessel, pays Fuel, and charges Hull for any part of the burn run dry. */
function brake(state: GalaxyState, vessel: Vessel, years: number, report: StepReport): void {
  const t = vessel.transit!;
  const driveOk = vessel.systems.drive.integrity > 0;
  const want = burnRate(vessel) * years;
  const used = driveOk ? Math.min(vessel.stock.fuel, want) : 0;
  vessel.stock.fuel = Math.max(0, vessel.stock.fuel - used);
  const dryFrac = want > 0 ? 1 - used / want : 0;
  if (dryFrac > 0) {
    const hull = vessel.systems.hull;
    hull.integrity = Math.max(0, hull.integrity - DRY_DECEL_HULL_PER_YEAR * years * dryFrac);
    if (!t.dryBurn) {
      t.dryBurn = true;
      raiseAlert(state, vessel, 'critical', driveOk ? 'Out of fuel mid-braking. The hull takes the rest.' : 'Drive offline mid-braking. The hull takes the rest.', report);
    }
  }
  const v0 = t.speedC;
  t.speedC = Math.max(MIN_SPEED_C, v0 - ACCEL_C_PER_YEAR * years);
  t.traveledLy += ((v0 + t.speedC) / 2) * years;
}

function burnRate(vessel: Vessel): number {
  return BURN_FUEL_PER_YEAR * (vessel.systems.drive.integrity < WEAK_DRIVE_BELOW ? WEAK_DRIVE_FUEL_MULT : 1);
}

/**
 * Accelerate, coast, decelerate. Fuel pays for both burns; braking without fuel or drive costs hull.
 * A coasting step that reaches the stopping point is split there, so braking starts at the same
 * place whatever the step length (CLAUDE.md rule 4).
 */
function move(state: GalaxyState, vessel: Vessel, years: number, report: StepReport): void {
  const t = vessel.transit!;
  const a = ACCEL_C_PER_YEAR;
  const v0 = t.speedC;

  if (t.burn === 'accel') {
    const want = burnRate(vessel) * years;
    if (vessel.systems.drive.integrity <= 0 || vessel.stock.fuel <= 0) {
      setBurn(state, vessel, 'coast', `Launch burn cut short at ${t.speedC.toFixed(3)}c.`);
    } else {
      const used = Math.min(vessel.stock.fuel, want);
      vessel.stock.fuel = Math.max(0, vessel.stock.fuel - used);
      t.speedC = Math.min(t.cruiseC, v0 + a * years * (want > 0 ? used / want : 1));
      t.traveledLy += ((v0 + t.speedC) / 2) * years;
      if (t.speedC >= t.cruiseC) setBurn(state, vessel, 'coast', `Cruise reached, ${t.cruiseC.toFixed(2)}c. Coasting.`);
    }
  } else if (t.burn === 'coast') {
    const stopping = (v0 * v0) / (2 * a);
    const toBrake = v0 > 0 ? Math.max(0, (t.distanceLy - t.traveledLy - stopping) / v0) : Infinity;
    if (toBrake >= years) {
      t.traveledLy += v0 * years;
    } else {
      t.traveledLy += v0 * toBrake;
      setBurn(state, vessel, 'decel', 'Deceleration burn started.');
      brake(state, vessel, years - toBrake, report);
    }
  } else {
    brake(state, vessel, years, report);
  }
}

/** The system around a star, generating it from the worlds stream the first time anyone needs it. */
export function ensureSystem(state: GalaxyState, starId: number): StarSystem | null {
  const existing = state.starSystems[starId];
  if (existing) return existing;
  const star = starById(state, starId);
  if (!star) return null;
  const system = generateSystem(streamRng(state.rng, 'worlds'), star);
  state.starSystems[starId] = system;
  return system;
}

function arrive(state: GalaxyState, vessel: Vessel, report: StepReport): void {
  const t = vessel.transit!;
  const star = starById(state, t.toStarId);
  vessel.phase = 'arrival';
  vessel.starId = t.toStarId;
  vessel.transit = null;
  const system = ensureSystem(state, t.toStarId);
  const n = system?.bodies.length ?? 0;
  raiseAlert(state, vessel, 'info', `Arrived at ${star?.name ?? `Star ${t.toStarId}`}. ${n} bodies in the system; survey one to land.`, report);
}

/** Survey time scales with sensors: weak sensors take twice as long. */
export function surveySeconds(vessel: Vessel, baseDays: number): number {
  return baseDays * SECONDS_PER_DAY * (vessel.systems.sensors.integrity < WEAK_SENSORS_BELOW ? WEAK_SENSORS_SURVEY_MULT : 1);
}

function stepOrbit(state: GalaxyState, vessel: Vessel, dtSeconds: number, report: StepReport): void {
  if (vessel.starId === null) return;
  // Saves from before Phase 4 can hold a Vessel already in orbit with no system yet.
  ensureSystem(state, vessel.starId);
  const s = vessel.survey;
  if (!s) return;
  s.remainingSeconds = Math.max(0, s.remainingSeconds - dtSeconds);
  if (s.remainingSeconds > 0) return;
  vessel.survey = null;
  const body = state.starSystems[vessel.starId]?.bodies[s.bodyId];
  if (!body) return;
  body.surveyed = true;
  const def = BODY_DEFS[body.kind];
  raiseAlert(state, vessel, 'info', `Survey of ${body.name} complete: ${def.name.toLowerCase()}${def.landable ? '' : ', no landing'}.`, report);
}

function stepTransit(state: GalaxyState, vessel: Vessel, dtSeconds: number, report: StepReport, opts: StepOptions): void {
  if (!vessel.transit) return;
  // Rates are per game hour and integrate linearly inside a step (CLAUDE.md rule 4).
  wear(vessel, dtSeconds / SECONDS_PER_HOUR);
  move(state, vessel, dtSeconds / SECONDS_PER_YEAR, report);
  if (vessel.systems.hull.integrity <= 0) {
    vessel.phase = 'lost';
    raiseAlert(state, vessel, 'critical', 'Lost: the hull failed.', report);
    return;
  }
  if (vessel.transit.traveledLy >= vessel.transit.distanceLy) {
    vessel.transit.traveledLy = vessel.transit.distanceLy;
    checkThresholds(state, vessel, report);
    arrive(state, vessel, report);
    return;
  }
  if (opts.events !== false && !state.events.some((e) => e.vesselId === vessel.id)) {
    const event = rollEvent(state, vessel, dtSeconds);
    if (event) report.events.push(event);
  }
  checkThresholds(state, vessel, report);
}

/**
 * Advances every Vessel and world by one fixed step. The ledger is the truth: this runs for
 * unfocused Vessels too. While any event waits for a choice, the galaxy holds still.
 * Any alert or event drops warp to 1x (DESIGN.md, Time).
 */
export function stepLedger(state: GalaxyState, dtSeconds: number, opts: StepOptions = {}): StepReport {
  const report: StepReport = { alerts: [], events: [], ran: false };
  if (state.events.length > 0) return report;
  report.ran = true;
  for (const vessel of Object.values(state.vessels)) {
    if (vessel.phase === 'transit') stepTransit(state, vessel, dtSeconds, report, opts);
    else if (vessel.phase === 'arrival') stepOrbit(state, vessel, dtSeconds, report);
  }
  state.time += dtSeconds;
  if (report.alerts.length > 0 || report.events.length > 0) state.warp = 1;
  return report;
}

/** Game seconds left on a transit, assuming the burn plan completes. Infinity when not moving and not burning. */
export function transitEtaSeconds(vessel: Vessel): number {
  const t = vessel.transit;
  if (!t) return Infinity;
  const a = ACCEL_C_PER_YEAR;
  let v = t.speedC;
  let remaining = Math.max(0, t.distanceLy - t.traveledLy);
  let years = 0;
  if (t.burn === 'accel') {
    const ta = Math.max(0, (t.cruiseC - v) / a);
    years += ta;
    remaining -= ((v + t.cruiseC) / 2) * ta;
    v = t.cruiseC;
  }
  if (v <= 0) return Infinity;
  if (t.burn !== 'decel') {
    const stopping = (v * v) / (2 * a);
    years += Math.max(0, remaining - stopping) / v;
    remaining = Math.min(Math.max(0, remaining), stopping);
  }
  // Braking from v covers the rest at about half speed on average.
  years += remaining > 0 ? (2 * remaining) / v : 0;
  return years * SECONDS_PER_YEAR;
}

export interface TransitSummary {
  fromName: string;
  targetName: string;
  distanceLy: number;
  remainingLy: number;
  /** 0 to 1. */
  progress: number;
  speedC: number;
  burn: Burn;
  etaSeconds: number;
}

/** What the destination readout shows. Null when the Vessel is not in transit (arrived, lost, landed). */
export function transitSummary(state: GalaxyState, vessel: Vessel): TransitSummary | null {
  const t = vessel.transit;
  if (!t || vessel.phase !== 'transit') return null;
  return {
    fromName: starById(state, t.fromStarId)?.name ?? `Star ${t.fromStarId}`,
    targetName: starById(state, t.toStarId)?.name ?? `Star ${t.toStarId}`,
    distanceLy: t.distanceLy,
    remainingLy: Math.max(0, t.distanceLy - t.traveledLy),
    progress: t.distanceLy > 0 ? Math.min(1, t.traveledLy / t.distanceLy) : 1,
    speedC: t.speedC,
    burn: t.burn,
    etaSeconds: transitEtaSeconds(vessel),
  };
}
