import { GameClock } from './clock';
import { applyCommand, type Command } from './commands';
import { stepLedger, type StepReport } from './ledger';
import { createGalaxy, type GalaxyState } from './state';

export interface TickReport {
  steps: number;
  stepSeconds: number;
  droppedSeconds: number;
  alerts: StepReport['alerts'];
  events: StepReport['events'];
  /** True when state changed this tick (steps ran or a command applied). */
  changed: boolean;
}

/**
 * Owns the galaxy, the clock and the command queue. Commands apply at step boundaries; when the
 * clock is paused they apply on the next tick so the UI still responds. The frame stops at the
 * first step that raises an alert or opens an event, so the player sees the galaxy as it was then.
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
    const holding = this.state.paused || this.state.events.length > 0;
    const { steps: planned, stepSeconds, droppedSeconds } = this.clock.advance(realDtSeconds, this.state.warp, holding);
    const alerts: StepReport['alerts'] = [];
    const events: StepReport['events'] = [];
    let steps = 0;
    for (let i = 0; i < planned; i++) {
      const report = stepLedger(this.state, stepSeconds);
      if (!report.ran) break;
      steps++;
      alerts.push(...report.alerts);
      events.push(...report.events);
      if (report.alerts.length > 0 || report.events.length > 0) {
        this.clock.reset();
        break;
      }
    }
    if (steps > 0) changed = true;
    return { steps, stepSeconds, droppedSeconds, alerts, events, changed };
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
