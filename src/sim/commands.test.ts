import { describe, expect, it } from 'vitest';
import { applyCommand } from './commands';
import { createGalaxy } from './state';

describe('commands', () => {
  it('sets warp only to a known level', () => {
    const g = createGalaxy(1);
    expect(applyCommand(g, { type: 'setWarp', warp: 1000 }).ok).toBe(true);
    expect(g.warp).toBe(1000);
    expect(applyCommand(g, { type: 'setWarp', warp: 7 }).ok).toBe(false);
    expect(g.warp).toBe(1000);
  });

  it('pauses and resumes', () => {
    const g = createGalaxy(1);
    applyCommand(g, { type: 'pause', paused: true });
    expect(g.paused).toBe(true);
    applyCommand(g, { type: 'pause', paused: false });
    expect(g.paused).toBe(false);
  });

  it('focuses only Vessels that exist', () => {
    const g = createGalaxy(1);
    expect(applyCommand(g, { type: 'focusVessel', vesselId: 2 }).ok).toBe(false);
    expect(applyCommand(g, { type: 'focusVessel', vesselId: 1 }).ok).toBe(true);
  });

  it('dismisses an alert by id', () => {
    const g = createGalaxy(1);
    g.alerts.push({ id: 5, vesselId: 1, time: 0, level: 'info', text: 'x' });
    expect(applyCommand(g, { type: 'dismissAlert', alertId: 5 }).ok).toBe(true);
    expect(g.alerts).toHaveLength(0);
    expect(applyCommand(g, { type: 'dismissAlert', alertId: 5 }).ok).toBe(false);
  });

  it('refuses the later-phase commands without touching state', () => {
    const g = createGalaxy(1);
    const before = JSON.stringify(g);
    const r = applyCommand(g, { type: 'launch', vesselId: 1, targetStarId: 2 });
    expect(r.ok).toBe(false);
    expect(r.reason).toContain('launch');
    expect(JSON.stringify(g)).toBe(before);
  });
});
