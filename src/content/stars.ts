export const SPECTRAL_CLASSES = ['O', 'B', 'A', 'F', 'G', 'K', 'M'] as const;
export type SpectralClass = (typeof SPECTRAL_CLASSES)[number];

/** Relative abundance in the solar neighbourhood, roughly. Order matches SPECTRAL_CLASSES. */
export const SPECTRAL_WEIGHTS: Record<SpectralClass, number> = {
  O: 0.0003,
  B: 0.1,
  A: 0.6,
  F: 3,
  G: 7.6,
  K: 12,
  M: 76,
};

export const STAR_MAP_RADIUS_LY = 50;
export const STAR_COUNT_MIN = 30;
export const STAR_COUNT_MAX = 60;
export const HOP_MIN_LY = 5;
export const HOP_MAX_LY = 15;
/** Cruise speed as a fraction of c. Tunable (DESIGN.md). */
export const CRUISE_SPEED_C = 0.2;
