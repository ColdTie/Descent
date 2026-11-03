import { describe, expect, it } from 'vitest';
import { STARTING_STOCK } from '../content/resources';
import type { Building, Colony } from '../sim/colony/types';
import { costText, queueState, rateText } from './colonyView';

const colony = { robots: [] } as unknown as Colony;
const bld = (over: Partial<Building>): Building => ({ id: 1, type: 'fabricator', cell: 10, nodeId: null, paid: false, auto: false, progress: 0, input: 0, output: 0, working: false, ...over });

describe('colony view helpers', () => {
  it('writes costs plainly', () => {
    expect(costText({ parts: 4, metal: 30 })).toBe('4 Parts · 30 Metal');
    expect(costText({})).toBe('free');
  });

  it('says what a queued building waits on', () => {
    const stock = { ...STARTING_STOCK };
    expect(queueState(colony, stock, bld({ cell: -1, type: 'oreMiner' }))).toBe('needs a surveyed ore node');
    expect(queueState(colony, stock, bld({}))).toBe('needs 30 Metal');
    expect(queueState(colony, stock, bld({ paid: true }))).toBe('waiting for a builder');
    expect(queueState(colony, stock, bld({ paid: true, progress: 0.4 }))).toBe('paused at 40%');
  });

  it('formats rates and hides tiny ones', () => {
    expect(rateText(3.24)).toBe('+3.2/h');
    expect(rateText(0.01)).toBe('');
    expect(rateText(undefined)).toBe('');
  });
});
