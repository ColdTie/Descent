import { describe, expect, it } from 'vitest';
import { createGalaxy } from '../sim/state';
import { commandForKey } from './hotkeys';

describe('hotkeys', () => {
  it('toggles pause with space', () => {
    const g = createGalaxy(1);
    expect(commandForKey(' ', g)).toEqual({ type: 'pause', paused: true });
    g.paused = true;
    expect(commandForKey(' ', g)).toEqual({ type: 'pause', paused: false });
  });

  it('steps warp up and down and clamps at the ends', () => {
    const g = createGalaxy(1);
    expect(commandForKey(']', g)).toEqual({ type: 'setWarp', warp: 10 });
    expect(commandForKey('[', g)).toEqual({ type: 'setWarp', warp: 1 });
    g.warp = 10_000_000;
    expect(commandForKey('+', g)).toEqual({ type: 'setWarp', warp: 10_000_000 });
    expect(commandForKey('-', g)).toEqual({ type: 'setWarp', warp: 1_000_000 });
  });

  it('jumps to a level with digits and ignores other keys', () => {
    const g = createGalaxy(1);
    expect(commandForKey('8', g)).toEqual({ type: 'setWarp', warp: 10_000_000 });
    expect(commandForKey('9', g)).toBeNull();
    expect(commandForKey('q', g)).toBeNull();
  });
});
