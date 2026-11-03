import { describe, expect, it } from 'vitest';
import { BODY_DEFS, SURVEY_DAYS } from '../content/bodies';
import { applyCommand } from './commands';
import { choiceBlocker, choicesFor } from './events';
import { stepLedger } from './ledger';
import { createGalaxy, focusedVessel } from './state';
import { SECONDS_PER_DAY } from './time';

describe('Phase 4 exit: land on a chosen world and enter Planetside', () => {
  it('flies, surveys the most ore-rich landable body, lands, for every seed that arrives', () => {
    let landed = 0;
    for (let seed = 1; seed <= 10; seed++) {
      const g = createGalaxy(seed);
      const v = focusedVessel(g);
      for (let i = 0; i < 365 * 300 && v.phase === 'transit'; i++) {
        const open = g.events[0];
        if (open) applyCommand(g, { type: 'resolveEvent', eventId: open.id, choice: choicesFor(open).findIndex((c) => !choiceBlocker(v, c.effect)) });
        else stepLedger(g, SECONDS_PER_DAY);
      }
      if (v.phase !== 'arrival') continue;
      const sys = g.starSystems[v.starId!]!;
      // Survey everything, one at a time, then pick.
      for (const b of sys.bodies) {
        expect(applyCommand(g, { type: 'surveyBody', vesselId: 1, bodyId: b.id }).ok).toBe(true);
        for (let d = 0; d < SURVEY_DAYS * 2 && v.survey; d++) stepLedger(g, SECONDS_PER_DAY);
        expect(b.surveyed).toBe(true);
      }
      const pick = sys.bodies.filter((b) => BODY_DEFS[b.kind].landable).sort((a, b) => b.profile.ore - a.profile.ore)[0]!;
      expect(applyCommand(g, { type: 'land', vesselId: 1, bodyId: pick.id }).ok).toBe(true);
      if ((v.phase as string) === 'planetside') landed++;
      expect(g.worlds[v.worldId!]!.bodyId).toBe(pick.id);
    }
    expect(landed).toBeGreaterThanOrEqual(7);
  });
});
