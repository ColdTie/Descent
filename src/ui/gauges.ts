export type IntegrityLevel = 'good' | 'warn' | 'critical';

/** Matches the alert thresholds in content/systems.ts: below 50 is a warning, below 25 is critical. */
export function integrityLevel(integrity: number): IntegrityLevel {
  if (integrity < 25) return 'critical';
  if (integrity < 50) return 'warn';
  return 'good';
}

export function formatInteger(n: number): string {
  return String(Math.round(n));
}

/** Compact stock numbers: 1234 → "1.2k". */
export function formatStock(n: number): string {
  if (Math.abs(n) >= 10_000) return `${(n / 1000).toFixed(0)}k`;
  if (Math.abs(n) >= 1000) return `${(n / 1000).toFixed(1)}k`;
  return String(Math.round(n));
}
