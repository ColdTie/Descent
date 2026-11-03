import { describe, expect, it } from 'vitest';
import { applyCommand } from './commands';
import { choiceBlocker, choicesFor } from './events';
import { stepLedger } from './ledger';
import { createGalaxy, focusedVessel, type GalaxyState } from './state';
import { SECONDS_PER_DAY } from './time';

/** Plays one transit to the end, answering each event with its first affordable choice. */
function playTransit(seed: number): { g: GalaxyState; events: number } {
  const g = createGalaxy(seed);
  const v = focusedVessel(g);
  let events = 0;
  for (let i = 0; i < 365 * 300 && v.phase === 'transit'; i++) {
    const open = g.events[0];
    if (open) {
      const idx = choicesFor(open).findIndex((c) => !choiceBlocker(v, c.effect));
      expect(applyCommand(g, { type: 'resolveEvent', eventId: open.id, choice: idx }).ok).toBe(true);
      events++;
      continue;
    }
    stepLedger(g, SECONDS_PER_DAY);
  }
  return { g, events };
}

describe('Phase 3 exit: a full transit', () => {
  it('runs from launch to arrival or loss with at least two events, for every seed tried', () => {
    let withTwo = 0;
    for (let seed = 1; seed <= 12; seed++) {
      const { g, events } = playTransit(seed);
      const v = focusedVessel(g);
      expect(['arrival', 'lost']).toContain(v.phase);
      if (events >= 2) withTwo++;
    }
    expect(withTwo).toBeGreaterThanOrEqual(10);
  });

  it('plays the same way twice for the same seed', () => {
    expect(JSON.stringify(playTransit(4).g)).toBe(JSON.stringify(playTransit(4).g));
  });
});
