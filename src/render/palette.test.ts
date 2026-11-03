import { describe, expect, it } from 'vitest';
import { palette } from './palette';

describe('palette', () => {
  it('holds 24-bit colors only', () => {
    for (const [key, value] of Object.entries(palette)) {
      expect(Number.isInteger(value), key).toBe(true);
      expect(value, key).toBeGreaterThanOrEqual(0);
      expect(value, key).toBeLessThanOrEqual(0xffffff);
    }
  });
});
