import { SYSTEM_IDS, type SystemId } from '../content/systems';
import { REPAIR_AMOUNT, REPAIR_PARTS } from '../content/transit';
import { applyChoice, choiceBlocker, choicesFor } from './events';
import { appendLog, type GalaxyState, getVessel, type Vessel } from './state';
import { isWarp } from './time';

/** Every way the player can change the galaxy. UI, hotkeys and the drone view dispatch these; nothing else writes state. */
export type Command =
  | { type: 'setWarp'; warp: number }
  | { type: 'pause'; paused: boolean }
  | { type: 'focusVessel'; vesselId: number }
  | { type: 'setPriority'; vesselId: number; job: string; value: number }
  | { type: 'queueBuild'; vesselId: number; building: string }
  | { type: 'setQuota'; vesselId: number; quota: string; value: number }
  | { type: 'pilotRobot'; vesselId: number; robotId: number | null }
  | { type: 'resolveEvent'; eventId: number; choice: number }
  | { type: 'repair'; vesselId: number; system: SystemId }
  | { type: 'launch'; vesselId: number; targetStarId: number }
  | { type: 'dismissAlert'; alertId: number };

export interface CommandResult {
  ok: boolean;
  /** Why a command was refused, for the notice line. Empty when ok. */
  reason: string;
}

const ok: CommandResult = { ok: true, reason: '' };
const refuse = (reason: string): CommandResult => ({ ok: false, reason });

/** What one repair would restore right now: the Fabricator's integrity scales the job. */
export function repairGain(vessel: Vessel, system: SystemId): number {
  const fab = vessel.systems.fabricator.integrity;
  const room = 100 - vessel.systems[system].integrity;
  return Math.max(0, Math.min(room, REPAIR_AMOUNT * (fab / 100)));
}

/** Why a repair cannot happen, or '' when it can. */
export function repairBlocker(vessel: Vessel, system: SystemId): string {
  if (vessel.phase === 'lost') return 'Vessel is lost';
  if (vessel.systems.fabricator.integrity <= 0) return 'Fabricator is offline';
  if (vessel.stock.parts < REPAIR_PARTS) return `needs ${REPAIR_PARTS} Parts`;
  if (vessel.systems[system].integrity >= 100) return 'already at 100';
  return '';
}

/** Applies one command in place. */
export function applyCommand(state: GalaxyState, cmd: Command): CommandResult {
  switch (cmd.type) {
    case 'setWarp':
      if (!isWarp(cmd.warp)) return refuse(`unknown warp level ${cmd.warp}`);
      state.warp = cmd.warp;
      return ok;
    case 'pause':
      state.paused = cmd.paused;
      return ok;
    case 'focusVessel':
      if (!getVessel(state, cmd.vesselId)) return refuse(`no Vessel ${cmd.vesselId}`);
      state.focusedVesselId = cmd.vesselId;
      return ok;
    case 'dismissAlert': {
      const before = state.alerts.length;
      state.alerts = state.alerts.filter((a) => a.id !== cmd.alertId);
      return state.alerts.length < before ? ok : refuse(`no alert ${cmd.alertId}`);
    }
    case 'resolveEvent': {
      const event = state.events.find((e) => e.id === cmd.eventId);
      if (!event) return refuse(`no event ${cmd.eventId}`);
      const vessel = getVessel(state, event.vesselId);
      const choice = choicesFor(event)[cmd.choice];
      if (!choice) return refuse(`no choice ${cmd.choice + 1}`);
      if (vessel) {
        const blocker = choiceBlocker(vessel, choice.effect);
        if (blocker) return refuse(`${choice.label}: ${blocker}`);
        applyChoice(state, vessel, event, choice);
      }
      state.events = state.events.filter((e) => e.id !== event.id);
      return ok;
    }
    case 'repair': {
      const vessel = getVessel(state, cmd.vesselId);
      if (!vessel) return refuse(`no Vessel ${cmd.vesselId}`);
      if (!SYSTEM_IDS.includes(cmd.system)) return refuse(`unknown system ${cmd.system}`);
      const blocker = repairBlocker(vessel, cmd.system);
      if (blocker) return refuse(`repair ${cmd.system}: ${blocker}`);
      const gain = repairGain(vessel, cmd.system);
      vessel.stock.parts -= REPAIR_PARTS;
      vessel.systems[cmd.system].integrity = Math.min(100, vessel.systems[cmd.system].integrity + gain);
      appendLog(vessel, state.time, `Fabricator repaired ${cmd.system} +${gain.toFixed(1)} for ${REPAIR_PARTS} Parts.`);
      return ok;
    }
    // Planetside and launch arrive in Phases 5 to 7. Typed now so callers can be written against them.
    case 'setPriority':
    case 'queueBuild':
    case 'setQuota':
    case 'pilotRobot':
    case 'launch':
      return refuse(`${cmd.type} is not implemented yet`);
  }
}
