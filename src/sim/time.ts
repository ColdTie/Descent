/** Game time is integer seconds since the galaxy epoch. */
export const SECONDS_PER_HOUR = 3600;
export const SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR;
export const DAYS_PER_YEAR = 365;
export const SECONDS_PER_YEAR = DAYS_PER_YEAR * SECONDS_PER_DAY;

export const WARP_LEVELS = [1, 10, 100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000] as const;
export type Warp = (typeof WARP_LEVELS)[number];

/** Most steps the clock will hand out for one real frame; anything beyond is dropped, not caught up. */
export const MAX_STEPS_PER_TICK = 240;

export function isWarp(value: number): value is Warp {
  return (WARP_LEVELS as readonly number[]).includes(value);
}

/**
 * Game seconds covered by one fixed step at a given warp: one second at 1x, growing with warp,
 * capped at one game day. Keeps steps per real second at or under ~116 at every level.
 */
export function stepSecondsFor(warp: number): number {
  return Math.min(SECONDS_PER_DAY, Math.max(1, Math.floor(warp / 100)));
}

export interface ClockReadout {
  year: number;
  day: number;
  hour: number;
  minute: number;
}

/** Year / Day / Hour display. Years and days are 1-based so the epoch reads Y 1 · D 1 · 00:00. */
export function readClock(seconds: number): ClockReadout {
  const whole = Math.max(0, Math.floor(seconds));
  const year = Math.floor(whole / SECONDS_PER_YEAR) + 1;
  const day = Math.floor((whole % SECONDS_PER_YEAR) / SECONDS_PER_DAY) + 1;
  const hour = Math.floor((whole % SECONDS_PER_DAY) / SECONDS_PER_HOUR);
  const minute = Math.floor((whole % SECONDS_PER_HOUR) / 60);
  return { year, day, hour, minute };
}

export function formatClock(seconds: number): string {
  const r = readClock(seconds);
  return `Y ${r.year} · D ${r.day} · ${String(r.hour).padStart(2, '0')}:${String(r.minute).padStart(2, '0')}`;
}

/** Durations such as an ETA: "31 y 4 d", "12 d", "5 h". */
export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds)) return '—';
  const s = Math.max(0, seconds);
  const years = Math.floor(s / SECONDS_PER_YEAR);
  const days = Math.floor((s % SECONDS_PER_YEAR) / SECONDS_PER_DAY);
  const hours = Math.floor((s % SECONDS_PER_DAY) / SECONDS_PER_HOUR);
  if (years > 0) return `${years} y ${days} d`;
  if (days > 0) return `${days} d ${hours} h`;
  return `${hours} h`;
}

export function formatWarp(warp: number): string {
  if (warp >= 1_000_000) return `${warp / 1_000_000}M`;
  if (warp >= 1_000) return `${warp / 1_000}k`;
  return String(warp);
}
