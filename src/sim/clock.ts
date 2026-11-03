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
 * the clock only converts real time into a whole number of steps. The leftover is kept in
 * real seconds, so changing warp never turns a 10M remainder into a burst at 1x.
 */
export class GameClock {
  private accumulator = 0;

  advance(realDtSeconds: number, warp: number, paused: boolean): ClockAdvance {
    const stepSeconds = stepSecondsFor(warp);
    if (paused || realDtSeconds <= 0 || !(warp > 0)) {
      if (paused) this.accumulator = 0;
      return { steps: 0, stepSeconds, droppedSeconds: 0 };
    }
    const realPerStep = stepSeconds / warp;
    this.accumulator += realDtSeconds;
    let steps = Math.floor(this.accumulator / realPerStep + 1e-9);
    this.accumulator = Math.max(0, this.accumulator - steps * realPerStep);
    let droppedSeconds = 0;
    if (steps > MAX_STEPS_PER_TICK) {
      droppedSeconds = (steps - MAX_STEPS_PER_TICK) * stepSeconds + this.accumulator * warp;
      steps = MAX_STEPS_PER_TICK;
      this.accumulator = 0;
    }
    return { steps, stepSeconds, droppedSeconds };
  }

  /** Forget partial progress, e.g. after a load or when an event interrupts the frame. */
  reset(): void {
    this.accumulator = 0;
  }
}
