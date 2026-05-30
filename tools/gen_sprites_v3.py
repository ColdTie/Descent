#!/usr/bin/env python3
"""DESCENT — Sprite Fetcher v3

Downloads Dungeon Crawl: Stone Soup sprites (CC0 license) from GitHub and
processes them for DESCENT's battle scene. All sprites start as 32×32 pixel
art and are scaled to 96×96 with NEAREST interpolation for a crispy look.
Portraits are 5× scaled (160×160) on class-specific gradient backgrounds.

DCSS credit: Dungeon Crawl: Stone Soup contributors — CC0 1.0 Universal
"""

import os, sys
from io import BytesIO
from urllib.request import urlopen, Request
from urllib.error import URLError
from PIL import Image, ImageDraw, ImageFilter

DCSS_BASE = "https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/source/rltiles"
ROOT = os.path.dirname(os.path.abspath(__file__))
SPRITES_DIR  = os.path.join(ROOT, "..", "assets", "sprites")
PORTRAITS_DIR = os.path.join(ROOT, "..", "assets", "portraits")

# ── Battle sprite mapping: output_name → DCSS path ───────────────────────────
BATTLE_MAP: dict[str, str] = {
    # Heroes — three playable classes
    "hero_brawler":  "mon/humanoids/humans/death_knight.png",  # armored heavy fighter
    "hero_rogue":    "mon/humanoids/humans/occultist.png",     # shadowy human
    "hero_arcanist": "mon/humanoids/humans/arcanist.png",      # wizard with staff

    # Regular enemies
    "enemy_imp":      "mon/demons/crimson_imp.png",           # small red demon
    "enemy_goblin":   "mon/humanoids/goblin.png",             # green goblin
    "enemy_skeleton": "mon/undead/skeletal_warrior.png",      # undead warrior
    "enemy_demon":    "mon/demons/orange_demon.png",          # large demon grunt
    "enemy_golem":    "mon/nonliving/blazeheart_golem.png",   # lava golem

    # Boss encounters (one per 6-floor tier)
    "enemy_boss_dungeon_lord":  "mon/unique/dispater.png",          # Lord of the Dungeon
    "enemy_boss_warden":        "mon/humanoids/humans/vault_warden.png",  # The Warden
    "enemy_boss_abyss_keeper":  "mon/unique/ereshkigal.png",        # Queen of the Abyss
    "enemy_boss":               "mon/unique/cerebov.png",           # generic boss fallback
}

# ── Portrait config: class → (dcss_path, bg_top_rgb, bg_bot_rgb, accent_rgb) ─
PORTRAIT_MAP: dict[str, tuple] = {
    "brawler": (
        "mon/humanoids/humans/death_knight.png",
        (34, 22, 48), (72, 36, 18),   # dark purple → rust
        (220, 100, 30),               # orange accent
    ),
    "rogue": (
        "mon/humanoids/humans/occultist.png",
        (14, 6, 24), (32, 16, 50),    # near-black → dark violet
        (138, 96, 218),               # purple accent
    ),
    "arcanist": (
        "mon/humanoids/humans/arcanist.png",
        (16, 6, 36), (26, 10, 58),    # midnight blue-violet
        (168, 110, 255),              # arcane purple accent
    ),
}

BATTLE_SIZE  = 96   # final battle sprite px
PORTRAIT_PX  = 5    # NEAREST scale factor for portrait (32*5=160)
PW, PH       = 200, 190


# ── Network helpers ────────────────────────────────────────────────────────────

def fetch(dcss_path: str) -> Image.Image:
    url = f"{DCSS_BASE}/{dcss_path}"
    req = Request(url, headers={"User-Agent": "descent-sprite-fetcher/3"})
    with urlopen(req, timeout=15) as r:
        return Image.open(BytesIO(r.read())).convert("RGBA")


# ── Processing ─────────────────────────────────────────────────────────────────

def make_battle_sprite(img: Image.Image) -> Image.Image:
    """Scale 32×32 DCSS sprite to 96×96 with NEAREST — crispy pixel art."""
    if img.size != (32, 32):
        img = img.resize((32, 32), Image.LANCZOS)
    return img.resize((BATTLE_SIZE, BATTLE_SIZE), Image.NEAREST)


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


def _add_glow(canvas: Image.Image, cx: int, cy: int, radius: int, col: tuple) -> Image.Image:
    glow = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    cr, cg, cb = col[:3]
    for i in range(4, 0, -1):
        r2 = radius * i // 2
        al = min(255, 70 * i // 4)
        d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(cr, cg, cb, al))
    blurred = glow.filter(ImageFilter.GaussianBlur(radius // 2))
    return Image.alpha_composite(canvas, blurred)


def make_portrait(img: Image.Image, bg_top: tuple, bg_bot: tuple, accent: tuple) -> Image.Image:
    """200×190 portrait: gradient bg + centered 5× pixel-art sprite + accent strip."""
    SPRITE_PX = 32 * PORTRAIT_PX  # 160

    canvas = _gradient_bg(bg_top, bg_bot)

    # subtle glow centered behind sprite
    canvas = _add_glow(canvas, PW // 2, PH // 2 - 5, 72, accent)

    # scale sprite 5× with NEAREST
    scaled = img.resize((SPRITE_PX, SPRITE_PX), Image.NEAREST)

    # paste centered horizontally, nudged up a few pixels
    sx = (PW - SPRITE_PX) // 2      # 20
    sy = (PH - SPRITE_PX) // 2 - 8  # 7
    canvas.paste(scaled, (sx, sy), scaled)

    # accent strip at bottom (class color identifier)
    d = ImageDraw.Draw(canvas)
    cr, cg, cb = accent
    d.rectangle([0, PH - 13, PW, PH], fill=(cr // 2, cg // 2, cb // 2, 255))
    d.rectangle([0, PH - 13, PW, PH - 11], fill=(cr, cg, cb, 255))

    # subtle pixel-art border on all sides
    d.rectangle([0, 0, PW - 1, 0], fill=(cr, cg, cb, 180))
    d.rectangle([0, 0, 0, PH - 1], fill=(cr, cg, cb, 180))
    d.rectangle([PW - 1, 0, PW - 1, PH - 1], fill=(cr, cg, cb, 180))

    return canvas


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    os.makedirs(SPRITES_DIR, exist_ok=True)
    os.makedirs(PORTRAITS_DIR, exist_ok=True)

    print("=== Battle Sprites (DCSS CC0 → 96×96 NEAREST) ===")
    for name, dcss_path in BATTLE_MAP.items():
        sys.stdout.write(f"  {name:<35} ← {dcss_path.split('/')[-1]}  ")
        sys.stdout.flush()
        try:
            img = fetch(dcss_path)
            out = make_battle_sprite(img)
            out_path = os.path.join(SPRITES_DIR, f"{name}.png")
            out.save(out_path)
            print(f"✓  {os.path.getsize(out_path):>6,} b")
        except (URLError, OSError) as e:
            print(f"FAIL: {e}")
            sys.exit(1)

    print("\n=== Class Portraits (160×160 pixel-art on 200×190 bg) ===")
    for name, (dcss_path, bg_top, bg_bot, accent) in PORTRAIT_MAP.items():
        sys.stdout.write(f"  {name:<12} ")
        sys.stdout.flush()
        try:
            img = fetch(dcss_path)
            out = make_portrait(img, bg_top, bg_bot, accent)
            out_path = os.path.join(PORTRAITS_DIR, f"{name}.png")
            out.save(out_path)
            print(f"✓  {os.path.getsize(out_path):>6,} b")
        except (URLError, OSError) as e:
            print(f"FAIL: {e}")
            sys.exit(1)


if __name__ == "__main__":
    main()
