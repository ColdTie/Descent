#!/usr/bin/env python3
"""DESCENT — Ability Effect Sprite Generator
Generates 64×64 pixel-art VFX sprites for each combat ability.
Outputs: assets/effects/fx_*.png
"""

import os, math
from PIL import Image, ImageDraw, ImageFilter
import random

ROOT      = os.path.dirname(os.path.abspath(__file__))
OUT_DIR   = os.path.join(ROOT, "..", "assets", "effects")
W, H      = 64, 64
CX, CY    = W // 2, H // 2

# ── helpers ──────────────────────────────────────────────────────────────────

def canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))

def radial_glow(img, cx, cy, r_max, color, exponent=0.6):
    d = ImageDraw.Draw(img)
    r, g, b = color
    for r_i in range(r_max, 0, -1):
        alpha = int(200 * (r_i / r_max) ** exponent)
        d.ellipse([cx - r_i, cy - r_i, cx + r_i, cy + r_i], fill=(r, g, b, alpha))
    return img

def sparks(img, cx, cy, count, dist_min, dist_max, color, seed=42):
    px = img.load()
    rng = random.Random(seed)
    for _ in range(count):
        angle = rng.uniform(0, 2 * math.pi)
        dist  = rng.uniform(dist_min, dist_max)
        x = int(cx + dist * math.cos(angle))
        y = int(cy + dist * math.sin(angle))
        if 0 <= x < W and 0 <= y < H:
            r, g, b, a = color
            px[x, y] = (r, g, b, a)
    return img

def save(img, name):
    path = os.path.join(OUT_DIR, name)
    img.save(path)
    print(f"  {name:<30} {os.path.getsize(path):>6} bytes")

# ── effects ──────────────────────────────────────────────────────────────────

def make_fireball():
    img = canvas()
    d = ImageDraw.Draw(img)
    # Outer flame halo
    for r_i in range(30, 0, -1):
        t = r_i / 30
        red   = 255
        green = int(100 * (1 - t) + 30 * t)
        alpha = int(190 * (r_i / 30) ** 0.55)
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i], fill=(red, green, 0, alpha))
    # White-yellow core
    for r_i in range(12, 0, -1):
        t = 1 - r_i / 12
        green = int(255 * (1 - t * 0.3))
        blue  = int(200 * (1 - t))
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i], fill=(255, green, blue, 255))
    sparks(img, CX, CY, 22, 22, 31, (255, 220, 60, 255))
    return img.filter(ImageFilter.GaussianBlur(0.6))

def make_frost():
    img = canvas()
    d   = ImageDraw.Draw(img)
    px  = img.load()
    # Faint blue glow ring
    for r_i in range(28, 18, -1):
        alpha = int(80 * (28 - r_i) / 10)
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i], fill=(80, 160, 255, alpha))
    # Six snowflake arms
    for arm in range(6):
        angle = math.radians(arm * 60)
        for t_i in range(1, 27):
            t = t_i / 26.0
            r = t * 27
            x = int(CX + r * math.cos(angle))
            y = int(CY + r * math.sin(angle))
            if 0 <= x < W and 0 <= y < H:
                bright = int(255 * (1 - t * 0.45))
                px[x, y] = (bright, bright + 8, 255, int(255 * (1 - t * 0.55)))
            # Side branches every 5 steps
            if t_i % 5 == 0:
                for side in (-1, 1):
                    ba = angle + side * math.pi / 3
                    bx = int(x + 5 * math.cos(ba))
                    by = int(y + 5 * math.sin(ba))
                    if 0 <= bx < W and 0 <= by < H:
                        px[bx, by] = (180, 220, 255, 200)
    # Bright core
    for r_i in range(7, 0, -1):
        t = 1 - r_i / 7
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i],
                  fill=(180, 220, 255, int(255 * (0.4 + 0.6 * t))))
    d.ellipse([CX - 3, CY - 3, CX + 3, CY + 3], fill=(255, 255, 255, 255))
    return img

def make_impact():
    """White-orange starburst for basic/physical attacks."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    px  = img.load()
    # 8 starburst rays
    for ray in range(8):
        angle = math.radians(ray * 45 + 22.5)
        for t_i in range(1, 29):
            t = t_i / 28.0
            r = t * 28
            x = int(CX + r * math.cos(angle))
            y = int(CY + r * math.sin(angle))
            if 0 <= x < W and 0 <= y < H:
                orange = int(255 - 100 * t)
                alpha  = int(255 * (1 - t))
                px[x, y] = (255, orange, int(30 * (1 - t)), alpha)
    # 4 cardinal rays (shorter)
    for ray in range(4):
        angle = math.radians(ray * 90)
        for t_i in range(1, 20):
            t = t_i / 19.0
            x = int(CX + t * 20 * math.cos(angle))
            y = int(CY + t * 20 * math.sin(angle))
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = (255, 200, 50, int(200 * (1 - t)))
    # White core
    for r_i in range(9, 0, -1):
        t = 1 - r_i / 9
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i],
                  fill=(255, 255, int(180 * (1 - t)), int(255 * (0.4 + 0.6 * t))))
    d.ellipse([CX - 4, CY - 4, CX + 4, CY + 4], fill=(255, 255, 255, 255))
    return img

def make_backstab():
    """Sharp red-black X slash for backstab."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    px  = img.load()
    # Dark-red glow
    radial_glow(img, CX, CY, 26, (180, 0, 10), 0.5)
    # Two diagonal slash lines
    for slash in range(2):
        angle = math.radians(45 + slash * 90)
        for t_i in range(-22, 23):
            t = t_i / 22.0
            x = int(CX + t_i * math.cos(angle))
            y = int(CY + t_i * math.sin(angle))
            if 0 <= x < W and 0 <= y < H:
                edge = abs(t)
                alpha = int(255 * (1 - edge * 0.7))
                red   = 255
                px[x, y]     = (red, 20, 20, alpha)
                # Thicken line
                for perp_d in (-1, 1):
                    pa = angle + math.pi / 2
                    nx = int(x + perp_d * math.cos(pa))
                    ny = int(y + perp_d * math.sin(pa))
                    if 0 <= nx < W and 0 <= ny < H:
                        px[nx, ny] = (255, 60, 60, int(alpha * 0.6))
    sparks(img, CX, CY, 10, 18, 28, (255, 100, 80, 255), seed=17)
    return img

def make_power_strike():
    """Golden starburst for heavy melee hits."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    px  = img.load()
    radial_glow(img, CX, CY, 28, (200, 140, 10), 0.5)
    for ray in range(6):
        angle = math.radians(ray * 60)
        for t_i in range(1, 30):
            t = t_i / 29.0
            x = int(CX + t * 30 * math.cos(angle))
            y = int(CY + t * 30 * math.sin(angle))
            if 0 <= x < W and 0 <= y < H:
                gold  = int(255 * (1 - t * 0.5))
                alpha = int(255 * (1 - t))
                px[x, y] = (255, gold, 0, alpha)
    for r_i in range(10, 0, -1):
        t = 1 - r_i / 10
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i],
                  fill=(255, int(220 * (0.5 + 0.5 * t)), 0, int(255 * (0.4 + 0.6 * t))))
    d.ellipse([CX - 4, CY - 4, CX + 4, CY + 4], fill=(255, 255, 200, 255))
    return img

def make_heal():
    """Green cross with glowing radial aura."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    radial_glow(img, CX, CY, 26, (20, 160, 60), 0.55)
    # Plus cross
    d.rectangle([CX - 4, CY - 15, CX + 4, CY + 15], fill=(60, 255, 110, 255))
    d.rectangle([CX - 15, CY - 4, CX + 15, CY + 4], fill=(60, 255, 110, 255))
    d.rectangle([CX - 5, CY - 5, CX + 5, CY + 5],   fill=(200, 255, 210, 255))
    sparks(img, CX, CY, 14, 16, 28, (120, 255, 150, 255))
    return img

def make_poison():
    """Sickly green-purple bubbles."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    radial_glow(img, CX, CY, 24, (30, 140, 30), 0.6)
    bubbles = [(CX, CY, 11), (CX - 12, CY - 8, 6), (CX + 10, CY - 6, 7),
               (CX - 7, CY + 13, 5), (CX + 9, CY + 11, 6)]
    for bx, by, br in bubbles:
        d.ellipse([bx - br, by - br, bx + br, by + br],
                  fill=(25, 145, 25, 200), outline=(100, 255, 100, 255))
        d.ellipse([bx - br // 3, by - br // 2, bx + br // 4, by],
                  fill=(180, 255, 180, 110))
    return img

def make_vanish():
    """Swirling purple-dark smoke."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    clouds = [
        (CX, CY, 22), (CX - 9, CY - 11, 14), (CX + 11, CY - 9, 13),
        (CX - 13, CY + 8, 10), (CX + 9, CY + 13, 11), (CX, CY - 19, 9),
    ]
    for sx, sy, sr in clouds:
        for r_i in range(sr, 0, -1):
            alpha = int(85 * (r_i / sr) ** 0.5)
            d.ellipse([sx - r_i, sy - r_i, sx + r_i, sy + r_i], fill=(110, 0, 170, alpha))
    sparks(img, CX, CY, 16, 9, 27, (190, 80, 255, 200), seed=7)
    return img.filter(ImageFilter.GaussianBlur(1.5))

def make_taunt():
    """Bold red shield with exclamation mark."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    radial_glow(img, CX, CY, 26, (200, 20, 20), 0.5)
    # Shield outline (pentagon-ish, point at bottom)
    r = 21
    pts = []
    for i in range(5):
        a = math.radians(i * 72 - 90)
        pts.append((CX + int(r * math.cos(a)), CY + int(r * math.sin(a))))
    shield = [pts[0], pts[1], pts[2], (CX, CY + 26), pts[3], pts[4]]
    d.polygon(shield, fill=(170, 15, 15, 225), outline=(255, 70, 70, 255))
    # Exclamation
    d.rectangle([CX - 2, CY - 12, CX + 2, CY + 3],  fill=(255, 215, 215, 255))
    d.rectangle([CX - 2, CY + 6,  CX + 2, CY + 10], fill=(255, 215, 215, 255))
    return img

def make_shadow_step():
    """Deep violet teleport blink — afterimage ring with dark sparks."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    px  = img.load()
    # Outer ring of the blink — deep violet
    for r_i in range(29, 18, -1):
        alpha = int(130 * (r_i - 18) / 11)
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i], fill=(80, 0, 140, alpha))
    # Inner ring — bright magenta
    for r_i in range(18, 10, -1):
        alpha = int(210 * (r_i - 10) / 8)
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i], fill=(160, 0, 220, alpha))
    # 6 sharp dark-violet rays outward
    for ray in range(6):
        angle = math.radians(ray * 60 + 15)
        for t_i in range(1, 27):
            t = t_i / 26.0
            x = int(CX + t * 27 * math.cos(angle))
            y = int(CY + t * 27 * math.sin(angle))
            if 0 <= x < W and 0 <= y < H:
                alpha = int(240 * (1 - t))
                px[x, y] = (120, 0, 200, alpha)
    # Bright white-violet core
    for r_i in range(8, 0, -1):
        t = 1 - r_i / 8
        d.ellipse([CX - r_i, CY - r_i, CX + r_i, CY + r_i],
                  fill=(200, 80, 255, int(255 * (0.5 + 0.5 * t))))
    d.ellipse([CX - 3, CY - 3, CX + 3, CY + 3], fill=(255, 240, 255, 255))
    sparks(img, CX, CY, 14, 14, 28, (200, 60, 255, 220), seed=99)
    return img.filter(ImageFilter.GaussianBlur(0.7))

def make_lava_heat():
    """Orange upward flame wisps for lava heat damage."""
    img = canvas()
    d   = ImageDraw.Draw(img)
    px  = img.load()
    rng = random.Random(13)
    # Three flame columns
    for col, cx_off in enumerate([-12, 0, 12]):
        flicker = rng.uniform(-3, 3)
        for y_i in range(28, 0, -1):
            t = y_i / 28
            x = int(CX + cx_off + flicker * math.sin(y_i * 0.5))
            y = int(CY + 6 - y_i)
            if 0 <= x < W and 0 <= y < H:
                red   = 255
                green = int(180 * (1 - t * 0.6))
                alpha = int(230 * (1 - t * 0.7))
                px[x, y] = (red, green, 0, alpha)
                # Widen flame base
                if y_i > 12:
                    for dx in range(-2, 3):
                        nx = x + dx
                        if 0 <= nx < W:
                            px[nx, y] = (255, max(0, green - 20 * abs(dx)), 0, int(alpha * (1 - abs(dx) * 0.25)))
    return img.filter(ImageFilter.GaussianBlur(0.8))

# ── main ─────────────────────────────────────────────────────────────────────

EFFECTS = [
    ("fx_fireball.png",     make_fireball),
    ("fx_frost.png",        make_frost),
    ("fx_impact.png",       make_impact),
    ("fx_backstab.png",     make_backstab),
    ("fx_power_strike.png", make_power_strike),
    ("fx_heal.png",         make_heal),
    ("fx_poison.png",       make_poison),
    ("fx_vanish.png",       make_vanish),
    ("fx_taunt.png",        make_taunt),
    ("fx_lava_heat.png",    make_lava_heat),
    ("fx_shadow_step.png",  make_shadow_step),
]

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"=== DESCENT Effect Generator — {len(EFFECTS)} effects → {OUT_DIR} ===")
    for name, fn in EFFECTS:
        save(fn(), name)
    print(f"\n✓ Done.")

if __name__ == "__main__":
    main()
