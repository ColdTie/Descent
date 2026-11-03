/** Small fixed palette for flat shaded placeholders. Hex colors as Three.js expects them. */
export const palette = {
  space: 0x05060d,
  star: 0xdfe6ff,
  hull: 0x9aa7b8,
  hullDark: 0x5b6676,
  ring: 0xc8a24a,
  drive: 0x3b4a5e,
  driveGlow: 0x4fd1ff,
  sun: 0xfff1d6,
  sky: 0x3a4a6a,
  ground: 0x14161e,
} as const;

export type PaletteKey = keyof typeof palette;

/** Star colors by spectral class, for destination markers and the star map. */
export const SPECTRAL_COLORS: Record<string, number> = {
  O: 0x9bb0ff,
  B: 0xaabfff,
  A: 0xcad7ff,
  F: 0xf8f7ff,
  G: 0xfff4ea,
  K: 0xffd2a1,
  M: 0xffbd6f,
};

export function spectralColor(spectral: string): number {
  return SPECTRAL_COLORS[spectral] ?? palette.star;
}

/** Body colours by kind once surveyed. */
export const BODY_COLORS: Record<string, number> = {
  molten: 0xe0683a,
  rocky: 0xa8957a,
  icy: 0xa9d8ea,
  gasGiant: 0xd2b48a,
};
