import { describe, expect, it } from 'vitest';
import type { Command } from './commands';
import { Game, runSteps } from './game';
import { serialize } from './migrations';
import { choicesFor } from './events';
import { createGalaxy } from './state';

const script: ReadonlyArray<{ step: number; cmd: Command }> = [
  { step: 0, cmd: { type: 'setWarp', warp: 100000 } },
  { step: 10, cmd: { type: 'pause', paused: true } },
  { step: 11, cmd: { type: 'pause', paused: false } },
  { step: 50, cmd: { type: 'setWarp', warp: 10 } },
];

describe('determinism', () => {
  it('produces identical state from the same seed and command list', () => {
    const a = runSteps(createGalaxy(2024), 500, 3600, script);
    const b = runSteps(createGalaxy(2024), 500, 3600, script);
    expect(serialize(a)).toBe(serialize(b));
  });

  it('diverges with a different seed or a different command list', () => {
    const a = runSteps(createGalaxy(2024), 100, 3600, script);
    const b = runSteps(createGalaxy(2025), 100, 3600, script);
    expect(serialize(a)).not.toBe(serialize(b));
    const c = runSteps(createGalaxy(2024), 100, 3600, [{ step: 0, cmd: { type: 'setWarp', warp: 1000 } }]);
    expect(serialize(c)).not.toBe(serialize(a));
    expect(c.warp).toBe(1000);
    expect(a.warp).toBe(10);
  });

  it('is the same through the Game tick path as through runSteps', () => {
    const game = Game.fresh(77);
    game.dispatch({ type: 'setWarp', warp: 100 });
    let steps = 0;
    while (steps < 300) steps += game.tick(0.25).steps;
    const direct = runSteps(createGalaxy(77), steps, 1, [{ step: 0, cmd: { type: 'setWarp', warp: 100 } }]);
    expect(serialize(game.state)).toBe(serialize(direct));
  });
});

describe('Game', () => {
  it('applies commands while paused so the UI stays responsive', () => {
    const game = Game.fresh(1);
    game.dispatch({ type: 'pause', paused: true });
    game.tick(1);
    expect(game.state.paused).toBe(true);
    expect(game.state.time).toBe(0);
    game.dispatch({ type: 'setWarp', warp: 1000 });
    game.tick(1);
    expect(game.state.warp).toBe(1000);
    expect(game.state.time).toBe(0);
  });

  it('stops the frame at the first alert or event and drops warp to 1x', () => {
    const game = Game.fresh(1);
    game.dispatch({ type: 'setWarp', warp: 10_000_000 });
    let hit = null;
    for (let i = 0; i < 400 && !hit; i++) {
      const r = game.tick(1);
      if (r.alerts.length || r.events.length) hit = r;
    }
    expect(hit).not.toBeNull();
    expect(game.state.warp).toBe(1);
    const stamp = hit!.alerts[0]?.time ?? hit!.events[0]!.time;
    expect(game.state.time - stamp).toBe(hit!.stepSeconds);
  });

  it('does not burst at 1x after leaving 10M with a remainder in the clock', () => {
    const game = Game.fresh(1);
    game.dispatch({ type: 'setWarp', warp: 10_000_000 });
    for (let i = 0; i < 7; i++) game.tick(1 / 60);
    game.dispatch({ type: 'setWarp', warp: 1 });
    const r = game.tick(1 / 60);
    expect(r.steps).toBeLessThanOrEqual(1);
    expect(r.droppedSeconds).toBe(0);
  });

  it('matches across two Game instances fed the same frames, warp and pause included', () => {
    const drive = (seed: number): Game => {
      const g = Game.fresh(seed);
      g.dispatch({ type: 'setWarp', warp: 1_000_000 });
      for (let i = 0; i < 600; i++) {
        if (i === 100) g.dispatch({ type: 'pause', paused: true });
        if (i === 150) g.dispatch({ type: 'pause', paused: false });
        const open = g.state.events[0];
        if (open) g.dispatch({ type: 'resolveEvent', eventId: open.id, choice: choicesFor(open).length - 1 });
        g.tick(1 / 30);
      }
      return g;
    };
    const a = drive(31);
    const b = drive(31);
    expect(serialize(a.state)).toBe(serialize(b.state));
    expect(a.state.time).toBeGreaterThan(0);
  });

  it('collects refusals for bad commands', () => {
    const game = Game.fresh(1);
    game.dispatch({ type: 'setWarp', warp: 3 });
    game.tick(0.01);
    expect(game.takeRefusals()).toEqual(['unknown warp level 3']);
    expect(game.takeRefusals()).toEqual([]);
  });
});
