#!/usr/bin/env python3
"""DESCENT — Sprite Generator v2

Better proportions (heads ~24% of height), more saturated colors,
stronger outlines, and new 200×190 portrait images for ClassSelect.

Outputs:
  assets/sprites/   — 96×96 battle sprites (overwrites existing)
  assets/portraits/ — 200×190 portrait images (new)
"""

import os, math
from PIL import Image, ImageDraw, ImageFilter

# ── Canvas sizes ─────────────────────────────────────────────────────────────
BASE     = 96
BSCALE   = 5
BR       = BASE * BSCALE          # 480 internal battle canvas

PW_OUT   = 200
PH_OUT   = 190
PSCALE   = 5
PW       = PW_OUT * PSCALE        # 1000 portrait width
PH       = PH_OUT * PSCALE        # 950 portrait height

ROOT         = os.path.dirname(__file__)
SPRITES_DIR  = os.path.join(ROOT, "..", "assets", "sprites")
PORTRAITS_DIR= os.path.join(ROOT, "..", "assets", "portraits")

# ── Coordinate helpers ───────────────────────────────────────────────────────
def s(v):       return int(v * BSCALE)
def sb(b):      return [s(v) for v in b]
def sp(pairs):  return [(s(x), s(y)) for x, y in pairs]
def ps(v):      return int(v * PSCALE)
def psb(b):     return [ps(v) for v in b]
def psp(pairs): return [(ps(x), ps(y)) for x, y in pairs]

# ── Canvas factories ─────────────────────────────────────────────────────────
def bc(): return Image.new("RGBA", (BR, BR), (0, 0, 0, 0))
def pc(): return Image.new("RGBA", (PW, PH), (0, 0, 0, 0))

# ── Glow helper (works for any canvas size / scale) ─────────────────────────
def _glow(img, cx, cy, r, col, sc, passes=3):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d   = ImageDraw.Draw(lay)
    cr, cg, cb = col[:3]
    for i in range(passes, 0, -1):
        r2 = int(r * sc) * (i + 1) // 2
        al = min(255, 105 * i // passes)
        cx_, cy_ = int(cx * sc), int(cy * sc)
        d.ellipse([cx_ - r2, cy_ - r2, cx_ + r2, cy_ + r2], fill=(cr, cg, cb, al))
    blurred = lay.filter(ImageFilter.GaussianBlur(max(1, int(r * sc) * 0.5)))
    return Image.alpha_composite(img, blurred)

def bg(img, cx, cy, r, col, passes=3):  return _glow(img, cx, cy, r, col, BSCALE, passes)
def pg(img, cx, cy, r, col, passes=3):  return _glow(img, cx, cy, r, col, PSCALE, passes)

# ── Outline + resize ─────────────────────────────────────────────────────────
def add_outline(img, thick=7, border=(5, 2, 8, 255)):
    alpha    = img.getchannel("A")
    expanded = alpha.filter(ImageFilter.MaxFilter(thick))
    out      = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ep, ap, op = expanded.load(), alpha.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            if ep[x, y] > 0 and ap[x, y] < 30:
                op[x, y] = border
    res = Image.new("RGBA", img.size, (0, 0, 0, 0))
    res.paste(out)
    res.paste(img, (0, 0), img)
    return res

def fin_sprite(img):
    return add_outline(img, thick=7).resize((BASE, BASE), Image.LANCZOS)

def fin_portrait(img):
    return add_outline(img, thick=9, border=(3, 1, 6, 255)).resize(
        (PW_OUT, PH_OUT), Image.LANCZOS)

# ── Portrait background helper ────────────────────────────────────────────────
def portrait_bg(top_col, bot_col):
    """Gradient background for portrait."""
    img = pc()
    d   = ImageDraw.Draw(img)
    for y in range(PH):
        t = y / PH
        r = int(top_col[0] * (1-t) + bot_col[0] * t)
        g = int(top_col[1] * (1-t) + bot_col[1] * t)
        b = int(top_col[2] * (1-t) + bot_col[2] * t)
        d.line([(0, y), (PW, y)], fill=(r, g, b, 255))
    return img

# ── Save helpers ─────────────────────────────────────────────────────────────
def save_sprite(img, name):
    os.makedirs(SPRITES_DIR, exist_ok=True)
    path = os.path.join(SPRITES_DIR, name + ".png")
    fin_sprite(img).save(path)
    print(f"  sprites/{name}.png  ({os.path.getsize(path):,} bytes)")

def save_portrait(img, name):
    os.makedirs(PORTRAITS_DIR, exist_ok=True)
    path = os.path.join(PORTRAITS_DIR, name + ".png")
    fin_portrait(img).save(path)
    print(f"  portraits/{name}.png  ({os.path.getsize(path):,} bytes)")


# ════════════════════════════════════════════════════════════════════════════
# HERO: BRAWLER
# Stocky fighter, black tank top, jeans, boots, stubble, raised fists.
# Head = 24% of height for proper proportions.
# ════════════════════════════════════════════════════════════════════════════

def hero_brawler_sprite():
    SKIN   = (215, 148, 90);  SKIN_H = (242, 178, 120);  SKIN_D = (155, 96, 50)
    HAIR   = (18,  10,  4)
    SHIRT  = (24,  24,  24);  SHIRT_H= (46,  46,  46)
    JEANS  = (38,  54,  108); JEANS_H= (58,  76,  136)
    BOOT   = (16,  10,  6);   BOOT_H = (30,  20,  12)
    BELT   = (54,  36,  14);  BUCKLE = (122, 86,  26)

    img = bc(); d = ImageDraw.Draw(img)

    # shadow
    d.ellipse(sb([16, 88, 80, 95]), fill=(0, 0, 0, 50))

    # BOOTS
    for bx in [(23, 43), (53, 73)]:
        d.rounded_rectangle(sb([bx[0], 81, bx[1], 96]), radius=s(4), fill=BOOT)
        d.rectangle(sb([bx[0], 81, bx[0]+6, 88]), fill=BOOT_H)

    # LEGS
    for lx in [(24, 44), (52, 72)]:
        d.rounded_rectangle(sb([lx[0], 60, lx[1], 84]), radius=s(5), fill=JEANS)
        d.rectangle(sb([lx[0], 60, lx[0]+4, 84]), fill=JEANS_H)
        d.ellipse(sb([lx[0]+2, 68, lx[0]+16, 78]), fill=(50, 68, 122, 80))

    # BELT
    d.rounded_rectangle(sb([21, 56, 75, 63]), radius=s(2), fill=BELT)
    d.rectangle(sb([44, 54, 52, 65]), fill=(72, 50, 18))
    d.rectangle(sb([45, 56, 51, 63]), fill=BUCKLE)

    # TORSO — black tank top
    d.rounded_rectangle(sb([20, 26, 76, 59]), radius=s(5), fill=SHIRT)
    d.rectangle(sb([20, 26, 26, 59]), fill=SHIRT_H)
    d.rectangle(sb([70, 26, 76, 59]), fill=(12, 12, 12))
    d.polygon(sp([(36, 26), (60, 26), (48, 37)]), fill=(14, 14, 14))
    d.arc(sb([22, 29, 46, 50]), start=200, end=340, fill=(12, 12, 12), width=s(1))
    d.arc(sb([50, 29, 74, 50]), start=200, end=340, fill=(12, 12, 12), width=s(1))
    # tank straps
    d.rounded_rectangle(sb([27, 14, 37, 28]), radius=s(3), fill=SHIRT)
    d.rounded_rectangle(sb([59, 14, 69, 28]), radius=s(3), fill=SHIRT)

    # LEFT ARM — extended punch
    d.rounded_rectangle(sb([4, 26, 22, 52]), radius=s(7), fill=SKIN)
    d.rectangle(sb([4, 26, 10, 52]), fill=SKIN_H)
    # fist left
    d.rounded_rectangle(sb([2, 48, 22, 63]), radius=s(5), fill=SKIN_D)
    d.rectangle(sb([3, 49, 9, 62]), fill=SKIN)
    for ky in [51, 55, 59]: d.line(sp([(3, ky), (21, ky)]), fill=(98, 50, 18), width=s(1))

    # RIGHT ARM — raised guard
    d.rounded_rectangle(sb([74, 16, 92, 46]), radius=s(7), fill=SKIN)
    d.rectangle(sb([74, 16, 80, 46]), fill=SKIN_H)
    # fist right raised
    d.rounded_rectangle(sb([74, 12, 93, 26]), radius=s(5), fill=SKIN_D)
    d.rectangle(sb([75, 13, 81, 25]), fill=SKIN)
    for ky in [14, 18, 22]: d.line(sp([(75, ky), (92, ky)]), fill=(98, 50, 18), width=s(1))

    # NECK
    d.rounded_rectangle(sb([39, 14, 57, 27]), radius=s(4), fill=SKIN)

    # HEAD
    d.ellipse(sb([27, 1, 69, 27]), fill=SKIN)
    d.ellipse(sb([27, 1, 41, 16]), fill=SKIN_H)
    d.ellipse(sb([55, 3, 69, 19]), fill=SKIN_D)

    # cheek bruise
    bruise = Image.new("RGBA", (BR, BR), (0,0,0,0))
    bd = ImageDraw.Draw(bruise)
    bd.ellipse(sb([54, 16, 67, 25]), fill=(60, 28, 112, 65))
    img = Image.alpha_composite(img, bruise); d = ImageDraw.Draw(img)

    # HAIR
    d.ellipse(sb([25, 1, 71, 11]), fill=HAIR)
    d.ellipse(sb([23, 1, 36, 10]), fill=HAIR)
    d.ellipse(sb([60, 1, 73, 10]), fill=HAIR)

    # stubble
    d.rectangle(sb([36, 22, 60, 27]), fill=(26, 14, 6))

    # brows
    d.polygon(sp([(29, 10), (43, 13), (41, 15), (30, 12)]), fill=HAIR)
    d.polygon(sp([(67, 10), (53, 13), (55, 15), (66, 12)]), fill=HAIR)

    # eyes — brown intense
    for ex in [34, 52]:
        d.ellipse(sb([ex, 13, ex+11, 21]), fill=(8, 4, 1))
        d.ellipse(sb([ex+1, 14, ex+10, 20]), fill=(72, 40, 14))
        d.ellipse(sb([ex+2, 15, ex+9, 19]), fill=(110, 60, 18))
        d.ellipse(sb([ex+3, 15, ex+8, 19]), fill=(5, 3, 1))
        d.ellipse(sb([ex+1, 13, ex+3, 15]), fill=(255, 255, 255, 180))

    # nose
    d.ellipse(sb([43, 19, 53, 25]), fill=SKIN_D)
    d.ellipse(sb([43, 22, 46, 25]), fill=(92, 48, 18))
    d.ellipse(sb([50, 22, 53, 25]), fill=(92, 48, 18))

    # mouth — grim
    d.rectangle(sb([38, 25, 58, 28]), fill=(78, 28, 8))
    d.rectangle(sb([39, 25, 57, 26]), fill=(120, 46, 12))

    return img


def hero_brawler_portrait():
    SKIN  = (215, 148, 90); SKIN_H = (242, 178, 120); SKIN_D = (155, 96, 50)
    HAIR  = (18, 10, 4)
    SHIRT = (24, 24, 24); SHIRT_H = (48, 48, 48)
    JEANS = (38, 54, 108)

    img = portrait_bg((28, 18, 40), (50, 30, 14))

    # subtle class glow behind character
    img = pg(img, 100, 135, 80, (220, 100, 30), passes=3)
    d   = ImageDraw.Draw(img)

    # ── TORSO (visible at bottom of portrait) ───────────────────
    # Shoulders (wide)
    d.rounded_rectangle(psb([10, 130, 190, 190]), radius=ps(12), fill=SHIRT)
    d.rectangle(psb([10, 130, 20, 190]), fill=SHIRT_H)
    d.rectangle(psb([180, 130, 190, 190]), fill=(12, 12, 12))
    # v-neck
    d.polygon(psp([(60, 128), (140, 128), (100, 152)]), fill=(14, 14, 14))
    # tank straps
    d.rounded_rectangle(psb([46, 96, 66, 132]), radius=ps(5), fill=SHIRT)
    d.rounded_rectangle(psb([134, 96, 154, 132]), radius=ps(5), fill=SHIRT)
    # chest muscle lines
    d.arc(psb([16, 132, 92, 180]), start=205, end=335, fill=(12, 12, 12), width=ps(2))
    d.arc(psb([108, 132, 184, 180]), start=205, end=335, fill=(12, 12, 12), width=ps(2))

    # NECK
    d.rounded_rectangle(psb([82, 92, 118, 132]), radius=ps(8), fill=SKIN)
    d.rectangle(psb([82, 92, 96, 132]), fill=SKIN_H)

    # ── HEAD ─────────────────────────────────────────────────────
    d.ellipse(psb([28, 12, 172, 102]), fill=SKIN)
    d.ellipse(psb([28, 12, 76, 58]), fill=SKIN_H)
    d.ellipse(psb([124, 16, 172, 66]), fill=SKIN_D)

    # cheek bruise
    bruise = Image.new("RGBA", (PW, PH), (0,0,0,0))
    bd = ImageDraw.Draw(bruise)
    bd.ellipse(psb([118, 56, 158, 88]), fill=(65, 28, 112, 70))
    img = Image.alpha_composite(img, bruise); d = ImageDraw.Draw(img)

    # HAIR
    d.ellipse(psb([24, 10, 176, 44]), fill=HAIR)
    d.ellipse(psb([20, 10, 68, 38]), fill=HAIR)
    d.ellipse(psb([132, 10, 180, 38]), fill=HAIR)

    # Stubble
    d.rectangle(psb([62, 82, 138, 100]), fill=(26, 14, 6))

    # BROWS — thick and furrowed
    d.polygon(psp([(34, 42), (76, 52), (72, 60), (36, 52)]), fill=HAIR)
    d.polygon(psp([(166, 42), (124, 52), (128, 60), (164, 52)]), fill=HAIR)

    # EYES — intense brown
    for ex in [40, 112]:
        d.ellipse(psb([ex, 52, ex+44, 82]), fill=(8, 4, 1))
        d.ellipse(psb([ex+2, 54, ex+42, 80]), fill=(72, 40, 14))
        d.ellipse(psb([ex+5, 57, ex+38, 77]), fill=(112, 62, 18))
        d.ellipse(psb([ex+12, 60, ex+32, 74]), fill=(5, 3, 1))
        d.ellipse(psb([ex+4, 53, ex+14, 63]), fill=(255, 255, 255, 185))

    # NOSE
    d.ellipse(psb([84, 76, 116, 98]), fill=SKIN_D)
    d.ellipse(psb([84, 90, 96, 100]), fill=(92, 48, 18))
    d.ellipse(psb([104, 90, 116, 100]), fill=(92, 48, 18))

    # MOUTH — tight grim line
    d.rectangle(psb([66, 100, 134, 112]), fill=(78, 28, 8))
    d.rectangle(psb([68, 100, 132, 105]), fill=(122, 48, 14))

    # SCAR across left brow
    d.line(psp([(46, 44), (58, 56)]), fill=(130, 60, 28), width=ps(1))

    return img


# ════════════════════════════════════════════════════════════════════════════
# HERO: ROGUE
# Dark hooded figure, twin daggers, glowing teal eyes. Visible, not a black blob.
# ════════════════════════════════════════════════════════════════════════════

def hero_rogue_sprite():
    CLOAK  = (40, 22, 62);  CLOAK_H = (68, 44, 96);  CLOAK_D = (20, 10, 34)
    BLADE  = (210, 220, 235); BLADE_H = (242, 248, 255)
    BOOT   = (18, 12, 8)
    ACCENT = (138, 96, 218)
    SKIN   = (188, 148, 105)
    EYE_C  = (78, 228, 188)
    GUARD  = (98, 72, 22)   # dagger guard

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([22, 88, 74, 95]), fill=(0, 0, 0, 50))

    # BOOTS
    d.rounded_rectangle(sb([28, 80, 44, 96]), radius=s(4), fill=BOOT)
    d.rounded_rectangle(sb([52, 80, 68, 96]), radius=s(4), fill=BOOT)
    d.rectangle(sb([28, 80, 33, 88]), fill=(28, 20, 14))
    d.rectangle(sb([52, 80, 57, 88]), fill=(28, 20, 14))

    # CLOAK BODY — wider, clear silhouette
    d.polygon(sp([(14, 28), (82, 28), (86, 96), (10, 96)]), fill=CLOAK)
    # Left highlight strip
    d.polygon(sp([(14, 28), (30, 28), (26, 96), (10, 96)]), fill=CLOAK_H)
    d.rectangle(sb([14, 28, 20, 96]), fill=CLOAK_H)
    # Right shadow strip
    d.rectangle(sb([76, 28, 82, 96]), fill=CLOAK_D)
    # Accent edge lines (purple trim)
    d.line(sp([(14, 28), (10, 96)]), fill=ACCENT, width=s(1))
    d.line(sp([(82, 28), (86, 96)]), fill=ACCENT, width=s(2))

    # LEFT DAGGER (visible at side)
    d.rectangle(sb([4, 38, 9, 72]), fill=GUARD)
    d.rectangle(sb([5, 45, 8, 60]), fill=(130, 96, 34))
    d.rectangle(sb([2, 36, 11, 40]), fill=(132, 108, 44))
    d.polygon(sp([(3, 16), (8, 16), (5, 36)]), fill=BLADE)
    d.polygon(sp([(4, 18), (7, 18), (5, 28)]), fill=BLADE_H)
    # blade sheen
    d.line(sp([(4, 18), (6, 34)]), fill=BLADE_H, width=s(1))

    # RIGHT DAGGER
    d.rectangle(sb([87, 40, 92, 72]), fill=GUARD)
    d.rectangle(sb([88, 47, 91, 62]), fill=(130, 96, 34))
    d.rectangle(sb([85, 38, 94, 42]), fill=(132, 108, 44))
    d.polygon(sp([(85, 18), (90, 18), (87, 38)]), fill=BLADE)
    d.polygon(sp([(86, 20), (89, 20), (87, 30)]), fill=BLADE_H)
    d.line(sp([(86, 20), (88, 36)]), fill=BLADE_H, width=s(1))

    # LEFT ARM (holding dagger, extends from cloak)
    d.rounded_rectangle(sb([8, 25, 20, 50]), radius=s(5), fill=CLOAK)
    d.rectangle(sb([8, 25, 14, 50]), fill=CLOAK_H)

    # RIGHT ARM
    d.rounded_rectangle(sb([76, 25, 88, 50]), radius=s(5), fill=CLOAK)
    d.rectangle(sb([82, 25, 88, 50]), fill=CLOAK_D)

    # HOOD — dark outer ring, lighter inner for face
    d.ellipse(sb([18, 2, 78, 40]), fill=CLOAK_D)
    d.ellipse(sb([24, 7, 72, 36]), fill=CLOAK)
    d.ellipse(sb([18, 2, 44, 22]), fill=CLOAK_H)

    # FACE (partially visible under hood)
    d.ellipse(sb([30, 13, 66, 35]), fill=SKIN)
    d.ellipse(sb([30, 13, 44, 26]), fill=(208, 170, 125))
    # Lower face mask
    d.rounded_rectangle(sb([30, 26, 66, 35]), radius=s(4), fill=CLOAK_D)

    # Hood clasp — accent gem
    d.ellipse(sb([42, 29, 54, 39]), fill=ACCENT)
    d.ellipse(sb([44, 31, 52, 37]), fill=(160, 110, 240))
    d.ellipse(sb([46, 33, 50, 35]), fill=(220, 200, 255, 200))

    # EYES — glowing teal (distinctive feature)
    img = bg(img, 38, 23, 8, EYE_C, passes=4)
    img = bg(img, 58, 23, 8, EYE_C, passes=4)
    d = ImageDraw.Draw(img)
    for ex in [32, 52]:
        d.ellipse(sb([ex, 18, ex+13, 29]), fill=(6, 3, 14))
        d.ellipse(sb([ex+1, 19, ex+12, 28]), fill=EYE_C)
        d.ellipse(sb([ex+2, 20, ex+11, 27]), fill=(188, 252, 236))
        d.ellipse(sb([ex+4, 22, ex+9, 26]), fill=(6, 3, 14))
        d.ellipse(sb([ex+1, 18, ex+4, 21]), fill=(255, 255, 255, 185))

    return img


def hero_rogue_portrait():
    CLOAK  = (40, 22, 62); CLOAK_H = (68, 44, 96); CLOAK_D = (20, 10, 34)
    BLADE  = (210, 220, 235); BLADE_H = (245, 250, 255)
    ACCENT = (138, 96, 218)
    SKIN   = (188, 148, 105)
    EYE_C  = (78, 228, 188)

    img = portrait_bg((16, 8, 28), (28, 14, 44))

    # Glow behind eyes
    img = pg(img, 68, 95, 40, EYE_C, passes=4)
    img = pg(img, 132, 95, 40, EYE_C, passes=4)
    d   = ImageDraw.Draw(img)

    # CLOAK BODY (lower portion)
    d.polygon(psp([(4, 130), (196, 130), (200, 190), (0, 190)]), fill=CLOAK)
    d.polygon(psp([(4, 130), (40, 130), (36, 190), (0, 190)]), fill=CLOAK_H)
    d.rectangle(psb([4, 130, 12, 190]), fill=CLOAK_H)
    d.rectangle(psb([188, 130, 196, 190]), fill=CLOAK_D)
    # Accent trim
    d.line(psp([(4, 130), (0, 190)]), fill=ACCENT, width=ps(2))
    d.line(psp([(196, 130), (200, 190)]), fill=ACCENT, width=ps(2))

    # Hood clasp
    d.ellipse(psb([87, 132, 113, 152]), fill=ACCENT)
    d.ellipse(psb([91, 136, 109, 148]), fill=(160, 110, 240))
    d.ellipse(psb([96, 140, 104, 145]), fill=(220, 200, 255, 200))

    # Hood outline (dark)
    d.ellipse(psb([14, 6, 186, 140]), fill=CLOAK_D)
    d.ellipse(psb([24, 14, 176, 128]), fill=CLOAK)
    d.ellipse(psb([14, 6, 72, 58]), fill=CLOAK_H)

    # FACE
    d.ellipse(psb([42, 34, 158, 118]), fill=SKIN)
    d.ellipse(psb([42, 34, 86, 76]), fill=(208, 170, 125))
    # lower mask
    d.rounded_rectangle(psb([42, 92, 158, 120]), radius=ps(8), fill=CLOAK_D)

    # EYES — glowing teal (large, dramatic)
    img = pg(img, 68, 70, 20, EYE_C, passes=5)
    img = pg(img, 132, 70, 20, EYE_C, passes=5)
    d   = ImageDraw.Draw(img)
    for ex in [36, 102]:
        d.ellipse(psb([ex, 54, ex+56, 92]), fill=(6, 3, 14))
        d.ellipse(psb([ex+2, 56, ex+54, 90]), fill=EYE_C)
        d.ellipse(psb([ex+5, 59, ex+51, 87]), fill=(188, 252, 236))
        d.ellipse(psb([ex+16, 68, ex+40, 80]), fill=(6, 3, 14))
        d.ellipse(psb([ex+3, 55, ex+13, 65]), fill=(255, 255, 255, 185))

    # Dagger hilts crossing at bottom
    for dx, sign in [(42, 1), (116, -1)]:
        d.rectangle(psb([dx, 140, dx+20, 190]), fill=(88, 58, 20))
        x0 = min(dx-8*sign, dx+28*sign)
        x1 = max(dx-8*sign, dx+28*sign)
        d.rectangle(psb([x0, 148, x1, 162]), fill=(132, 108, 44))
        d.polygon(psp([(dx+2, 108), (dx+18, 108), (dx+10, 142)]), fill=BLADE)
        d.polygon(psp([(dx+5, 110), (dx+15, 110), (dx+10, 126)]), fill=BLADE_H)

    return img


# ════════════════════════════════════════════════════════════════════════════
# HERO: ARCANIST
# Robed wizard, pointed hat, glowing staff orb, white beard, magic glow.
# ════════════════════════════════════════════════════════════════════════════

def hero_arcanist_sprite():
    SKIN  = (195, 155, 112); SKIN_D = (145, 105, 65)
    ROBE  = (48, 28, 90); ROBE_H = (70, 44, 122); ROBE_D = (26, 12, 56)
    BEARD = (212, 206, 195)
    HAT   = (36, 20, 68)
    GLOW  = (168, 110, 255); GLOW_H = (218, 178, 255)
    WOOD  = (88, 58, 22); GOLD = (198, 158, 28)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([22, 88, 74, 95]), fill=(0, 0, 0, 50))

    # ROBE (wide, flowing)
    d.polygon(sp([(18, 32), (78, 32), (86, 96), (10, 96)]), fill=ROBE)
    d.polygon(sp([(18, 32), (38, 32), (30, 96), (12, 96)]), fill=ROBE_H)
    d.rectangle(sb([18, 32, 24, 96]), fill=ROBE_H)
    d.rectangle(sb([72, 32, 78, 96]), fill=ROBE_D)
    # Gold hem
    d.rectangle(sb([10, 90, 86, 96]), fill=GOLD)
    # Arcane rune on robe chest
    img = bg(img, 48, 55, 10, GLOW, passes=3)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([40, 47, 56, 63]), fill=(122, 72, 215))
    d.ellipse(sb([42, 49, 54, 61]), fill=ROBE)
    d.ellipse(sb([46, 53, 50, 57]), fill=GLOW)

    # STAFF (left side — tall, prominent)
    d.rectangle(sb([5, 8, 11, 82]), fill=WOOD)
    d.rectangle(sb([6, 8, 9, 82]), fill=(118, 82, 34))
    d.rectangle(sb([3, 24, 13, 28]), fill=GOLD)
    d.rectangle(sb([3, 50, 13, 54]), fill=GOLD)
    # ORB glow at top of staff
    img = bg(img, 8, 6, 11, GLOW, passes=5)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([1, 1, 15, 13]), fill=GLOW)
    d.ellipse(sb([3, 3, 13, 11]), fill=GLOW_H)
    d.ellipse(sb([5, 4, 9, 8]), fill=(248, 232, 255, 220))

    # LEFT ARM (holding staff)
    d.rounded_rectangle(sb([11, 30, 22, 58]), radius=s(5), fill=ROBE)
    d.rectangle(sb([11, 30, 16, 58]), fill=ROBE_H)

    # RIGHT ARM (casting — hand glowing)
    d.rounded_rectangle(sb([74, 26, 88, 52]), radius=s(5), fill=ROBE)
    d.rectangle(sb([82, 26, 88, 52]), fill=ROBE_D)
    img = bg(img, 85, 57, 9, GLOW, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([79, 51, 93, 63]), fill=GLOW)
    d.ellipse(sb([81, 53, 91, 61]), fill=GLOW_H)

    # NECK
    d.rounded_rectangle(sb([39, 20, 57, 33]), radius=s(4), fill=SKIN)

    # HEAD
    d.ellipse(sb([28, 4, 68, 28]), fill=SKIN)
    d.ellipse(sb([28, 4, 42, 18]), fill=SKIN)
    d.ellipse(sb([54, 6, 68, 20]), fill=SKIN_D)

    # WIZARD HAT
    d.polygon(sp([(48, 0), (24, 22), (72, 22)]), fill=HAT)
    d.polygon(sp([(48, 0), (26, 20), (48, 20)]), fill=(56, 36, 92))
    d.ellipse(sb([22, 18, 74, 28]), fill=HAT)
    d.ellipse(sb([22, 18, 46, 26]), fill=(56, 36, 92))
    # star at hat tip
    img = bg(img, 48, 2, 6, GLOW, passes=3)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([44, 0, 52, 6]), fill=GLOW_H)

    # BEARD
    d.polygon(sp([(30, 22), (66, 22), (62, 40), (34, 40)]), fill=BEARD)
    d.rectangle(sb([30, 22, 36, 40]), fill=(232, 228, 218))

    # BROWS (bushy white)
    d.rectangle(sb([30, 10, 42, 14]), fill=(188, 184, 172))
    d.rectangle(sb([54, 10, 66, 14]), fill=(188, 184, 172))

    # EYES — glowing purple-blue
    img = bg(img, 38, 18, 6, GLOW, passes=3)
    img = bg(img, 58, 18, 6, GLOW, passes=3)
    d = ImageDraw.Draw(img)
    for ex in [33, 53]:
        d.ellipse(sb([ex, 14, ex+12, 22]), fill=(8, 4, 18))
        d.ellipse(sb([ex+1, 15, ex+11, 21]), fill=(82, 50, 172))
        d.ellipse(sb([ex+2, 16, ex+10, 20]), fill=(158, 100, 255))
        d.ellipse(sb([ex+4, 16, ex+8, 20]), fill=(8, 4, 18))
        d.ellipse(sb([ex+2, 15, ex+4, 17]), fill=(255, 255, 255, 185))

    # nose
    d.ellipse(sb([43, 19, 53, 25]), fill=SKIN_D)

    return img


def hero_arcanist_portrait():
    SKIN  = (195, 155, 112); SKIN_D = (145, 105, 65)
    ROBE  = (48, 28, 90); ROBE_H = (72, 46, 124); ROBE_D = (24, 10, 52)
    BEARD = (212, 206, 195)
    HAT   = (36, 20, 68)
    GLOW  = (168, 110, 255); GLOW_H = (218, 178, 255)
    WOOD  = (88, 58, 22); GOLD = (198, 158, 28)

    img = portrait_bg((18, 8, 38), (26, 12, 52))

    # Magical glow behind character
    img = pg(img, 100, 120, 90, GLOW, passes=4)
    d   = ImageDraw.Draw(img)

    # ROBE (lower portion)
    d.polygon(psp([(8, 138), (192, 138), (196, 190), (4, 190)]), fill=ROBE)
    d.polygon(psp([(8, 138), (46, 138), (40, 190), (4, 190)]), fill=ROBE_H)
    d.rectangle(psb([8, 138, 16, 190]), fill=ROBE_H)
    d.rectangle(psb([184, 138, 192, 190]), fill=ROBE_D)
    d.rectangle(psb([4, 184, 196, 190]), fill=GOLD)
    # arcane rune
    img = pg(img, 100, 162, 18, GLOW, passes=3)
    d   = ImageDraw.Draw(img)
    d.ellipse(psb([82, 148, 118, 176]), fill=(122, 72, 215))
    d.ellipse(psb([86, 152, 114, 172]), fill=ROBE)
    d.ellipse(psb([96, 160, 104, 168]), fill=GLOW)

    # STAFF TIP visible left side
    img = pg(img, 18, 14, 16, GLOW, passes=5)
    d   = ImageDraw.Draw(img)
    d.rectangle(psb([14, 22, 22, 190]), fill=WOOD)
    d.ellipse(psb([6, 4, 30, 26]), fill=GLOW)
    d.ellipse(psb([9, 7, 27, 23]), fill=GLOW_H)
    d.ellipse(psb([13, 11, 21, 17]), fill=(248, 235, 255, 225))

    # NECK
    d.rounded_rectangle(psb([82, 112, 118, 140]), radius=ps(6), fill=SKIN)

    # HEAD
    d.ellipse(psb([30, 18, 170, 110]), fill=SKIN)
    d.ellipse(psb([30, 18, 78, 64]), fill=SKIN)
    d.ellipse(psb([122, 22, 170, 72]), fill=SKIN_D)

    # WIZARD HAT
    d.polygon(psp([(100, 2), (28, 52), (172, 52)]), fill=HAT)
    d.polygon(psp([(100, 2), (32, 50), (100, 50)]), fill=(58, 38, 96))
    d.ellipse(psb([24, 44, 176, 68]), fill=HAT)
    d.ellipse(psb([24, 44, 98, 64]), fill=(58, 38, 96))
    img = pg(img, 100, 4, 12, GLOW, passes=3)
    d   = ImageDraw.Draw(img)
    d.ellipse(psb([92, 0, 108, 12]), fill=GLOW_H)

    # BEARD
    d.polygon(psp([(36, 78), (164, 78), (154, 130), (46, 130)]), fill=BEARD)
    d.rectangle(psb([36, 78, 54, 130]), fill=(232, 228, 218))

    # BROWS
    d.rectangle(psb([38, 36, 78, 50]), fill=(188, 184, 172))
    d.rectangle(psb([122, 36, 162, 50]), fill=(188, 184, 172))

    # EYES — glowing purple-blue
    img = pg(img, 64, 68, 18, GLOW, passes=4)
    img = pg(img, 136, 68, 18, GLOW, passes=4)
    d   = ImageDraw.Draw(img)
    for ex in [36, 108]:
        d.ellipse(psb([ex, 54, ex+52, 86]), fill=(8, 4, 18))
        d.ellipse(psb([ex+2, 56, ex+50, 84]), fill=(82, 50, 172))
        d.ellipse(psb([ex+5, 59, ex+47, 81]), fill=(158, 100, 255))
        d.ellipse(psb([ex+16, 66, ex+36, 76]), fill=(8, 4, 18))
        d.ellipse(psb([ex+4, 56, ex+14, 64]), fill=(255, 255, 255, 185))

    # NOSE
    d.ellipse(psb([86, 84, 114, 100]), fill=SKIN_D)

    # casting glow on right hand (partially visible)
    img = pg(img, 178, 150, 22, GLOW, passes=3)
    d   = ImageDraw.Draw(img)
    d.ellipse(psb([158, 134, 196, 166]), fill=GLOW)
    d.ellipse(psb([163, 139, 191, 161]), fill=GLOW_H)

    return img


# ════════════════════════════════════════════════════════════════════════════
# ENEMIES (battle sprites only)
# ════════════════════════════════════════════════════════════════════════════

def enemy_imp():
    RED  = (215, 38, 20); RED_H = (255, 90, 58); RED_D = (138, 16, 6)
    WING = (155, 16, 8);  WING_D= (85, 6, 2)
    EYE  = (255, 200, 0)
    CLAW = (78, 50, 18)
    TAIL = (175, 28, 12)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([22, 88, 74, 95]), fill=(0, 0, 0, 45))

    # WINGS (prominent bat wings, spread wide)
    d.polygon(sp([(46, 32), (2, 6), (14, 40), (36, 38)]), fill=WING)
    d.polygon(sp([(46, 32), (2, 6), (8, 28), (26, 34)]), fill=WING_D)
    d.polygon(sp([(50, 32), (94, 6), (82, 40), (60, 38)]), fill=WING)
    d.polygon(sp([(50, 32), (94, 6), (88, 28), (70, 34)]), fill=WING_D)
    # wing ribs
    d.line(sp([(46, 32), (2, 6)]), fill=RED_D, width=s(2))
    d.line(sp([(50, 32), (94, 6)]), fill=RED_D, width=s(2))
    d.line(sp([(16, 40), (2, 6)]), fill=RED_D, width=s(1))
    d.line(sp([(80, 40), (94, 6)]), fill=RED_D, width=s(1))

    # TAIL (swishing)
    d.line(sp([(58, 64), (72, 72), (80, 64), (84, 76)]), fill=TAIL, width=s(4))
    d.polygon(sp([(78, 72), (88, 68), (82, 80)]), fill=RED_D)

    # BODY
    d.ellipse(sb([28, 34, 68, 76]), fill=RED)
    d.ellipse(sb([28, 34, 42, 52]), fill=RED_H)
    d.ellipse(sb([54, 52, 68, 68]), fill=RED_D)

    # ARMS / CLAWS
    d.rounded_rectangle(sb([12, 40, 28, 56]), radius=s(5), fill=RED)
    d.rounded_rectangle(sb([68, 40, 84, 56]), radius=s(5), fill=RED)
    for cx, cy in [(6, 52), (10, 56), (14, 58)]:
        d.polygon(sp([(12, 52), (cx, cy), (16, 52)]), fill=CLAW)
    for cx, cy in [(90, 52), (86, 56), (82, 58)]:
        d.polygon(sp([(84, 52), (cx, cy), (80, 52)]), fill=CLAW)

    # LEGS
    d.rounded_rectangle(sb([32, 72, 44, 84]), radius=s(4), fill=RED)
    d.rounded_rectangle(sb([52, 72, 64, 84]), radius=s(4), fill=RED)
    for cx, cy in [(26, 84), (32, 88), (38, 86)]:
        d.polygon(sp([(32, 84), (cx, cy), (36, 84)]), fill=CLAW)
    for cx, cy in [(58, 88), (64, 84), (68, 88)]:
        d.polygon(sp([(58, 84), (cx, cy), (62, 84)]), fill=CLAW)

    # HEAD
    d.ellipse(sb([28, 22, 68, 52]), fill=RED)
    d.ellipse(sb([28, 22, 42, 40]), fill=RED_H)

    # HORNS
    d.polygon(sp([(34, 26), (26, 6), (40, 24)]), fill=RED_D)
    d.polygon(sp([(62, 26), (70, 6), (56, 24)]), fill=RED_D)

    # EYE GLOW
    img = bg(img, 40, 36, 8, EYE, passes=4)
    img = bg(img, 56, 36, 8, EYE, passes=4)
    d = ImageDraw.Draw(img)
    for ex in [32, 50]:
        d.ellipse(sb([ex, 30, ex+14, 44]), fill=(10, 4, 1))
        d.ellipse(sb([ex+1, 31, ex+13, 43]), fill=EYE)
        d.ellipse(sb([ex+2, 32, ex+12, 42]), fill=(255, 226, 54))
        d.ellipse(sb([ex+4, 34, ex+10, 40]), fill=(8, 2, 0))
        d.ellipse(sb([ex+2, 31, ex+5, 34]), fill=(255, 255, 255, 185))

    # GRIN
    d.arc(sb([32, 40, 64, 54]), start=10, end=170, fill=RED_D, width=s(2))
    for tx in [35, 40, 46, 52, 57]:
        d.polygon(sp([(tx, 43), (tx+2, 48), (tx+4, 43)]), fill=(230, 215, 195))

    return img


def enemy_goblin():
    GREEN  = (72, 145, 48); GREEN_H = (104, 185, 70); GREEN_D = (44, 92, 26)
    EYE    = (255, 196, 0)
    LEATH  = (70, 46, 18); LEATH_D = (46, 28, 10)
    METAL  = (96, 90, 80)
    CLUB   = (102, 68, 26)
    BOOT   = (40, 24, 10)
    TOOTH  = (220, 214, 184)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([22, 88, 74, 95]), fill=(0, 0, 0, 55))

    # CLUB (raised high)
    d.rectangle(sb([4, 8, 12, 60]), fill=CLUB)
    d.rectangle(sb([5, 8, 9, 60]), fill=(135, 94, 40))
    d.ellipse(sb([0, 0, 16, 18]), fill=CLUB)
    d.ellipse(sb([2, 2, 14, 16]), fill=(135, 94, 40))
    for sy in [5, 9, 13]:
        d.ellipse(sb([1, sy, 5, sy+4]), fill=METAL)
        d.ellipse(sb([11, sy, 15, sy+4]), fill=METAL)
    for wy in [25, 33, 41, 49]:
        d.rectangle(sb([3, wy, 13, wy+3]), fill=LEATH_D)

    # BOOTS
    d.rounded_rectangle(sb([26, 80, 45, 96]), radius=s(4), fill=BOOT)
    d.rounded_rectangle(sb([51, 80, 70, 96]), radius=s(4), fill=BOOT)

    # LEGS (squat)
    d.ellipse(sb([25, 60, 46, 84]), fill=GREEN)
    d.ellipse(sb([50, 60, 71, 84]), fill=GREEN)
    d.rectangle(sb([25, 60, 31, 80]), fill=GREEN_H)

    # BELT
    d.rounded_rectangle(sb([22, 55, 74, 63]), radius=s(2), fill=LEATH)
    for bx in [26, 36, 51, 61, 67]:
        d.ellipse(sb([bx, 57, bx+4, 61]), fill=METAL)

    # LEATHER TORSO
    d.rounded_rectangle(sb([22, 28, 74, 58]), radius=s(5), fill=LEATH)
    d.rectangle(sb([22, 28, 28, 58]), fill=(92, 64, 28))
    d.rectangle(sb([68, 28, 74, 58]), fill=LEATH_D)
    d.line(sp([(44, 29), (44, 57)]), fill=LEATH_D, width=s(2))
    d.rectangle(sb([26, 34, 41, 48]), fill=LEATH_D)
    d.rectangle(sb([53, 36, 66, 48]), fill=LEATH_D)

    # BIG POINTY EARS
    d.polygon(sp([(22, 22), (4, 10), (6, 36), (22, 32)]), fill=GREEN)
    d.polygon(sp([(22, 22), (6, 12), (6, 30)]), fill=GREEN_H)
    d.polygon(sp([(74, 22), (92, 10), (90, 36), (74, 32)]), fill=GREEN)
    d.polygon(sp([(74, 22), (90, 12), (90, 30)]), fill=GREEN_D)

    # ARMS
    d.rounded_rectangle(sb([8, 27, 23, 54]), radius=s(6), fill=GREEN)
    d.rectangle(sb([8, 27, 14, 54]), fill=GREEN_H)
    d.rounded_rectangle(sb([73, 27, 87, 54]), radius=s(6), fill=GREEN)
    # Right arm buckler
    d.ellipse(sb([75, 50, 93, 68]), fill=LEATH)
    d.ellipse(sb([77, 52, 91, 66]), fill=LEATH_D)
    d.ellipse(sb([81, 56, 89, 64]), fill=METAL)
    d.ellipse(sb([83, 58, 87, 62]), fill=(150, 140, 120))

    # CRUDE HELMET (metal)
    d.ellipse(sb([24, 8, 72, 28]), fill=METAL)
    d.rectangle(sb([24, 16, 72, 28]), fill=METAL)
    d.rectangle(sb([24, 16, 28, 28]), fill=(130, 124, 110))
    d.ellipse(sb([24, 10, 40, 22]), fill=(128, 122, 108))
    for hx in [30, 48, 64]:
        d.ellipse(sb([hx, 11, hx+4, 15]), fill=(140, 130, 110))

    # HEAD
    d.ellipse(sb([26, 12, 70, 36]), fill=GREEN)
    d.ellipse(sb([26, 12, 40, 26]), fill=GREEN_H)
    d.ellipse(sb([56, 16, 70, 30]), fill=GREEN_D)
    d.rectangle(sb([28, 22, 42, 26]), fill=GREEN_D)
    d.rectangle(sb([54, 22, 68, 26]), fill=GREEN_D)

    # EYES — glowing yellow
    img = bg(img, 36, 28, 6, EYE, passes=3)
    img = bg(img, 60, 28, 6, EYE, passes=3)
    d = ImageDraw.Draw(img)
    for ex in [29, 53]:
        d.ellipse(sb([ex, 24, ex+14, 34]), fill=(8, 4, 1))
        d.ellipse(sb([ex+1, 25, ex+13, 33]), fill=EYE)
        d.ellipse(sb([ex+2, 26, ex+12, 32]), fill=(255, 214, 44))
        d.rectangle(sb([ex+6, 25, ex+8, 33]), fill=(8, 4, 1))
        d.ellipse(sb([ex+2, 25, ex+4, 27]), fill=(255, 255, 255, 165))

    # FLAT NOSE
    d.ellipse(sb([42, 30, 54, 36]), fill=GREEN_D)
    d.ellipse(sb([42, 33, 46, 36]), fill=(28, 58, 16))
    d.ellipse(sb([50, 33, 54, 36]), fill=(28, 58, 16))

    # GRIN + TUSK
    d.arc(sb([30, 33, 66, 46]), start=15, end=165, fill=GREEN_D, width=s(2))
    for tx in [33, 38, 48, 57]:
        d.polygon(sp([(tx, 36), (tx+2, 41), (tx+4, 36)]), fill=TOOTH)
    d.polygon(sp([(45, 36), (50, 48), (55, 36)]), fill=(234, 228, 200))

    return img


def enemy_skeleton():
    BONE   = (224, 214, 186); BONE_H = (248, 240, 220); BONE_D = (152, 140, 114)
    RUST   = (108, 72, 38); RUST_D = (68, 42, 20)
    EYE    = (220, 48, 18)
    BLADE  = (174, 182, 194); BLADE_H = (210, 220, 230)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([22, 88, 74, 95]), fill=(0, 0, 0, 55))

    # SWORD (right, upright)
    d.rectangle(sb([74, 8, 80, 68]), fill=BLADE)
    d.rectangle(sb([75, 8, 78, 68]), fill=BLADE_H)
    d.rectangle(sb([67, 36, 87, 42]), fill=(130, 90, 34))
    d.rounded_rectangle(sb([73, 62, 81, 74]), radius=s(3), fill=(100, 70, 28))
    d.ellipse(sb([73, 72, 81, 80]), fill=(120, 84, 30))

    # FEET
    d.rounded_rectangle(sb([27, 80, 46, 92]), radius=s(3), fill=BONE_D)
    d.rounded_rectangle(sb([50, 80, 69, 92]), radius=s(3), fill=BONE_D)
    for bx in [28, 33, 38]: d.rectangle(sb([bx, 80, bx+3, 84]), fill=BONE)
    for bx in [51, 56, 61]: d.rectangle(sb([bx, 80, bx+3, 84]), fill=BONE)

    # SHIN BONES
    d.rectangle(sb([31, 60, 37, 82]), fill=BONE)
    d.rectangle(sb([32, 60, 35, 82]), fill=BONE_H)
    d.rectangle(sb([59, 60, 65, 82]), fill=BONE)
    d.rectangle(sb([60, 60, 63, 82]), fill=BONE_H)

    # KNEE CAPS
    d.ellipse(sb([28, 54, 42, 65]), fill=BONE)
    d.ellipse(sb([54, 54, 68, 65]), fill=BONE)

    # THIGH BONES
    d.rectangle(sb([30, 44, 40, 62]), fill=BONE)
    d.rectangle(sb([56, 44, 66, 62]), fill=BONE)
    d.rectangle(sb([31, 44, 34, 62]), fill=BONE_H)

    # PELVIS
    d.ellipse(sb([27, 42, 69, 58]), fill=BONE)
    d.ellipse(sb([31, 46, 46, 56]), fill=BONE_D)
    d.ellipse(sb([50, 46, 65, 56]), fill=BONE_D)

    # RUSTY BREASTPLATE
    d.rounded_rectangle(sb([25, 26, 71, 46]), radius=s(4), fill=RUST)
    d.rectangle(sb([25, 26, 31, 46]), fill=(130, 90, 50))
    d.rectangle(sb([65, 26, 71, 46]), fill=RUST_D)
    for ry in range(28, 44, 4):
        for rx in range(28, 68, 4):
            d.ellipse(sb([rx, ry, rx+3, ry+3]), fill=RUST_D)

    # RIBS
    for rib_y in [27, 31, 35, 39, 43]:
        d.arc(sb([27, rib_y, 46, rib_y+6]), start=180, end=360, fill=BONE, width=s(2))
        d.arc(sb([50, rib_y, 69, rib_y+6]), start=0, end=180, fill=BONE, width=s(2))

    # SPINE
    for sy in [26, 32, 38, 44]: d.ellipse(sb([44, sy, 52, sy+5]), fill=BONE)

    # LEFT ARM BONES
    d.rounded_rectangle(sb([10, 24, 26, 44]), radius=s(6), fill=BONE)
    d.rectangle(sb([11, 24, 14, 44]), fill=BONE_H)
    d.ellipse(sb([8, 22, 22, 28]), fill=BONE)
    for hb in [8, 12, 16]: d.rectangle(sb([hb, 44, hb+3, 54]), fill=BONE)
    d.rectangle(sb([8, 42, 20, 46]), fill=BONE)

    # RIGHT ARM BONES
    d.rounded_rectangle(sb([70, 24, 86, 44]), radius=s(6), fill=BONE)
    d.rectangle(sb([82, 24, 85, 44]), fill=BONE_H)
    d.ellipse(sb([74, 22, 88, 28]), fill=BONE)

    # SKULL
    d.ellipse(sb([28, 2, 68, 30]), fill=BONE)
    d.ellipse(sb([28, 2, 44, 18]), fill=BONE_H)
    d.ellipse(sb([52, 4, 68, 22]), fill=BONE_D)
    d.rounded_rectangle(sb([34, 22, 62, 32]), radius=s(4), fill=BONE_D)

    # EYE GLOW (red soul fire — very prominent)
    img = bg(img, 37, 15, 9, EYE, passes=5)
    img = bg(img, 59, 15, 9, EYE, passes=5)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([31, 10, 46, 22]), fill=(18, 6, 2))
    d.ellipse(sb([50, 10, 65, 22]), fill=(18, 6, 2))
    d.ellipse(sb([33, 12, 44, 20]), fill=EYE)
    d.ellipse(sb([52, 12, 63, 20]), fill=EYE)
    d.ellipse(sb([34, 13, 43, 19]), fill=(255, 94, 44))
    d.ellipse(sb([53, 13, 62, 19]), fill=(255, 94, 44))

    # nasal cavity
    d.polygon(sp([(44, 22), (48, 28), (52, 22)]), fill=(16, 6, 2))

    # teeth
    for tx in [36, 40, 44, 48, 52, 56]:
        d.rectangle(sb([tx, 28, tx+3, 34]), fill=BONE_H)

    return img


def enemy_demon():
    RED  = (165, 22, 12); RED_H = (215, 60, 38); RED_D = (104, 8, 4)
    HORN = (52, 32, 16)
    EYE  = (255, 150, 0)
    FIRE = (255, 185, 0); FIRE2 = (255, 100, 10)
    CLAW = (60, 38, 18)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([18, 88, 78, 95]), fill=(0, 0, 0, 65))

    # fire aura behind body
    for fx, fy, fr in [(48, 80, 22), (28, 72, 14), (68, 74, 16)]:
        img = bg(img, fx, fy, fr, (255, 80, 0), passes=3)
    d = ImageDraw.Draw(img)

    # TAIL
    d.line(sp([(62, 58), (78, 66), (84, 58), (88, 72), (84, 82)]), fill=RED_D, width=s(5))
    d.polygon(sp([(82, 78), (90, 73), (86, 86)]), fill=RED_D)

    # LEGS (massive)
    d.rounded_rectangle(sb([24, 56, 48, 88]), radius=s(8), fill=RED)
    d.rounded_rectangle(sb([52, 56, 76, 88]), radius=s(8), fill=RED)
    d.rectangle(sb([24, 56, 32, 88]), fill=RED_H)
    d.rectangle(sb([68, 56, 76, 88]), fill=RED_D)
    for cx, cy in [(18, 88), (24, 92), (30, 90), (36, 94)]:
        d.polygon(sp([(24, 86), (cx, cy), (32, 86)]), fill=CLAW)
    for cx, cy in [(60, 88), (66, 92), (72, 90), (78, 94)]:
        d.polygon(sp([(60, 86), (cx, cy), (72, 86)]), fill=CLAW)

    # BODY (huge, muscular)
    d.ellipse(sb([16, 24, 80, 62]), fill=RED)
    d.ellipse(sb([16, 24, 34, 44]), fill=RED_H)
    d.ellipse(sb([62, 32, 80, 56]), fill=RED_D)
    d.arc(sb([20, 30, 44, 54]), start=200, end=340, fill=RED_D, width=s(3))
    d.arc(sb([52, 30, 76, 54]), start=200, end=340, fill=RED_D, width=s(3))

    # LEFT ARM (claw forward)
    d.rounded_rectangle(sb([0, 20, 18, 54]), radius=s(8), fill=RED)
    d.rectangle(sb([0, 20, 6, 54]), fill=RED_H)
    for cx, cy in [(0, 54), (4, 60), (8, 62), (14, 60)]:
        d.polygon(sp([(2, 52), (cx, cy), (12, 52)]), fill=CLAW)

    # RIGHT ARM (raised, menacing)
    d.rounded_rectangle(sb([78, 12, 96, 48]), radius=s(8), fill=RED)
    d.rectangle(sb([90, 12, 96, 48]), fill=RED_D)
    for cx, cy in [(78, 8), (84, 4), (90, 6), (96, 10)]:
        d.polygon(sp([(82, 14), (cx, cy), (92, 14)]), fill=CLAW)

    # fire fists glow
    img = bg(img, 8, 54, 11, FIRE, passes=4)
    img = bg(img, 88, 8, 11, FIRE, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([0, 48, 16, 64]), fill=FIRE2)
    d.ellipse(sb([2, 50, 14, 62]), fill=FIRE)
    d.ellipse(sb([80, 2, 96, 18]), fill=FIRE2)
    d.ellipse(sb([82, 4, 94, 16]), fill=FIRE)

    # NECK
    d.rounded_rectangle(sb([36, 18, 60, 28]), radius=s(5), fill=RED)

    # HEAD
    d.ellipse(sb([22, 4, 74, 32]), fill=RED)
    d.ellipse(sb([22, 4, 40, 20]), fill=RED_H)
    d.ellipse(sb([56, 6, 74, 24]), fill=RED_D)

    # HORNS (large)
    d.polygon(sp([(28, 8), (6, 0), (20, 22), (32, 18)]), fill=HORN)
    d.polygon(sp([(28, 8), (8, 2), (16, 18)]), fill=(80, 50, 24))
    d.polygon(sp([(68, 8), (90, 0), (76, 22), (64, 18)]), fill=HORN)
    d.polygon(sp([(68, 8), (88, 2), (80, 18)]), fill=(80, 50, 24))

    # EYES (burning orange)
    img = bg(img, 37, 18, 9, EYE, passes=5)
    img = bg(img, 61, 18, 9, EYE, passes=5)
    d = ImageDraw.Draw(img)
    for ex in [28, 52]:
        d.ellipse(sb([ex, 13, ex+16, 25]), fill=(12, 2, 1))
        d.ellipse(sb([ex+1, 14, ex+15, 24]), fill=EYE)
        d.ellipse(sb([ex+2, 15, ex+14, 23]), fill=(255, 195, 44))
        d.ellipse(sb([ex+4, 16, ex+12, 22]), fill=(12, 2, 1))
        d.ellipse(sb([ex+2, 14, ex+5, 17]), fill=(255, 255, 200, 200))
        d.polygon(sp([(ex+6, 15), (ex+8, 13), (ex+10, 15), (ex+8, 23)]), fill=FIRE2)

    # nose and mouth
    d.ellipse(sb([43, 22, 53, 28]), fill=RED_D)
    d.arc(sb([28, 26, 68, 36]), start=10, end=170, fill=RED_D, width=s(2))
    for tx in [31, 37, 44, 53, 59]:
        d.polygon(sp([(tx, 28), (tx+2, 35), (tx+4, 28)]), fill=(234, 220, 200))

    return img


def enemy_golem():
    STONE  = (116, 108, 98); STONE_H = (158, 150, 136); STONE_D = (70, 62, 54)
    RUNE   = (78, 162, 210); RUNE2 = (140, 220, 255)
    CRACK  = (48, 42, 36)
    MOSS   = (60, 108, 50)
    LAVA   = (255, 88, 0); LAVA2 = (255, 178, 0)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([16, 88, 80, 96]), fill=(0, 0, 0, 80))

    # LEGS (pillar-like)
    d.rounded_rectangle(sb([20, 58, 47, 90]), radius=s(6), fill=STONE)
    d.rounded_rectangle(sb([53, 58, 80, 90]), radius=s(6), fill=STONE)
    d.rectangle(sb([20, 58, 28, 90]), fill=STONE_H)
    d.rectangle(sb([72, 58, 80, 90]), fill=STONE_D)
    d.line(sp([(28, 60), (24, 72), (30, 80)]), fill=CRACK, width=s(2))
    d.line(sp([(64, 62), (68, 74), (64, 84)]), fill=CRACK, width=s(2))
    # lava cracks on legs
    img = bg(img, 26, 70, 4, LAVA, passes=3)
    img = bg(img, 66, 76, 4, LAVA, passes=3)
    d = ImageDraw.Draw(img)
    d.line(sp([(22, 62), (26, 72)]), fill=LAVA, width=s(1))
    d.line(sp([(66, 64), (70, 76)]), fill=LAVA, width=s(1))
    d.ellipse(sb([20, 84, 35, 90]), fill=MOSS)
    d.ellipse(sb([60, 86, 74, 91]), fill=MOSS)

    # BODY (massive cube torso)
    d.rounded_rectangle(sb([12, 26, 84, 62]), radius=s(6), fill=STONE)
    d.rectangle(sb([12, 26, 22, 62]), fill=STONE_H)
    d.rectangle(sb([74, 26, 84, 62]), fill=STONE_D)
    # body cracks
    d.line(sp([(36, 28), (32, 40), (40, 52)]), fill=CRACK, width=s(2))
    d.line(sp([(60, 30), (64, 45), (58, 58)]), fill=CRACK, width=s(2))
    # lava glow on body
    img = bg(img, 36, 40, 6, LAVA, passes=4)
    img = bg(img, 48, 44, 5, LAVA2, passes=3)
    d = ImageDraw.Draw(img)
    d.line(sp([(18, 44), (38, 40), (44, 60)]), fill=LAVA, width=s(2))
    d.line(sp([(60, 30), (64, 45)]), fill=LAVA, width=s(2))
    # glowing rune circle on chest
    img = bg(img, 48, 44, 14, RUNE, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([36, 34, 60, 54]), fill=RUNE)
    d.ellipse(sb([38, 36, 58, 52]), fill=STONE)
    d.ellipse(sb([40, 38, 56, 50]), fill=RUNE)
    d.ellipse(sb([44, 42, 52, 46]), fill=RUNE2)
    d.line(sp([(48, 34), (48, 54)]), fill=RUNE2, width=s(2))
    d.line(sp([(36, 44), (60, 44)]), fill=RUNE2, width=s(2))
    d.line(sp([(39, 37), (57, 51)]), fill=RUNE, width=s(1))
    d.line(sp([(57, 37), (39, 51)]), fill=RUNE, width=s(1))

    # ARMS (massive)
    d.rounded_rectangle(sb([0, 22, 16, 72]), radius=s(6), fill=STONE)
    d.rectangle(sb([0, 22, 6, 72]), fill=STONE_H)
    d.rectangle(sb([10, 22, 16, 72]), fill=STONE_D)
    d.rounded_rectangle(sb([0, 68, 18, 82]), radius=s(4), fill=STONE_D)
    d.rounded_rectangle(sb([80, 12, 96, 62]), radius=s(6), fill=STONE)
    d.rectangle(sb([86, 12, 96, 62]), fill=STONE_D)
    d.rectangle(sb([80, 12, 86, 62]), fill=STONE_H)
    d.rounded_rectangle(sb([80, 6, 96, 20]), radius=s(4), fill=STONE_D)

    # NECK
    d.rounded_rectangle(sb([35, 18, 61, 28]), radius=s(4), fill=STONE)

    # HEAD (rough cube)
    d.rounded_rectangle(sb([20, 2, 76, 24]), radius=s(4), fill=STONE)
    d.rectangle(sb([20, 2, 30, 24]), fill=STONE_H)
    d.rectangle(sb([66, 2, 76, 24]), fill=STONE_D)
    d.line(sp([(40, 4), (36, 14), (42, 20)]), fill=CRACK, width=s(2))
    d.line(sp([(54, 6), (58, 16)]), fill=CRACK, width=s(1))
    d.ellipse(sb([20, 2, 36, 10]), fill=MOSS)
    d.ellipse(sb([64, 2, 76, 10]), fill=MOSS)

    # EYES (glowing rune slots)
    img = bg(img, 34, 12, 9, RUNE2, passes=4)
    img = bg(img, 62, 12, 9, RUNE2, passes=4)
    d = ImageDraw.Draw(img)
    d.rectangle(sb([26, 8, 44, 18]), fill=CRACK)
    d.rectangle(sb([52, 8, 70, 18]), fill=CRACK)
    d.rectangle(sb([28, 10, 42, 16]), fill=RUNE)
    d.rectangle(sb([54, 10, 68, 16]), fill=RUNE)
    d.rectangle(sb([31, 11, 39, 15]), fill=RUNE2)
    d.rectangle(sb([57, 11, 65, 15]), fill=RUNE2)

    # mouth grill
    d.rectangle(sb([28, 20, 68, 24]), fill=CRACK)
    for mx in [31, 38, 45, 52, 59]:
        d.rectangle(sb([mx, 20, mx+5, 24]), fill=STONE_D)

    return img


# ════════════════════════════════════════════════════════════════════════════
# BOSSES
# ════════════════════════════════════════════════════════════════════════════

def enemy_boss_dungeon_lord():
    ARMOR  = (18, 12, 32); ARMOR_H = (44, 32, 68); ARMOR_D = (8, 4, 16)
    GOLD   = (210, 164, 20); GOLD_D = (150, 110, 8)
    CAPE   = (140, 18, 28); CAPE_H = (184, 34, 46)
    SKIN   = (164, 100, 60); SKIN_D = (114, 64, 30)
    PURPLE = (160, 50, 220); PURP_H = (200, 100, 255)
    EYE    = (220, 160, 255)
    BLADE  = (190, 200, 215); BLADE_H = (220, 230, 248)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([20, 88, 76, 96]), fill=(0, 0, 0, 65))

    # dark magic aura
    for ax, ay, ar in [(48, 48, 38), (48, 78, 24), (20, 60, 18), (76, 60, 18)]:
        img = bg(img, ax, ay, ar, (120, 20, 200), passes=3)
    d = ImageDraw.Draw(img)

    # CRIMSON CAPE
    d.polygon(sp([(22, 26), (74, 26), (86, 96), (10, 96)]), fill=CAPE)
    d.polygon(sp([(22, 26), (38, 26), (30, 96), (12, 96)]), fill=CAPE_H)
    d.rectangle(sb([10, 26, 18, 96]), fill=CAPE_H)
    d.rectangle(sb([78, 26, 86, 96]), fill=(110, 12, 22))

    # GREATSWORD (behind, upright)
    d.rectangle(sb([3, 2, 11, 72]), fill=BLADE)
    d.rectangle(sb([4, 2, 8, 72]), fill=BLADE_H)
    d.rectangle(sb([0, 34, 14, 40]), fill=GOLD)
    d.rounded_rectangle(sb([4, 66, 10, 78]), radius=s(3), fill=GOLD)

    # GREAVES
    d.rounded_rectangle(sb([24, 78, 46, 92]), radius=s(4), fill=ARMOR)
    d.rounded_rectangle(sb([50, 78, 72, 92]), radius=s(4), fill=ARMOR)
    d.rectangle(sb([24, 78, 30, 88]), fill=ARMOR_H)
    d.rectangle(sb([24, 78, 46, 81]), fill=GOLD)
    d.rectangle(sb([50, 78, 72, 81]), fill=GOLD)

    # ARMORED LEGS
    d.rounded_rectangle(sb([24, 58, 46, 80]), radius=s(5), fill=ARMOR)
    d.rounded_rectangle(sb([50, 58, 72, 80]), radius=s(5), fill=ARMOR)
    d.rectangle(sb([24, 58, 30, 80]), fill=ARMOR_H)
    d.rectangle(sb([66, 58, 72, 80]), fill=ARMOR_D)

    # BELT/SKIRT
    d.rounded_rectangle(sb([20, 54, 76, 62]), radius=s(3), fill=ARMOR_D)
    for bx in [24, 32, 40, 48, 56, 64]:
        d.rectangle(sb([bx, 54, bx+6, 62]), fill=ARMOR)
    d.rectangle(sb([43, 53, 53, 63]), fill=GOLD)

    # BREASTPLATE
    d.rounded_rectangle(sb([18, 24, 78, 58]), radius=s(6), fill=ARMOR)
    d.rectangle(sb([18, 24, 26, 58]), fill=ARMOR_H)
    d.rectangle(sb([70, 24, 78, 58]), fill=ARMOR_D)
    d.rounded_rectangle(sb([28, 30, 68, 50]), radius=s(4), fill=ARMOR_D)
    d.rounded_rectangle(sb([30, 32, 66, 48]), radius=s(3), fill=ARMOR)
    # center gem (purple glowing)
    img = bg(img, 48, 40, 9, PURPLE, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([40, 34, 56, 46]), fill=PURPLE)
    d.ellipse(sb([41, 35, 55, 45]), fill=PURP_H)
    d.ellipse(sb([44, 38, 52, 42]), fill=(242, 222, 255))
    d.rectangle(sb([18, 24, 78, 27]), fill=GOLD)
    d.rectangle(sb([18, 54, 78, 57]), fill=GOLD)

    # PAULDRONS
    d.ellipse(sb([4, 17, 26, 36]), fill=ARMOR)
    d.ellipse(sb([4, 17, 14, 27]), fill=ARMOR_H)
    d.ellipse(sb([70, 17, 92, 36]), fill=ARMOR)
    d.ellipse(sb([80, 17, 92, 27]), fill=ARMOR_D)
    d.arc(sb([4, 17, 26, 36]), start=180, end=360, fill=GOLD, width=s(2))
    d.arc(sb([70, 17, 92, 36]), start=180, end=360, fill=GOLD, width=s(2))

    # ARMS
    d.rounded_rectangle(sb([6, 28, 20, 58]), radius=s(6), fill=ARMOR)
    d.rectangle(sb([6, 28, 12, 58]), fill=ARMOR_H)
    d.rounded_rectangle(sb([76, 22, 90, 50]), radius=s(6), fill=ARMOR)
    d.rectangle(sb([84, 22, 90, 50]), fill=ARMOR_D)

    # NECK GORGET
    d.rounded_rectangle(sb([37, 16, 59, 26]), radius=s(4), fill=ARMOR)

    # CROWN
    for cx in [26, 35, 47, 59, 68]:
        h = 9 if cx == 47 else 5
        d.rectangle(sb([cx, 4-h, cx+5, 8]), fill=GOLD)
        d.ellipse(sb([cx, 2-h, cx+5, 4-h+2]), fill=GOLD_D)
    d.rectangle(sb([24, 8, 72, 14]), fill=GOLD)
    d.ellipse(sb([30, 7, 38, 13]), fill=PURPLE)
    d.ellipse(sb([52, 7, 60, 13]), fill=PURPLE)
    d.ellipse(sb([42, 5, 52, 11]), fill=EYE)

    # HEAD
    d.ellipse(sb([26, 8, 70, 28]), fill=SKIN)
    d.ellipse(sb([26, 8, 40, 22]), fill=SKIN)
    d.ellipse(sb([56, 10, 70, 24]), fill=SKIN_D)

    # EYES glowing purple
    img = bg(img, 36, 18, 8, PURPLE, passes=5)
    img = bg(img, 60, 18, 8, PURPLE, passes=5)
    d = ImageDraw.Draw(img)
    for ex in [29, 53]:
        d.ellipse(sb([ex, 14, ex+14, 24]), fill=(12, 4, 20))
        d.ellipse(sb([ex+1, 15, ex+13, 23]), fill=PURPLE)
        d.ellipse(sb([ex+2, 16, ex+12, 22]), fill=PURP_H)
        d.ellipse(sb([ex+4, 17, ex+10, 21]), fill=(12, 4, 20))
        d.ellipse(sb([ex+2, 15, ex+4, 17]), fill=(255, 255, 255, 200))

    d.ellipse(sb([43, 22, 53, 26]), fill=SKIN_D)
    d.rectangle(sb([37, 26, 59, 29]), fill=(48, 18, 8))

    return img


def enemy_boss_warden():
    PLATE  = (52, 58, 64); PLATE_H = (88, 96, 102); PLATE_D = (26, 30, 34)
    GOLD   = (194, 154, 14); GOLD_D = (140, 104, 8)
    EYE    = (255, 204, 0)
    HALB   = (160, 168, 178); HALB_H = (195, 205, 218)
    RED    = (180, 28, 18)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([16, 88, 80, 96]), fill=(0, 0, 0, 75))

    # HALBERD (right, tall)
    d.rectangle(sb([78, 4, 84, 82]), fill=(90, 60, 24))
    d.rectangle(sb([79, 4, 82, 82]), fill=(120, 85, 35))
    d.polygon(sp([(73, 4), (89, 4), (91, 24), (79, 28), (74, 24)]), fill=HALB)
    d.polygon(sp([(75, 4), (87, 4), (87, 20), (79, 24)]), fill=HALB_H)
    d.polygon(sp([(89, 13), (96, 7), (93, 22)]), fill=HALB)
    d.rectangle(sb([75, 26, 92, 30]), fill=GOLD)

    # GREAVES
    d.rounded_rectangle(sb([22, 76, 46, 92]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([50, 76, 74, 92]), radius=s(5), fill=PLATE)
    d.rectangle(sb([22, 76, 30, 90]), fill=PLATE_H)
    d.ellipse(sb([24, 70, 44, 80]), fill=PLATE)
    d.ellipse(sb([52, 70, 72, 80]), fill=PLATE)

    # ARMORED LEGS
    d.rounded_rectangle(sb([22, 56, 46, 78]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([50, 56, 74, 78]), radius=s(5), fill=PLATE)
    d.rectangle(sb([22, 56, 28, 78]), fill=PLATE_H)
    d.rectangle(sb([68, 56, 74, 78]), fill=PLATE_D)

    # TASSETS
    d.rounded_rectangle(sb([18, 52, 78, 60]), radius=s(3), fill=PLATE_D)
    for bx in [20, 30, 42, 52, 62]:
        d.rounded_rectangle(sb([bx, 52, bx+8, 60]), radius=s(2), fill=PLATE)
    d.rectangle(sb([43, 50, 53, 62]), fill=GOLD)

    # MASSIVE BREASTPLATE
    d.rounded_rectangle(sb([14, 20, 82, 56]), radius=s(6), fill=PLATE)
    d.rectangle(sb([14, 20, 24, 56]), fill=PLATE_H)
    d.rectangle(sb([72, 20, 82, 56]), fill=PLATE_D)
    for ry in [24, 32, 40, 48]:
        d.rectangle(sb([16, ry, 80, ry+4]), fill=PLATE_D)
        d.rectangle(sb([16, ry, 22, ry+4]), fill=PLATE_H)
    d.rectangle(sb([14, 20, 82, 24]), fill=GOLD)
    d.rectangle(sb([14, 52, 82, 56]), fill=GOLD)
    # RED CROSS
    d.rectangle(sb([43, 28, 53, 48]), fill=RED)
    d.rectangle(sb([37, 34, 59, 42]), fill=RED)
    d.rectangle(sb([45, 30, 51, 46]), fill=(220, 40, 28))

    # TOWER PAULDRONS
    d.rounded_rectangle(sb([0, 14, 18, 42]), radius=s(5), fill=PLATE)
    d.rectangle(sb([0, 14, 6, 42]), fill=PLATE_H)
    d.rectangle(sb([12, 14, 18, 42]), fill=PLATE_D)
    d.rectangle(sb([0, 14, 18, 18]), fill=GOLD)
    d.rounded_rectangle(sb([78, 14, 96, 42]), radius=s(5), fill=PLATE)
    d.rectangle(sb([90, 14, 96, 42]), fill=PLATE_D)
    d.rectangle(sb([78, 14, 84, 42]), fill=PLATE_H)
    d.rectangle(sb([78, 14, 96, 18]), fill=GOLD)

    # ARMS + GAUNTLETS
    d.rounded_rectangle(sb([4, 28, 16, 56]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([80, 20, 92, 48]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([2, 52, 16, 66]), radius=s(4), fill=PLATE_D)
    d.rounded_rectangle(sb([80, 44, 94, 56]), radius=s(4), fill=PLATE_D)
    d.rectangle(sb([2, 52, 16, 55]), fill=GOLD)
    d.rectangle(sb([80, 44, 94, 47]), fill=GOLD)

    # CLOSED HELMET
    d.rounded_rectangle(sb([20, 2, 76, 24]), radius=s(6), fill=PLATE)
    d.rectangle(sb([20, 2, 28, 24]), fill=PLATE_H)
    d.rectangle(sb([68, 2, 76, 24]), fill=PLATE_D)
    d.rectangle(sb([26, 10, 70, 18]), fill=PLATE_D)
    # EYE SLIT glow
    img = bg(img, 38, 14, 9, EYE, passes=4)
    img = bg(img, 58, 14, 9, EYE, passes=4)
    d = ImageDraw.Draw(img)
    d.rectangle(sb([30, 11, 46, 16]), fill=(12, 8, 1))
    d.rectangle(sb([50, 11, 66, 16]), fill=(12, 8, 1))
    d.rectangle(sb([32, 12, 44, 15]), fill=EYE)
    d.rectangle(sb([52, 12, 64, 15]), fill=EYE)
    d.rectangle(sb([34, 12, 38, 15]), fill=(255, 235, 85))
    d.rectangle(sb([54, 12, 58, 15]), fill=(255, 235, 85))
    # HELM CREST
    d.rectangle(sb([44, 2, 52, 12]), fill=GOLD)
    d.rounded_rectangle(sb([24, 18, 72, 26]), radius=s(3), fill=PLATE)
    d.rectangle(sb([20, 22, 76, 26]), fill=GOLD)

    return img


def enemy_boss_abyss_keeper():
    BODY   = (22, 6, 46); BODY_H = (50, 18, 90); BODY_D = (10, 2, 26)
    TENT   = (38, 10, 70); TENT_D = (18, 3, 40)
    EYE1   = (220, 80, 255); EYE2 = (158, 18, 200)
    GLOW   = (180, 60, 255); GLOW2 = (120, 8, 180)
    ORB    = (250, 200, 255)

    img = bc(); d = ImageDraw.Draw(img)
    d.ellipse(sb([18, 88, 78, 96]), fill=(0, 0, 0, 80))

    # VOID AURA (very wide)
    for ax, ay, ar in [(48, 48, 48), (48, 72, 34), (18, 62, 26), (78, 60, 22)]:
        img = bg(img, ax, ay, ar, (120, 0, 200), passes=4)
    d = ImageDraw.Draw(img)

    # TENTACLES
    tentacles = [
        [(30, 62), (8, 72), (4, 88)],
        [(28, 64), (10, 80), (12, 92)],
        [(38, 68), (20, 82), (14, 90)],
        [(66, 62), (88, 72), (92, 88)],
        [(68, 64), (86, 80), (84, 92)],
        [(58, 68), (76, 82), (82, 90)],
        [(44, 68), (36, 84), (28, 90)],
        [(52, 68), (60, 84), (68, 90)],
    ]
    for pts in tentacles:
        flat = [c for pt in pts for c in (s(pt[0]), s(pt[1]))]
        d.line(flat, fill=TENT, width=s(5))
        d.line(flat, fill=TENT_D, width=s(2))
        mx = (pts[0][0] + pts[1][0]) // 2
        my = (pts[0][1] + pts[1][1]) // 2
        d.ellipse(sb([mx-3, my-3, mx+3, my+3]), fill=EYE2)

    # CLOAK/BODY
    d.ellipse(sb([14, 32, 82, 74]), fill=BODY)
    d.ellipse(sb([14, 32, 34, 54]), fill=BODY_H)
    d.ellipse(sb([62, 44, 82, 68]), fill=BODY_D)
    d.arc(sb([16, 34, 48, 66]), start=200, end=320, fill=BODY_H, width=s(2))

    # FLOATING ORBS
    for ox, oy, or_ in [(10, 34, 7), (86, 36, 6), (12, 58, 5), (84, 62, 5)]:
        img = bg(img, ox, oy, or_+4, GLOW, passes=3)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([ox-or_, oy-or_, ox+or_, oy+or_]), fill=GLOW)
        d.ellipse(sb([ox-or_+2, oy-or_+2, ox+or_-2, oy+or_-2]), fill=ORB)

    # SHADOWY ARM TENDRILS
    d.polygon(sp([(14, 38), (0, 28), (6, 52), (18, 50)]), fill=BODY)
    d.polygon(sp([(14, 38), (2, 30), (6, 48)]), fill=BODY_H)
    d.polygon(sp([(82, 38), (96, 28), (90, 52), (78, 50)]), fill=BODY)
    d.polygon(sp([(82, 38), (94, 30), (90, 48)]), fill=BODY_D)
    for cx, cy in [(0, 26), (2, 22), (6, 24), (10, 22)]:
        d.line(sp([(6, 32), (cx, cy)]), fill=TENT_D, width=s(2))
    for cx, cy in [(96, 26), (94, 22), (90, 24), (86, 22)]:
        d.line(sp([(90, 32), (cx, cy)]), fill=TENT_D, width=s(2))

    # NECK / UPPER BODY
    d.ellipse(sb([32, 16, 64, 42]), fill=BODY)
    d.ellipse(sb([32, 16, 44, 30]), fill=BODY_H)

    # HEAD
    d.ellipse(sb([22, 0, 74, 36]), fill=BODY)
    d.ellipse(sb([22, 0, 38, 18]), fill=BODY_H)
    d.ellipse(sb([58, 4, 74, 26]), fill=BODY_D)

    # CROWN TENTACLES FROM HEAD
    for hx, hy in [(26, 4), (36, 2), (48, 0), (60, 2), (70, 4)]:
        d.polygon(sp([(hx, 8), (hx-3, hy), (hx+3, hy)]), fill=TENT)
        img = bg(img, hx, hy, 4, EYE1, passes=2)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([hx-2, hy-2, hx+2, hy+2]), fill=EYE1)

    # 3 MAIN GLOWING EYES
    for ecx, ecy, er in [(34, 15, 8), (62, 15, 8), (48, 20, 10)]:
        img = bg(img, ecx, ecy, er+4, EYE1, passes=5)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([ecx-er, ecy-er, ecx+er, ecy+er]), fill=(8, 1, 15))
        d.ellipse(sb([ecx-er+1, ecy-er+1, ecx+er-1, ecy+er-1]), fill=EYE2)
        d.ellipse(sb([ecx-er+3, ecy-er+3, ecx+er-3, ecy+er-3]), fill=EYE1)
        d.ellipse(sb([ecx-3, ecy-3, ecx+3, ecy+3]), fill=(8, 1, 15))
        d.ellipse(sb([ecx-er+1, ecy-er+1, ecx-er+5, ecy-er+5]), fill=(255, 255, 255, 200))

    # MOUTH (toothy rift)
    d.arc(sb([30, 26, 66, 38]), start=10, end=170, fill=(6, 1, 12), width=s(3))
    for tx in [33, 38, 44, 52, 58]:
        d.polygon(sp([(tx, 29), (tx+2, 36), (tx+4, 29)]), fill=EYE1)

    # SCATTERED EYES ON BODY
    for ex, ey, er in [(18, 46, 4), (76, 44, 4), (22, 60, 3), (72, 58, 3)]:
        img = bg(img, ex, ey, er+2, EYE2, passes=2)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([ex-er, ey-er, ex+er, ey+er]), fill=(6, 1, 12))
        d.ellipse(sb([ex-er+1, ey-er+1, ex+er-1, ey+er-1]), fill=EYE2)
        d.ellipse(sb([ex-1, ey-1, ex+1, ey+1]), fill=(6, 1, 12))

    return img


# ════════════════════════════════════════════════════════════════════════════
# REGISTRY & MAIN
# ════════════════════════════════════════════════════════════════════════════

BATTLE_SPRITES = {
    "hero_brawler":            hero_brawler_sprite,
    "hero_rogue":              hero_rogue_sprite,
    "hero_arcanist":           hero_arcanist_sprite,
    "enemy_imp":               enemy_imp,
    "enemy_goblin":            enemy_goblin,
    "enemy_skeleton":          enemy_skeleton,
    "enemy_demon":             enemy_demon,
    "enemy_golem":             enemy_golem,
    "enemy_boss_dungeon_lord": enemy_boss_dungeon_lord,
    "enemy_boss_warden":       enemy_boss_warden,
    "enemy_boss_abyss_keeper": enemy_boss_abyss_keeper,
    "enemy_boss":              enemy_boss_dungeon_lord,   # legacy alias
}

PORTRAITS = {
    "brawler":  hero_brawler_portrait,
    "rogue":    hero_rogue_portrait,
    "arcanist": hero_arcanist_portrait,
}

if __name__ == "__main__":
    import sys
    only_portraits = "--portraits-only" in sys.argv
    only_sprites   = "--sprites-only"   in sys.argv

    if not only_portraits:
        print(f"Generating battle sprites → {SPRITES_DIR}/")
        for name, fn in BATTLE_SPRITES.items():
            save_sprite(fn(), name)

    if not only_sprites:
        print(f"Generating portraits → {PORTRAITS_DIR}/")
        for name, fn in PORTRAITS.items():
            save_portrait(fn(), name)

    print("Done.")
