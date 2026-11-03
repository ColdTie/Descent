import { GameClock } from './clock';
import { applyCommand, type Command } from './commands';
import { stepLedger, type StepReport } from './ledger';
import { createGalaxy, type GalaxyState } from './state';

export interface TickReport {
  steps: number;
  stepSeconds: number;
  droppedSeconds: number;
  alerts: StepReport['alerts'];
  /** True when state changed this tick (steps ran or a command applied). */
  changed: boolean;
}

/**
 * Owns the galaxy, the clock and the command queue. Commands are applied at step boundaries;
 * when the clock is paused they apply at the next tick so the UI still responds.
 */
export class Game {
  state: GalaxyState;
  readonly clock = new GameClock();
  private queue: Command[] = [];
  private refused: string[] = [];

  constructor(state: GalaxyState) {
    this.state = state;
  }

  static fresh(seed: number): Game {
    return new Game(createGalaxy(seed));
  }

  dispatch(cmd: Command): void {
    this.queue.push(cmd);
  }

  /** Reasons for commands refused since the last call. */
  takeRefusals(): string[] {
    const out = this.refused;
    this.refused = [];
    return out;
  }

  /** Replace the galaxy, e.g. after a load. */
  load(state: GalaxyState): void {
    this.state = state;
    this.queue = [];
    this.clock.reset();
  }

  private flush(): boolean {
    let changed = false;
    for (const cmd of this.queue) {
      const r = applyCommand(this.state, cmd);
      if (r.ok) changed = true;
      else this.refused.push(r.reason);
    }
    this.queue = [];
    return changed;
  }

  tick(realDtSeconds: number): TickReport {
    let changed = this.flush();
    const { steps, stepSeconds, droppedSeconds } = this.clock.advance(realDtSeconds, this.state.warp, this.state.paused);
    const alerts: StepReport['alerts'] = [];
    for (let i = 0; i < steps; i++) {
      if (i > 0 && this.flush()) changed = true;
      const report = stepLedger(this.state, stepSeconds);
      alerts.push(...report.alerts);
      if (report.alerts.length > 0 && this.state.warp !== 1) {
        // Any alert drops warp to 1x (DESIGN.md, Time). The remaining steps this frame still run at the old step size.
        this.state.warp = 1;
      }
    }
    if (steps > 0) changed = true;
    return { steps, stepSeconds, droppedSeconds, alerts, changed };
  }
}

/** Deterministic driver for tests: runs N steps of a given size, applying commands tagged by step index. */
export function runSteps(state: GalaxyState, steps: number, stepSeconds: number, commands: ReadonlyArray<{ step: number; cmd: Command }> = []): GalaxyState {
  for (let i = 0; i < steps; i++) {
    for (const c of commands) if (c.step === i) applyCommand(state, c.cmd);
    stepLedger(state, stepSeconds);
  }
  return state;
}
