import { type GalaxyState, getVessel } from './state';
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
  | { type: 'launch'; vesselId: number; targetStarId: number }
  | { type: 'dismissAlert'; alertId: number };

export interface CommandResult {
  ok: boolean;
  /** Why a command was refused, for the log. Empty when ok. */
  reason: string;
}

const ok: CommandResult = { ok: true, reason: '' };
const refuse = (reason: string): CommandResult => ({ ok: false, reason });

/** Applies one command in place. Returns whether it changed anything. */
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
    // Planetside, events and launch arrive in Phases 3 to 7. Typed now so callers can be written against them.
    case 'setPriority':
    case 'queueBuild':
    case 'setQuota':
    case 'pilotRobot':
    case 'resolveEvent':
    case 'launch':
      return refuse(`${cmd.type} is not implemented yet`);
  }
}
