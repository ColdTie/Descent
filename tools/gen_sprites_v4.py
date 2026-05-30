#!/usr/bin/env python3
"""DESCENT — Sprite Processor v4

Downloads CC0 DCSS sprites (32×32 pixel art by real artists) and processes
them for maximum visual quality:
  - Scales to 128×128 with NEAREST interpolation (crispy 4× pixel art)
  - Adds dark 2-pixel outline for contrast against any background
  - Generates 200×220 portrait cards with gradient + glow + accent strip
  - Falls back gracefully if any individual sprite fails

DCSS credit: Dungeon Crawl: Stone Soup contributors — CC0 1.0 Universal
https://github.com/crawl/crawl/
"""

import os
import sys
from io import BytesIO
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from PIL import Image, ImageDraw, ImageFilter

DCSS_BASE   = "https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/source/rltiles"
ROOT        = os.path.dirname(os.path.abspath(__file__))
SPRITES_DIR  = os.path.join(ROOT, "..", "assets", "sprites")
PORTRAITS_DIR = os.path.join(ROOT, "..", "assets", "portraits")

# ── Sprite mapping: output name → DCSS path ──────────────────────────────────
BATTLE_MAP: dict[str, str] = {
    # Heroes — three playable classes
    # hell_knight: full plate armour, imposing heavy fighter (Carl-like bruiser)
    # sonja: unique assassin-type with daggers
    # arcanist: canonical wizard human
    "hero_brawler":  "mon/humanoids/humans/hell_knight.png",
    "hero_rogue":    "mon/unique/sonja.png",
    "hero_arcanist": "mon/humanoids/humans/arcanist.png",

    # Regular enemies
    "enemy_imp":      "mon/demons/crimson_imp.png",      # small winged red devil
    "enemy_goblin":   "mon/humanoids/goblin.png",         # green goblin
    "enemy_skeleton": "mon/undead/skeletal_warrior.png",  # armoured undead fighter
    "enemy_demon":    "mon/demons/executioner.png",       # massive fearsome greater demon
    "enemy_golem":    "mon/nonliving/blazeheart_golem.png",  # lava golem (matches lava tiles)

    # Boss encounters (one per 6-floor tier)
    # dispater: Hell's armoured overlord — Lord of Dis
    # vault_warden: elite fortress guardian
    # gloorx_vloq: eldritch unique demon lord of the Abyss
    "enemy_boss_dungeon_lord": "mon/unique/dispater.png",
    "enemy_boss_warden":       "mon/humanoids/humans/vault_warden.png",
    "enemy_boss_abyss_keeper": "mon/unique/gloorx_vloq.png",
    "enemy_boss":              "mon/unique/cerebov.png",
}

# ── Portrait config: class → (dcss_path, bg_top, bg_bot, accent) ─────────────
PORTRAIT_MAP: dict[str, tuple] = {
    "brawler": (
        "mon/humanoids/humans/hell_knight.png",
        (44, 22, 10), (92, 38, 16),
        (225, 92, 22),
    ),
    "rogue": (
        "mon/unique/sonja.png",
        (12, 5, 20), (26, 12, 46),
        (142, 90, 222),
    ),
    "arcanist": (
        "mon/humanoids/humans/arcanist.png",
        (14, 5, 32), (22, 8, 54),
        (172, 106, 255),
    ),
}

BATTLE_SIZE = 128   # 4× NEAREST scale of 32×32 source
PW, PH      = 200, 220  # portrait canvas dimensions


# ── Network ────────────────────────────────────────────────────────────────────

def _fetch(dcss_path: str) -> Image.Image:
    url = f"{DCSS_BASE}/{dcss_path}"
    req = Request(url, headers={"User-Agent": "descent-sprite-fetcher/4"})
    with urlopen(req, timeout=15) as r:
        return Image.open(BytesIO(r.read())).convert("RGBA")


# ── Pixel-art outline ─────────────────────────────────────────────────────────

def _add_outline(img: Image.Image, color: tuple = (8, 4, 18, 255),
                 thickness: int = 2) -> Image.Image:
    """Expand sprite by `thickness` pixels and fill border with `color`."""
    alpha   = img.getchannel("A")
    kernel  = thickness * 2 + 1
    dilated = alpha.filter(ImageFilter.MaxFilter(kernel))

    # Build the outline mask
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


# ── Battle sprite processing ──────────────────────────────────────────────────

def _make_battle_sprite(raw: Image.Image) -> Image.Image:
    """Normalise to 32×32, scale 4× with NEAREST, add dark outline."""
    if raw.size != (32, 32):
        raw = raw.resize((32, 32), Image.LANCZOS)
    scaled = raw.resize((BATTLE_SIZE, BATTLE_SIZE), Image.NEAREST)
    return _add_outline(scaled, thickness=2)


# ── Portrait processing ───────────────────────────────────────────────────────

def _gradient_bg(top: tuple, bot: tuple) -> Image.Image:
    canvas = Image.new("RGBA", (PW, PH), (0, 0, 0, 255))
    d = ImageDraw.Draw(canvas)
    for y in range(PH):
        t = y / PH
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        d.line([(0, y), (PW, y)], fill=(r, g, b, 255))
    return canvas


def _add_glow(canvas: Image.Image, cx: int, cy: int,
              radius: int, col: tuple) -> Image.Image:
    glow = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    cr, cg, cb = col[:3]
    for i in range(5, 0, -1):
        r2 = radius * i // 3
        al = min(255, 72 * i // 5)
        d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2],
                  fill=(cr, cg, cb, al))
    blurred = glow.filter(ImageFilter.GaussianBlur(radius // 2))
    return Image.alpha_composite(canvas, blurred)


def _make_portrait(raw: Image.Image,
                   bg_top: tuple, bg_bot: tuple, accent: tuple) -> Image.Image:
    """200×220 portrait card: gradient + radial glow + 5× pixel sprite + strip."""
    SPRITE_PX = 32 * 5  # 160 px — 5× NEAREST

    canvas = _gradient_bg(bg_top, bg_bot)
    canvas = _add_glow(canvas, PW // 2, PH // 2 - 15, 80, accent)

    # Normalise and scale sprite
    src = raw.resize((32, 32), Image.LANCZOS) if raw.size != (32, 32) else raw
    sprite = src.resize((SPRITE_PX, SPRITE_PX), Image.NEAREST)
    sprite = _add_outline(sprite, color=(8, 4, 18, 255), thickness=3)

    # Centre sprite, nudge up so face is more prominent
    sx = (PW - SPRITE_PX) // 2
    sy = (PH - SPRITE_PX) // 2 - 14
    canvas.paste(sprite, (sx, sy), sprite)

    # Accent strip at bottom
    d = ImageDraw.Draw(canvas)
    cr, cg, cb = accent[:3]
    d.rectangle([0, PH - 16, PW, PH],     fill=(cr // 2, cg // 2, cb // 2, 255))
    d.rectangle([0, PH - 16, PW, PH - 14], fill=(cr, cg, cb, 255))

    # Thin class-colour border on three sides
    d.rectangle([0, 0, PW - 1, 0],         fill=(cr, cg, cb, 200))
    d.rectangle([0, 0, 0, PH - 1],          fill=(cr, cg, cb, 200))
    d.rectangle([PW - 1, 0, PW - 1, PH - 1], fill=(cr, cg, cb, 200))

    return canvas


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    os.makedirs(SPRITES_DIR,   exist_ok=True)
    os.makedirs(PORTRAITS_DIR, exist_ok=True)

    print("=== Battle Sprites (DCSS CC0 → 128×128 NEAREST + outline) ===")
    failed: list[str] = []
    for name, dcss_path in BATTLE_MAP.items():
        sys.stdout.write(f"  {name:<38} ← {dcss_path.split('/')[-1]}  ")
        sys.stdout.flush()
        try:
            raw  = _fetch(dcss_path)
            out  = _make_battle_sprite(raw)
            path = os.path.join(SPRITES_DIR, f"{name}.png")
            out.save(path)
            print(f"✓  {os.path.getsize(path):>7,} b")
        except (URLError, HTTPError, OSError) as e:
            print(f"FAIL: {e}")
            failed.append(name)

    print(f"\n=== Class Portraits (160×160 on 200×220 bg) ===")
    for cls_id, (dcss_path, bg_top, bg_bot, accent) in PORTRAIT_MAP.items():
        sys.stdout.write(f"  {cls_id:<12} ")
        sys.stdout.flush()
        try:
            raw  = _fetch(dcss_path)
            out  = _make_portrait(raw, bg_top, bg_bot, accent)
            path = os.path.join(PORTRAITS_DIR, f"{cls_id}.png")
            out.save(path)
            print(f"✓  {os.path.getsize(path):>7,} b")
        except (URLError, HTTPError, OSError) as e:
            print(f"FAIL: {e}")
            failed.append(f"portrait:{cls_id}")

    if failed:
        print(f"\n⚠  {len(failed)} sprite(s) failed: {', '.join(failed)}")
        print("   The game will use fallback glyphs for missing sprites.")
    else:
        print("\nAll sprites generated successfully.")


if __name__ == "__main__":
    main()
