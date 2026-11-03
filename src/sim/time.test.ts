import { describe, expect, it } from 'vitest';
import { formatClock, formatDuration, formatWarp, isWarp, readClock, SECONDS_PER_DAY, SECONDS_PER_YEAR, stepSecondsFor, WARP_LEVELS } from './time';

describe('warp and step length', () => {
  it('lists the eight warp levels from DESIGN.md', () => {
    expect([...WARP_LEVELS]).toEqual([1, 10, 100, 1000, 10000, 100000, 1000000, 10000000]);
    expect(isWarp(1000)).toBe(true);
    expect(isWarp(500)).toBe(false);
  });

  it('keeps every warp level between one game second and one game day per step', () => {
    for (const w of WARP_LEVELS) {
      const s = stepSecondsFor(w);
      expect(s).toBeGreaterThanOrEqual(1);
      expect(s).toBeLessThanOrEqual(SECONDS_PER_DAY);
      expect(Number.isInteger(s)).toBe(true);
    }
    expect(stepSecondsFor(1)).toBe(1);
    expect(stepSecondsFor(10_000_000)).toBe(SECONDS_PER_DAY);
  });

  it('bounds the steps per real second at every warp level', () => {
    for (const w of WARP_LEVELS) expect(w / stepSecondsFor(w)).toBeLessThanOrEqual(120);
  });
});

describe('clock readout', () => {
  it('starts at Y 1 · D 1 · 00:00', () => {
    expect(readClock(0)).toEqual({ year: 1, day: 1, hour: 0, minute: 0 });
    expect(formatClock(0)).toBe('Y 1 · D 1 · 00:00');
  });

  it('rolls days and years', () => {
    expect(readClock(SECONDS_PER_DAY * 202 + 6 * 3600 + 5 * 60)).toEqual({ year: 1, day: 203, hour: 6, minute: 5 });
    expect(readClock(SECONDS_PER_YEAR * 11)).toEqual({ year: 12, day: 1, hour: 0, minute: 0 });
  });

  it('formats durations and warps', () => {
    expect(formatDuration(SECONDS_PER_YEAR * 31 + SECONDS_PER_DAY * 4)).toBe('31 y 4 d');
    expect(formatDuration(SECONDS_PER_DAY * 12 + 3600 * 5)).toBe('12 d 5 h');
    expect(formatDuration(3600 * 5)).toBe('5 h');
    expect(formatDuration(Infinity)).toBe('—');
    expect(formatWarp(1)).toBe('1');
    expect(formatWarp(1000)).toBe('1k');
    expect(formatWarp(10_000_000)).toBe('10M');
  });
});
