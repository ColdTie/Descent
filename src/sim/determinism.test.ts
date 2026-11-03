import { describe, expect, it } from 'vitest';
import type { Command } from './commands';
import { Game, runSteps } from './game';
import { serialize } from './migrations';
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

  it('drops warp to 1x when the ledger raises an alert', () => {
    const game = Game.fresh(1);
    game.dispatch({ type: 'setWarp', warp: 10_000_000 });
    let alerts = 0;
    // One real second at 10M warp is 115 game days; a system crosses 50 integrity after about 30 game years.
    for (let i = 0; i < 400 && alerts === 0; i++) alerts += game.tick(1).alerts.length;
    expect(alerts).toBeGreaterThan(0);
    expect(game.state.warp).toBe(1);
  });

  it('collects refusals for bad commands', () => {
    const game = Game.fresh(1);
    game.dispatch({ type: 'setWarp', warp: 3 });
    game.tick(0.01);
    expect(game.takeRefusals()).toEqual(['unknown warp level 3']);
    expect(game.takeRefusals()).toEqual([]);
  });
});
