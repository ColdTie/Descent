import { describe, expect, it } from 'vitest';
import { createRng, hashString, initialRngStates, streamRng } from './rng';

describe('named RNG streams', () => {
  it('seeds each stream differently from the same galaxy seed', () => {
    const s = initialRngStates(42);
    expect(new Set([s.galaxy, s.worlds, s.events]).size).toBe(3);
    expect(initialRngStates(42)).toEqual(s);
    expect(initialRngStates(43)).not.toEqual(s);
  });

  it('draws from one stream without moving the others', () => {
    const s = initialRngStates(7);
    const before = { ...s };
    const events = streamRng(s, 'events');
    events.next();
    events.next();
    expect(s.events).not.toBe(before.events);
    expect(s.galaxy).toBe(before.galaxy);
    expect(s.worlds).toBe(before.worlds);
  });

  it('matches createRng seeded with the stream cursor, so a save resumes the exact sequence', () => {
    const s = initialRngStates(99);
    const a = streamRng(s, 'worlds');
    const first = [a.next(), a.next(), a.next()];
    const resumed = createRng(initialRngStates(99).worlds);
    expect([resumed.next(), resumed.next(), resumed.next()]).toEqual(first);
    const copy = { ...s };
    const b = streamRng(copy, 'worlds');
    expect(b.next()).toBe(a.next());
  });

  it('hashes strings stably', () => {
    expect(hashString('events')).toBe(hashString('events'));
    expect(hashString('events')).not.toBe(hashString('galaxy'));
  });
});
