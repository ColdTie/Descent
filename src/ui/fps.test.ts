import { describe, expect, it } from 'vitest';
import { FpsMeter } from './fps';

describe('FpsMeter', () => {
  it('publishes a rounded fps once the window fills', () => {
    const meter = new FpsMeter(0.5);
    const seen: number[] = [];
    meter.subscribe((fps) => seen.push(fps));
    // 1/64 is exact in binary, so 32 samples sum to exactly the 0.5 s window.
    for (let i = 0; i < 32; i++) meter.sample(1 / 64);
    expect(seen).toEqual([64]);
    expect(meter.fps).toBe(64);
  });

  it('stops notifying after unsubscribe', () => {
    const meter = new FpsMeter(0.1);
    const seen: number[] = [];
    const off = meter.subscribe((fps) => seen.push(fps));
    meter.sample(0.1);
    off();
    meter.sample(0.1);
    expect(seen).toHaveLength(1);
  });
});
