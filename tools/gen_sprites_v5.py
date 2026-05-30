#!/usr/bin/env python3
"""DESCENT — Sprite Generator v5

Renders the bespoke SVG character art (custom-drawn, stored in assets/sprites/)
to crisp 192×192 anti-aliased PNGs using cairosvg.

Falls back to downloading DCSS CC0 pixel art (NEAREST-scaled) only for the
generic enemy_boss fallback which has no SVG source.

SVG sprites: hero_brawler, hero_rogue, hero_arcanist, enemy_imp, enemy_goblin,
  enemy_skeleton, enemy_demon, enemy_golem, enemy_boss_dungeon_lord,
  enemy_boss_warden, enemy_boss_abyss_keeper

Portraits: 200×220 composed cards — SVG sprite on class-coloured gradient
  background with radial glow and accent strip.
"""

import os
import sys
from io import BytesIO
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from PIL import Image, ImageDraw, ImageFilter
import cairosvg

ROOT        = os.path.dirname(os.path.abspath(__file__))
SPRITES_DIR  = os.path.join(ROOT, "..", "assets", "sprites")
PORTRAITS_DIR = os.path.join(ROOT, "..", "assets", "portraits")

BATTLE_SIZE = 192   # 2× the 96×96 SVG viewBox — vector art stays crisp

# All sprite names that have an SVG source
SVG_SPRITES = [
    "hero_brawler",
    "hero_rogue",
    "hero_arcanist",
    "enemy_imp",
    "enemy_goblin",
    "enemy_skeleton",
    "enemy_demon",
    "enemy_golem",
    "enemy_boss_dungeon_lord",
    "enemy_boss_warden",
    "enemy_boss_abyss_keeper",
]

# Portrait config: class_id → (svg_sprite_name, bg_top, bg_bot, accent_rgb)
PORTRAIT_MAP: dict[str, tuple] = {
    "brawler":  ("hero_brawler",  (44, 22, 10), (92, 38, 16),  (225, 92,  22)),
    "rogue":    ("hero_rogue",    (12,  5, 20), (26, 12, 46),  (142, 90, 222)),
    "arcanist": ("hero_arcanist", (14,  5, 32), (22,  8, 54),  (172, 106, 255)),
}

# DCSS fallback for sprites that have no SVG yet
DCSS_BASE     = "https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/source/rltiles"
DCSS_FALLBACK: dict[str, str] = {
    "enemy_boss": "mon/unique/cerebov.png",
}

PW, PH = 200, 220   # portrait canvas dimensions


# ── SVG rendering ─────────────────────────────────────────────────────────────

def _svg_to_img(svg_path: str, size: int) -> Image.Image:
    """Render an SVG file to a PIL RGBA image at `size` × `size`."""
    png_bytes = cairosvg.svg2png(url=svg_path, output_width=size, output_height=size)
    return Image.open(BytesIO(png_bytes)).convert("RGBA")


# ── Pixel-art outline (used for DCSS fallback sprites) ────────────────────────

def _add_outline(img: Image.Image, color: tuple = (8, 4, 18, 255),
                 thickness: int = 2) -> Image.Image:
    alpha   = img.getchannel("A")
    kernel  = thickness * 2 + 1
    dilated = alpha.filter(ImageFilter.MaxFilter(kernel))
    outline = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d_pix   = dilated.load()
    a_pix   = alpha.load()
    o_pix   = outline.load()
    for y in range(img.height):
        for x in range(img.width):
            if d_pix[x, y] > 30 and a_pix[x, y] < 30:
                o_pix[x, y] = color
    result = Image.new("RGBA", img.size, (0, 0, 0, 0))
    result.paste(outline, (0, 0))
    result.paste(img, (0, 0), img)
    return result


# ── DCSS fallback download ────────────────────────────────────────────────────

def _fetch_dcss(dcss_path: str) -> Image.Image:
    url = f"{DCSS_BASE}/{dcss_path}"
    req = Request(url, headers={"User-Agent": "descent-sprite-fetcher/5"})
    with urlopen(req, timeout=15) as r:
        return Image.open(BytesIO(r.read())).convert("RGBA")


def _make_dcss_sprite(raw: Image.Image) -> Image.Image:
    if raw.size != (32, 32):
        raw = raw.resize((32, 32), Image.LANCZOS)
    scaled = raw.resize((BATTLE_SIZE, BATTLE_SIZE), Image.NEAREST)
    return _add_outline(scaled, thickness=2)


# ── Portrait composition ──────────────────────────────────────────────────────

def _gradient_bg(top: tuple, bot: tuple) -> Image.Image:
    canvas = Image.new("RGBA", (PW, PH), (0, 0, 0, 255))
    d = ImageDraw.Draw(canvas)
    for y in range(PH):
        t  = y / PH
        r  = int(top[0] * (1 - t) + bot[0] * t)
        g  = int(top[1] * (1 - t) + bot[1] * t)
        b  = int(top[2] * (1 - t) + bot[2] * t)
        d.line([(0, y), (PW, y)], fill=(r, g, b, 255))
    return canvas


def _add_glow(canvas: Image.Image, cx: int, cy: int,
              radius: int, col: tuple) -> Image.Image:
    glow = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    d    = ImageDraw.Draw(glow)
    cr, cg, cb = col[:3]
    for i in range(5, 0, -1):
        r2 = radius * i // 3
        al = min(255, 80 * i // 5)
        d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(cr, cg, cb, al))
    blurred = glow.filter(ImageFilter.GaussianBlur(radius // 3))
    return Image.alpha_composite(canvas, blurred)


def _make_portrait(svg_path: str, bg_top: tuple, bg_bot: tuple,
                   accent: tuple) -> Image.Image:
    """200×220 portrait card: gradient bg + radial glow + SVG sprite + accent strip."""
    SPRITE_PX = 170  # sprite fills most of the 200px card width

    canvas = _gradient_bg(bg_top, bg_bot)
    canvas = _add_glow(canvas, PW // 2, PH // 2 - 10, 90, accent)

    sprite = _svg_to_img(svg_path, SPRITE_PX)

    # Subtle dark outline so sprite reads against any background colour
    alpha   = sprite.getchannel("A")
    kernel  = 5
    dilated = alpha.filter(ImageFilter.MaxFilter(kernel))
    outline = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    dp = dilated.load(); ap = alpha.load(); op = outline.load()
    for y in range(sprite.height):
        for x in range(sprite.width):
            if dp[x, y] > 30 and ap[x, y] < 30:
                op[x, y] = (8, 4, 18, 220)
    base = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    base.paste(outline, (0, 0))
    base.paste(sprite, (0, 0), sprite)
    sprite = base

    sx = (PW - SPRITE_PX) // 2
    sy = (PH - SPRITE_PX) // 2 - 14
    canvas.paste(sprite, (sx, sy), sprite)

    d = ImageDraw.Draw(canvas)
    cr, cg, cb = accent[:3]
    # Bottom accent strip
    d.rectangle([0, PH - 16, PW, PH],      fill=(cr // 2, cg // 2, cb // 2, 255))
    d.rectangle([0, PH - 16, PW, PH - 14], fill=(cr, cg, cb, 255))
    # Three-side class-colour border
    d.rectangle([0, 0, PW - 1, 0],           fill=(cr, cg, cb, 200))
    d.rectangle([0, 0, 0, PH - 1],            fill=(cr, cg, cb, 200))
    d.rectangle([PW - 1, 0, PW - 1, PH - 1], fill=(cr, cg, cb, 200))

    return canvas


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    os.makedirs(SPRITES_DIR,   exist_ok=True)
    os.makedirs(PORTRAITS_DIR, exist_ok=True)

    print("=== Battle Sprites (custom SVG → 192×192 anti-aliased PNG) ===")
    failed: list[str] = []

    for name in SVG_SPRITES:
        svg_path = os.path.join(SPRITES_DIR, f"{name}.svg")
        out_path = os.path.join(SPRITES_DIR, f"{name}.png")
        sys.stdout.write(f"  {name:<38} ")
        sys.stdout.flush()
        try:
            img = _svg_to_img(svg_path, BATTLE_SIZE)
            img.save(out_path)
            print(f"✓  {os.path.getsize(out_path):>8,} b  [SVG]")
        except Exception as e:
            print(f"FAIL: {e}")
            failed.append(name)

    # DCSS pixel-art fallback sprites (no custom SVG source)
    for name, dcss_path in DCSS_FALLBACK.items():
        out_path = os.path.join(SPRITES_DIR, f"{name}.png")
        sys.stdout.write(f"  {name:<38} [DCSS fallback] ")
        sys.stdout.flush()
        try:
            raw = _fetch_dcss(dcss_path)
            out = _make_dcss_sprite(raw)
            out.save(out_path)
            print(f"✓  {os.path.getsize(out_path):>8,} b")
        except (URLError, HTTPError, OSError) as e:
            print(f"FAIL: {e}")
            failed.append(name)

    print(f"\n=== Class Portraits (SVG sprite → 170px on {PW}×{PH} bg) ===")
    for cls_id, (svg_name, bg_top, bg_bot, accent) in PORTRAIT_MAP.items():
        svg_path = os.path.join(SPRITES_DIR, f"{svg_name}.svg")
        out_path = os.path.join(PORTRAITS_DIR, f"{cls_id}.png")
        sys.stdout.write(f"  {cls_id:<12} ")
        sys.stdout.flush()
        try:
            portrait = _make_portrait(svg_path, bg_top, bg_bot, accent)
            portrait.save(out_path)
            print(f"✓  {os.path.getsize(out_path):>8,} b")
        except Exception as e:
            print(f"FAIL: {e}")
            failed.append(f"portrait:{cls_id}")

    if failed:
        print(f"\n⚠  {len(failed)} sprite(s) failed: {', '.join(failed)}")
        print("   The game will use fallback glyphs for missing sprites.")
    else:
        print("\nAll sprites generated successfully.")


if __name__ == "__main__":
    main()
