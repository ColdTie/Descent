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
