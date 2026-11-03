import { SYSTEM_ALERT_THRESHOLDS, SYSTEM_DEFS, SYSTEM_IDS } from '../content/systems';
import { appendLog, type Alert, type GalaxyState, type Vessel } from './state';
import { SECONDS_PER_HOUR, SECONDS_PER_YEAR } from './time';

export interface StepReport {
  /** Alerts raised during this step, already appended to state.alerts. */
  alerts: Alert[];
}

function raiseAlert(state: GalaxyState, vessel: Vessel, level: Alert['level'], text: string, report: StepReport): void {
  const alert: Alert = { id: state.nextAlertId++, vesselId: vessel.id, time: state.time, level, text };
  state.alerts.push(alert);
  appendLog(vessel, state.time, text);
  report.alerts.push(alert);
}

function stepTransit(vessel: Vessel, dtSeconds: number, state: GalaxyState, report: StepReport): void {
  const t = vessel.transit;
  if (!t) return;
  // Rates are per game hour and integrate linearly inside a step (CLAUDE.md rule 4).
  const hours = dtSeconds / SECONDS_PER_HOUR;
  for (const id of SYSTEM_IDS) {
    const sys = vessel.systems[id];
    sys.integrity = Math.max(0, sys.integrity - SYSTEM_DEFS[id].wearPerHour * hours);
    for (const threshold of SYSTEM_ALERT_THRESHOLDS) {
      if (sys.integrity < threshold && !sys.alerted.includes(threshold)) {
        sys.alerted.push(threshold);
        const level = threshold <= 10 ? 'critical' : threshold <= 25 ? 'warn' : 'info';
        raiseAlert(state, vessel, level, `${SYSTEM_DEFS[id].name} integrity below ${threshold}.`, report);
      }
    }
  }
  // Coasting: speed is a fraction of c, and c is one light year per game year.
  t.traveledLy = Math.min(t.distanceLy, t.traveledLy + (t.speedC * dtSeconds) / SECONDS_PER_YEAR);
}

/**
 * Advances every Vessel and world by one fixed step. The ledger is the truth: this runs for
 * unfocused Vessels too. Arrival, planetside economy and events land in later phases.
 */
export function stepLedger(state: GalaxyState, dtSeconds: number): StepReport {
  const report: StepReport = { alerts: [] };
  for (const vessel of Object.values(state.vessels)) {
    if (vessel.phase === 'transit') stepTransit(vessel, dtSeconds, state, report);
  }
  state.time += dtSeconds;
  return report;
}

/** Seconds left on a transit at its current speed. Infinity when not moving. */
export function transitEtaSeconds(vessel: Vessel): number {
  const t = vessel.transit;
  if (!t || t.speedC <= 0) return Infinity;
  return ((t.distanceLy - t.traveledLy) / t.speedC) * SECONDS_PER_YEAR;
}
