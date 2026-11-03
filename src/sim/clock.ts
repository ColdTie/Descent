import { MAX_STEPS_PER_TICK, stepSecondsFor } from './time';

export interface ClockAdvance {
  /** Fixed steps to run this frame. */
  steps: number;
  /** Game seconds per step. */
  stepSeconds: number;
  /** Game seconds that were dropped because the frame asked for more than MAX_STEPS_PER_TICK. */
  droppedSeconds: number;
}

/**
 * Fixed step accumulator. Warp and pause live in GalaxyState (the ledger is the truth);
 * the clock only converts real time into a whole number of steps.
 */
export class GameClock {
  private accumulator = 0;

  advance(realDtSeconds: number, warp: number, paused: boolean): ClockAdvance {
    const stepSeconds = stepSecondsFor(warp);
    if (paused || realDtSeconds <= 0) return { steps: 0, stepSeconds, droppedSeconds: 0 };
    this.accumulator += realDtSeconds * warp;
    let steps = Math.floor(this.accumulator / stepSeconds);
    this.accumulator -= steps * stepSeconds;
    let droppedSeconds = 0;
    if (steps > MAX_STEPS_PER_TICK) {
      droppedSeconds = (steps - MAX_STEPS_PER_TICK) * stepSeconds + this.accumulator;
      steps = MAX_STEPS_PER_TICK;
      this.accumulator = 0;
    }
    return { steps, stepSeconds, droppedSeconds };
  }

  /** Forget partial progress, e.g. after a load. */
  reset(): void {
    this.accumulator = 0;
  }
}
