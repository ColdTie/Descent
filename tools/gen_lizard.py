#!/usr/bin/env python3
"""Render the Lizard Titan SVG to a 192x192 anti-aliased PNG.

Matches the style of the other enemy/boss sprites which are also produced
by rasterizing custom SVGs (assets/sprites/enemy_*.svg) with cairosvg.

Input : assets/sprites/enemy_boss_lizard_titan.svg
Output: assets/sprites/enemy_boss_lizard_titan.png
"""

import os

import cairosvg

SVG = "assets/sprites/enemy_boss_lizard_titan.svg"
PNG = "assets/sprites/enemy_boss_lizard_titan.png"
SIZE = 192


def main() -> None:
    if not os.path.isfile(SVG):
        raise SystemExit(f"missing {SVG}")
    cairosvg.svg2png(url=SVG, write_to=PNG, output_width=SIZE, output_height=SIZE)
    print(f"wrote {PNG}")


if __name__ == "__main__":
    main()
