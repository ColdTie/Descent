import { describe, expect, it } from 'vitest';
import { formatStock, integrityLevel } from './gauges';

describe('gauges', () => {
  it('maps integrity to the alert bands', () => {
    expect(integrityLevel(100)).toBe('good');
    expect(integrityLevel(50)).toBe('good');
    expect(integrityLevel(49.9)).toBe('warn');
    expect(integrityLevel(25)).toBe('warn');
    expect(integrityLevel(24.9)).toBe('critical');
    expect(integrityLevel(0)).toBe('critical');
  });

  it('formats stock compactly', () => {
    expect(formatStock(0)).toBe('0');
    expect(formatStock(999.4)).toBe('999');
    expect(formatStock(1234)).toBe('1.2k');
    expect(formatStock(25000)).toBe('25k');
  });
});
