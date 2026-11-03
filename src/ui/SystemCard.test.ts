import { describe, expect, it } from 'vitest';
import type { Body } from '../sim/system';
import { profileLine } from './SystemCard';

const body = (kind: Body['kind'], hazard: Body['profile']['hazard'] = 'none', severity = 0): Body => ({
  id: 0,
  name: 'Star 3 b',
  kind,
  orbitAu: 1,
  surveyed: true,
  profile: { ore: 0.82, ice: 0.04, gravity: 0.93, hazard, severity },
});

describe('profileLine', () => {
  it('reads a landable body in plain units', () => {
    expect(profileLine(body('rocky'))).toBe('ore 82% · ice 4% · 0.9 g · no hazard');
    expect(profileLine(body('molten', 'quakes', 2))).toBe('ore 82% · ice 4% · 0.9 g · quakes 2');
  });

  it('says a gas giant has no surface', () => {
    expect(profileLine(body('gasGiant', 'storms', 3))).toBe('0.9 g · storms 3 · no surface');
  });
});
