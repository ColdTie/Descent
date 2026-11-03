import { describe, expect, it } from 'vitest';
import { GameClock } from './clock';
import { MAX_STEPS_PER_TICK, SECONDS_PER_DAY, WARP_LEVELS } from './time';

describe('GameClock', () => {
  it('hands out one step per game second at 1x', () => {
    const c = new GameClock();
    expect(c.advance(0.5, 1, false).steps).toBe(0);
    expect(c.advance(0.5, 1, false).steps).toBe(1);
    expect(c.advance(2.25, 1, false).steps).toBe(2);
  });

  it('runs no steps while paused and keeps nothing in the accumulator', () => {
    const c = new GameClock();
    expect(c.advance(5, 1, true).steps).toBe(0);
    expect(c.advance(0.1, 1, false).steps).toBe(0);
  });

  it('covers warp × real seconds of game time at every level', () => {
    for (const w of WARP_LEVELS) {
      const c = new GameClock();
      const r = c.advance(1, w, false);
      expect(r.steps * r.stepSeconds).toBeLessThanOrEqual(w);
      expect(r.steps * r.stepSeconds).toBeGreaterThan(w - r.stepSeconds);
      expect(r.droppedSeconds).toBe(0);
    }
  });

  it('caps steps per tick and reports the dropped time instead of catching up', () => {
    const c = new GameClock();
    const r = c.advance(10, 10_000_000, false);
    expect(r.steps).toBe(MAX_STEPS_PER_TICK);
    expect(r.stepSeconds).toBe(SECONDS_PER_DAY);
    expect(r.droppedSeconds).toBeGreaterThan(0);
    expect(c.advance(0, 1, false).steps).toBe(0);
  });
});
