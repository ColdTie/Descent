#!/usr/bin/env python3
"""DESCENT — Sprite Generator v6
DCSS CC0 pixel art: all 12 sprites via verified GitHub paths.
4× NEAREST scale → 192×192 canvas with pixel outline + ground shadow.
Dramatic 200×220 class portraits with atmospheric glow backgrounds.

Attribution: Dungeon Crawl: Stone Soup contributors — CC0 1.0 Universal
  https://github.com/crawl/crawl
"""

import os, sys, math
from io import BytesIO
from urllib.request import urlopen, Request
from urllib.error import URLError
from PIL import Image, ImageDraw, ImageFilter

DCSS_BASE = "https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/source/rltiles"
ROOT = os.path.dirname(os.path.abspath(__file__))
SPRITES_DIR  = os.path.join(ROOT, "..", "assets", "sprites")
PORTRAITS_DIR = os.path.join(ROOT, "..", "assets", "portraits")

# All paths verified against GitHub directory listing 2024.
BATTLE_MAP: dict[str, str] = {
    "hero_brawler":            "mon/humanoids/humans/death_knight.png",
    "hero_rogue":              "mon/humanoids/humans/occultist.png",
    "hero_arcanist":           "mon/humanoids/humans/arcanist.png",
    "enemy_imp":               "mon/demons/crimson_imp.png",
    "enemy_goblin":            "mon/humanoids/goblin.png",
    "enemy_skeleton":          "mon/undead/skeletal_warrior.png",
    "enemy_demon":             "mon/demons/orange_demon.png",
    "enemy_golem":             "mon/nonliving/blazeheart_golem.png",
    "enemy_boss_dungeon_lord": "mon/unique/dispater.png",
    "enemy_boss_warden":       "mon/humanoids/humans/vault_warden.png",
    "enemy_boss_abyss_keeper": "mon/unique/ereshkigal.png",
    "enemy_boss":              "mon/unique/cerebov.png",
}

PORTRAIT_MAP: dict[str, dict] = {
    "brawler": {
        "dcss":    "mon/humanoids/humans/death_knight.png",
        "bg_top":  (28,  8,  4),
        "bg_bot":  (62, 22,  8),
        "glow":    (200, 55, 12),
        "accent":  (220, 80, 20),
    },
    "rogue": {
        "dcss":    "mon/humanoids/humans/occultist.png",
        "bg_top":  ( 6,  3, 16),
        "bg_bot":  (18,  8, 40),
        "glow":    (100, 55, 200),
        "accent":  (130, 80, 225),
    },
    "arcanist": {
        "dcss":    "mon/humanoids/humans/arcanist.png",
        "bg_top":  ( 4,  6, 28),
        "bg_bot":  (10, 18, 62),
        "glow":    ( 55, 115, 240),
        "accent":  ( 75, 155, 255),
    },
}

SPRITE_SCALE = 4          # 32 → 128 px (crispy pixel art)
CANVAS_W, CANVAS_H = 192, 192
PORTRAIT_W, PORTRAIT_H = 200, 220


# ── Network ────────────────────────────────────────────────────────────────────

def fetch(dcss_path: str) -> Image.Image:
    url = f"{DCSS_BASE}/{dcss_path}"
    req = Request(url, headers={"User-Agent": "descent-sprites/6"})
    with urlopen(req, timeout=20) as r:
        return Image.open(BytesIO(r.read())).convert("RGBA")


# ── Processing ─────────────────────────────────────────────────────────────────

def add_outline(img: Image.Image, thickness: int = 2) -> Image.Image:
    """Add a dark pixel outline around all non-transparent areas."""
    w, h = img.size
    px = img.load()
    outline = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out = outline.load()
    dark = (8, 4, 12, 215)

    for x in range(w):
        for y in range(h):
            if px[x, y][3] < 50:
                # transparent — outline it if any neighbor is opaque
                for dx in range(-thickness, thickness + 1):
                    for dy in range(-thickness, thickness + 1):
                        if dx == 0 and dy == 0:
                            continue
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 50:
                            out[x, y] = dark
                            break
                    else:
                        continue
                    break

    result = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    result.paste(outline, (0, 0))
    result.paste(img, (0, 0), img)
    return result


def make_battle_sprite(raw: Image.Image) -> Image.Image:
    """
    Scale DCSS sprite 4× with NEAREST, add pixel outline, center on
    192×192 transparent canvas. Handles both 32×32 and 32×48 boss sprites.
    """
    sw = raw.width  * SPRITE_SCALE
    sh = raw.height * SPRITE_SCALE

    # For tall sprites (128×192), scale down so they fit with a small margin
    margin = 6
    if sh > CANVAS_H - margin:
        factor = (CANVAS_H - margin) / sh
        sw = max(1, int(sw * factor))
        sh = max(1, int(sh * factor))
    if sw > CANVAS_W - margin:
        factor = (CANVAS_W - margin) / sw
        sh = max(1, int(sh * factor))
        sw = max(1, int(sw * factor))

    scaled   = raw.resize((sw, sh), Image.NEAREST)
    outlined = add_outline(scaled, thickness=2)

    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))

    # Soft oval ground shadow
    ox = (CANVAS_W - sw) // 2
    oy = CANVAS_H - sh - 3
    shadow_layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    cx = ox + sw // 2
    sy = oy + sh - 2
    sr = sw // 3
    sd.ellipse([cx - sr, sy - 5, cx + sr, sy + 10], fill=(0, 0, 0, 105))
    canvas = Image.alpha_composite(canvas, shadow_layer.filter(ImageFilter.GaussianBlur(5)))
    canvas.paste(outlined, (ox, oy), outlined)
    return canvas


def _gradient(w: int, h: int, top: tuple, bot: tuple) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        d.line([(0, y), (w, y)], fill=(r, g, b, 255))
    return img


def _glow(w: int, h: int, cx: int, cy: int, radius: int, col: tuple) -> Image.Image:
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r, g, b = col[:3]
    for i in range(7, 0, -1):
        ri = radius * i // 5
        alpha = int(38 * i / 7)
        d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=(r, g, b, alpha))
    return layer.filter(ImageFilter.GaussianBlur(radius // 4))


def make_portrait(raw: Image.Image, cfg: dict) -> Image.Image:
    PW, PH = PORTRAIT_W, PORTRAIT_H

    canvas = _gradient(PW, PH, cfg["bg_top"], cfg["bg_bot"])

    # Main atmospheric glow (large, centered)
    canvas = Image.alpha_composite(canvas,
        _glow(PW, PH, PW // 2, PH // 2 - 10, 100, cfg["glow"]))
    # Focused glow higher up (emanates from character head)
    canvas = Image.alpha_composite(canvas,
        _glow(PW, PH, PW // 2, PH // 3, 55, cfg["glow"]))

    # Vignette corners
    vig = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)
    for i in range(22):
        alpha = int(140 * (i / 22) ** 1.6)
        vd.rectangle([i, i, PW - i - 1, PH - i - 1],
                     outline=(0, 0, 0, max(0, 170 - alpha)))
    canvas = Image.alpha_composite(canvas, vig.filter(ImageFilter.GaussianBlur(5)))

    # Scale sprite (6× NEAREST, capped to fit portrait)
    SCALE = 6
    sw = raw.width  * SCALE
    sh = raw.height * SCALE
    max_h = int(PH * 0.80)
    max_w = int(PW * 0.86)
    if sh > max_h:
        f = max_h / sh; sw = int(sw * f); sh = int(sh * f)
    if sw > max_w:
        f = max_w / sw; sh = int(sh * f); sw = int(sw * f)

    scaled = raw.resize((sw, sh), Image.NEAREST)

    # Ground shadow beneath sprite
    sx = (PW - sw) // 2
    sy = PH - sh - 20
    shad = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    shd = ImageDraw.Draw(shad)
    scx = sx + sw // 2
    shd.ellipse([scx - sw // 2, sy + sh - 6,
                 scx + sw // 2, sy + sh + 16],
                fill=(0, 0, 0, 135))
    canvas = Image.alpha_composite(canvas, shad.filter(ImageFilter.GaussianBlur(9)))

    # Paste sprite
    canvas.paste(scaled, (sx, sy), scaled)

    # Accent border strips (top + bottom bars, thin side lines)
    d = ImageDraw.Draw(canvas)
    acc = cfg["accent"]
    d.rectangle([0, 0,     PW,     4], fill=(*acc, 255))
    d.rectangle([0, PH - 4, PW,   PH], fill=(*acc, 255))
    d.rectangle([0, 0,       2,   PH], fill=(*acc, 120))
    d.rectangle([PW - 2, 0, PW,   PH], fill=(*acc, 120))

    return canvas


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    os.makedirs(SPRITES_DIR,   exist_ok=True)
    os.makedirs(PORTRAITS_DIR, exist_ok=True)

    print("=== DESCENT Sprite Generator v6 (DCSS CC0 → 192×192 pixel art) ===")
    print(f"  Scale: {SPRITE_SCALE}×  Filter: NEAREST  Canvas: {CANVAS_W}×{CANVAS_H}\n")

    errors: list[str] = []

    print("Battle sprites:")
    for name, dcss_path in BATTLE_MAP.items():
        sys.stdout.write(f"  {name:<35}  ")
        sys.stdout.flush()
        try:
            raw    = fetch(dcss_path)
            sprite = make_battle_sprite(raw)
            out    = os.path.join(SPRITES_DIR, f"{name}.png")
            sprite.save(out)
            print(f"✓  {raw.size} raw → {CANVAS_W}×{CANVAS_H}  ({os.path.getsize(out):,}b)")
        except (URLError, OSError, Exception) as e:
            print(f"FAIL: {e}")
            errors.append(name)

    print("\nClass portraits (200×220):")
    for name, cfg in PORTRAIT_MAP.items():
        sys.stdout.write(f"  {name:<12}  ")
        sys.stdout.flush()
        try:
            raw     = fetch(cfg["dcss"])
            portrait = make_portrait(raw, cfg)
            out      = os.path.join(PORTRAITS_DIR, f"{name}.png")
            portrait.save(out)
            print(f"✓  ({os.path.getsize(out):,}b)")
        except (URLError, OSError, Exception) as e:
            print(f"FAIL: {e}")
            errors.append(f"portrait_{name}")

    if errors:
        print(f"\nFAILED: {', '.join(errors)}")
        sys.exit(1)
    print("\n✓ All sprites and portraits generated.")
    print("Attribution: DCSS contributors — CC0 1.0 Universal (https://github.com/crawl/crawl)")


if __name__ == "__main__":
    main()
