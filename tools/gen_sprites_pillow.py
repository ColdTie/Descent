#!/usr/bin/env python3
"""Generate high-quality pixel-art PNG sprites for DESCENT using Pillow.

96x96 canvas. Each character has multi-layer shading, highlights, and a
dark outline pass. PNGs load in Godot headlessly without editor import.
"""

import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 96
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def new_img() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def add_outline(img: Image.Image, color=(8, 4, 14, 255), expand=2) -> Image.Image:
    """Dilate the alpha channel then underlay the outline color."""
    alpha = img.getchannel("A")
    expanded = alpha.filter(ImageFilter.MaxFilter(expand * 2 + 1))
    outline_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pix_in = expanded.load()
    pix_orig = alpha.load()
    pix_out = outline_layer.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if pix_in[x, y] > 0 and pix_orig[x, y] < 10:
                pix_out[x, y] = color
    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(outline_layer, (0, 0))
    result.paste(img, (0, 0), img)
    return result


def shadow_ellipse(d, x0, y0, x1, y1, opacity=60):
    """Draw ground shadow ellipse."""
    sx, sy = (x0 + x1) // 2, (y0 + y1) // 2
    rx, ry = (x1 - x0) // 2, (y1 - y0) // 2
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([x0, y0, x1, y1], fill=(0, 0, 0, opacity))
    return shadow


def save(img: Image.Image, name: str):
    path = os.path.join(OUTPUT_DIR, name + ".png")
    img = add_outline(img)
    img.save(path)
    print(f"  {name}.png  ({os.path.getsize(path):,} bytes)")


# ---------------------------------------------------------------------------
# Hero Brawler — Carl, blue-collar fighter
# ---------------------------------------------------------------------------

def hero_brawler() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    # --- Colour palette ---
    SKIN, SKIN_D, SKIN_H = (195, 130, 80), (140, 85, 45), (225, 160, 105)
    HAIR = (22, 12, 4)
    TANK, TANK_H, TANK_D = (28, 55, 115), (42, 75, 145), (16, 35, 80)
    JEANS, JEANS_H = (35, 50, 90), (50, 68, 115)
    BOOT = (20, 12, 6)
    BELT, BUCKLE = (55, 35, 15), (115, 80, 30)

    # Ground shadow
    d.ellipse([26, 89, 70, 95], fill=(0, 0, 0, 55))

    # BOOTS
    d.rounded_rectangle([28, 79, 47, 92], radius=4, fill=BOOT)
    d.rounded_rectangle([49, 79, 68, 92], radius=4, fill=BOOT)
    d.rectangle([29, 79, 36, 84], fill=(35, 22, 10))

    # JEANS
    d.rounded_rectangle([29, 55, 46, 82], radius=5, fill=JEANS)
    d.rounded_rectangle([50, 55, 67, 82], radius=5, fill=JEANS)
    d.rectangle([29, 55, 34, 82], fill=JEANS_H)

    # BELT
    d.rounded_rectangle([26, 52, 70, 58], radius=2, fill=BELT)
    d.rectangle([43, 50, 53, 60], fill=(80, 52, 20))   # buckle bg
    d.rectangle([45, 52, 51, 58], fill=BUCKLE)          # buckle face

    # TORSO — tank top (dark, shows muscles)
    d.rounded_rectangle([24, 26, 72, 55], radius=5, fill=(30, 30, 30))
    d.rectangle([24, 26, 30, 55], fill=(44, 44, 44))    # left hi
    d.rectangle([66, 26, 72, 55], fill=(18, 18, 18))    # right shadow
    # Straps
    d.rounded_rectangle([29, 16, 39, 28], radius=3, fill=(30, 30, 30))
    d.rounded_rectangle([57, 16, 67, 28], radius=3, fill=(30, 30, 30))
    # V-neck
    d.polygon([(38, 26), (58, 26), (48, 35)], fill=(20, 20, 20))

    # LEFT ARM — extended punch
    d.rounded_rectangle([3, 24, 25, 52], radius=8, fill=SKIN)
    d.rectangle([3, 24, 9, 52], fill=SKIN_H)
    # Fist
    d.rounded_rectangle([1, 50, 22, 66], radius=4, fill=SKIN_D)
    d.rectangle([2, 51, 8, 65], fill=SKIN)
    for y in [54, 58, 62]:
        d.line([(2, y), (20, y)], fill=(100, 50, 15), width=1)

    # RIGHT ARM — guard raised
    d.rounded_rectangle([71, 12, 93, 40], radius=8, fill=SKIN)
    d.rectangle([71, 12, 77, 40], fill=SKIN_H)
    # Fist raised
    d.rounded_rectangle([71, 6, 93, 22], radius=4, fill=SKIN_D)
    d.rectangle([72, 7, 78, 21], fill=SKIN)
    for y in [10, 14, 18]:
        d.line([(72, y), (91, y)], fill=(100, 50, 15), width=1)

    # NECK
    d.rounded_rectangle([40, 16, 56, 28], radius=4, fill=SKIN)

    # HEAD (slightly wider than tall, masculine)
    d.ellipse([27, 0, 69, 20], fill=SKIN)     # hair zone
    d.ellipse([26, 2, 70, 26], fill=SKIN)     # main face

    # Face shading
    d.ellipse([26, 2, 40, 18], fill=SKIN_H)   # left hi
    d.ellipse([58, 4, 70, 20], fill=SKIN_D)   # right shadow

    # HAIR
    d.ellipse([25, 0, 71, 12], fill=HAIR)
    d.ellipse([23, 2, 36, 14], fill=HAIR)
    d.ellipse([60, 2, 73, 14], fill=HAIR)
    # Stubble chin
    d.rectangle([37, 23, 59, 29], fill=(25, 14, 5))

    # BROWS — furrowed
    d.polygon([(29, 11), (42, 13), (40, 16), (30, 14)], fill=HAIR)
    d.polygon([(67, 11), (54, 13), (56, 16), (66, 14)], fill=HAIR)

    # EYES
    for ex in [36, 54]:
        d.ellipse([ex, 13, ex+10, 21], fill=(12, 8, 4))
        d.ellipse([ex+1, 14, ex+9, 20], fill=(80, 45, 15))
        d.ellipse([ex+2, 15, ex+8, 19], fill=(120, 65, 20))
        d.ellipse([ex+3, 15, ex+7, 19], fill=(10, 6, 2))
        d.ellipse([ex+2, 14, ex+4, 16], fill=(255, 255, 255, 160))

    # NOSE
    d.ellipse([44, 19, 52, 25], fill=SKIN_D)
    d.ellipse([44, 22, 47, 25], fill=(100, 55, 20))
    d.ellipse([49, 22, 52, 25], fill=(100, 55, 20))

    # MOUTH — tight grim line
    d.rectangle([39, 26, 57, 29], fill=(85, 30, 10))
    d.rectangle([40, 26, 56, 27], fill=(130, 50, 15))

    # Cheek bruise
    d.ellipse([55, 18, 66, 24], fill=(70, 40, 130, 55))

    return img


# ---------------------------------------------------------------------------
# Hero Rogue — shadow assassin
# ---------------------------------------------------------------------------

def hero_rogue() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    SKIN, SKIN_D = (180, 140, 100), (120, 90, 60)
    CLOAK, CLOAK_H, CLOAK_D = (35, 22, 50), (55, 38, 75), (18, 10, 28)
    BLADE, BLADE_H = (200, 210, 225), (240, 245, 255)
    BOOT = (20, 14, 10)
    ACCENT = (170, 130, 220)

    d.ellipse([24, 89, 72, 95], fill=(0, 0, 0, 55))

    # BOOTS
    d.rounded_rectangle([28, 79, 46, 92], radius=4, fill=BOOT)
    d.rounded_rectangle([50, 79, 68, 92], radius=4, fill=BOOT)

    # LEGS (cloak covers most)
    d.rounded_rectangle([29, 56, 45, 81], radius=5, fill=CLOAK_D)
    d.rounded_rectangle([51, 56, 67, 81], radius=5, fill=CLOAK_D)

    # CLOAK body — sweeping shape
    d.polygon([(20, 30), (76, 30), (80, 88), (16, 88)], fill=CLOAK)
    d.polygon([(22, 30), (72, 30), (68, 88), (26, 88)], fill=CLOAK_H)
    d.rectangle([22, 30, 27, 88], fill=CLOAK_H)   # left edge hi
    d.rectangle([69, 30, 74, 88], fill=CLOAK_D)   # right edge sh

    # DAGGER (left hand, blade forward)
    d.rectangle([4, 44, 8, 78], fill=(95, 65, 22))    # handle
    d.rectangle([5, 50, 7, 60], fill=(145, 100, 35))  # grip wrap
    d.rectangle([2, 42, 10, 46], fill=(140, 110, 45)) # crossguard
    d.polygon([(4, 22), (8, 22), (6, 42)], fill=BLADE)
    d.polygon([(5, 22), (7, 22), (6, 30)], fill=BLADE_H)

    # LEFT ARM holding dagger
    d.rounded_rectangle([8, 28, 22, 52], radius=6, fill=CLOAK)
    d.rectangle([8, 28, 13, 52], fill=CLOAK_H)

    # RIGHT ARM (hidden in cloak)
    d.rounded_rectangle([74, 28, 88, 52], radius=6, fill=CLOAK)
    d.rectangle([82, 28, 87, 52], fill=CLOAK_D)

    # HOOD
    d.ellipse([24, 4, 72, 36], fill=CLOAK_D)
    d.ellipse([28, 10, 68, 36], fill=CLOAK)          # inner hood
    d.ellipse([24, 4, 50, 22], fill=CLOAK_H)         # hood left hi

    # FACE (shadowed in hood)
    d.ellipse([32, 16, 64, 38], fill=SKIN_D)
    d.ellipse([32, 16, 44, 28], fill=SKIN)            # left face hi
    # Mask (lower half)
    d.rectangle([32, 28, 64, 38], fill=CLOAK_D)

    # EYES — glowing purple
    for ex in [36, 52]:
        d.ellipse([ex, 20, ex+10, 28], fill=(10, 4, 18))
        d.ellipse([ex+1, 21, ex+9, 27], fill=ACCENT)
        d.ellipse([ex+2, 22, ex+8, 26], fill=(210, 180, 255))
        d.ellipse([ex+3, 22, ex+7, 26], fill=(14, 6, 22))
        d.ellipse([ex+2, 21, ex+4, 23], fill=(255, 255, 255, 160))

    # Cloak accent trim
    d.line([(20, 30), (16, 88)], fill=ACCENT, width=2)
    d.line([(76, 30), (80, 88)], fill=ACCENT, width=2)
    # Hood clasp
    d.ellipse([44, 30, 52, 38], fill=ACCENT)
    d.ellipse([46, 32, 50, 36], fill=(140, 100, 200))

    return img


# ---------------------------------------------------------------------------
# Hero Arcanist — robed mage
# ---------------------------------------------------------------------------

def hero_arcanist() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    SKIN, SKIN_D = (195, 155, 110), (145, 105, 65)
    ROBE, ROBE_H, ROBE_D = (48, 28, 88), (68, 44, 118), (28, 14, 55)
    BEARD = (205, 200, 190)
    GLOW, GLOW_H = (170, 110, 255), (220, 180, 255)
    WOOD = (90, 60, 22)
    HAT = (38, 22, 70)
    RUNE = (130, 80, 220)

    d.ellipse([24, 89, 72, 95], fill=(0, 0, 0, 55))

    # ROBE (wide flowing)
    d.polygon([(22, 34), (74, 34), (82, 92), (14, 92)], fill=ROBE)
    d.polygon([(24, 34), (70, 34), (76, 92), (20, 92)], fill=ROBE_H)
    d.rectangle([22, 34, 28, 90], fill=ROBE_H)   # left hi
    d.rectangle([70, 34, 76, 90], fill=ROBE_D)   # right shadow
    # Robe belt
    d.rounded_rectangle([28, 52, 68, 58], radius=3, fill=ROBE_D)
    # Arcane symbol on robe
    d.ellipse([42, 62, 54, 74], fill=RUNE)
    d.ellipse([44, 64, 52, 72], fill=ROBE)        # ring hollow
    d.ellipse([47, 67, 49, 69], fill=RUNE)        # center dot

    # STAFF (left side)
    d.rectangle([5, 10, 10, 78], fill=WOOD)
    d.rectangle([6, 10, 8, 78], fill=(120, 85, 35))  # wood hi
    # Crystal orb on top
    d.ellipse([0, 2, 16, 18], fill=GLOW)
    d.ellipse([2, 4, 12, 14], fill=GLOW_H)
    d.ellipse([4, 5, 8, 9], fill=(240, 230, 255, 200))
    # Staff rings
    d.rectangle([4, 25, 11, 28], fill=(130, 90, 35))
    d.rectangle([4, 48, 11, 51], fill=(130, 90, 35))

    # LEFT ARM (holding staff)
    d.rounded_rectangle([10, 32, 24, 58], radius=6, fill=ROBE)
    d.rectangle([10, 32, 15, 58], fill=ROBE_H)

    # RIGHT ARM (casting gesture)
    d.rounded_rectangle([72, 28, 88, 52], radius=6, fill=ROBE)
    d.rectangle([82, 28, 87, 52], fill=ROBE_D)
    # Casting hand glow
    d.ellipse([80, 48, 92, 60], fill=GLOW)
    d.ellipse([82, 50, 90, 58], fill=GLOW_H)

    # NECK
    d.rounded_rectangle([40, 20, 56, 34], radius=4, fill=SKIN)

    # HEAD
    d.ellipse([30, 4, 66, 26], fill=SKIN)
    d.ellipse([30, 4, 44, 18], fill=SKIN)          # left face hi
    d.ellipse([54, 6, 66, 20], fill=SKIN_D)         # right shadow

    # POINTED HAT
    d.polygon([(48, 0), (28, 22), (68, 22)], fill=HAT)
    d.polygon([(48, 0), (30, 20), (48, 20)], fill=(58, 38, 95))  # left face
    d.ellipse([26, 18, 70, 28], fill=HAT)           # brim
    d.ellipse([26, 18, 48, 26], fill=(58, 38, 95))  # brim left
    # Star on hat
    d.ellipse([44, 5, 52, 13], fill=GLOW)
    d.ellipse([45, 6, 51, 12], fill=GLOW_H)

    # BEARD (long, white)
    d.polygon([(33, 24), (63, 24), (60, 38), (36, 38)], fill=BEARD)
    d.rectangle([33, 24, 38, 38], fill=(230, 225, 215))  # hi

    # BROWS — bushy
    d.rectangle([33, 10, 44, 13], fill=(160, 155, 145))
    d.rectangle([52, 10, 63, 13], fill=(160, 155, 145))

    # EYES — glowing blue
    for ex in [35, 53]:
        d.ellipse([ex, 13, ex+10, 21], fill=(10, 6, 20))
        d.ellipse([ex+1, 14, ex+9, 20], fill=(80, 50, 170))
        d.ellipse([ex+2, 15, ex+8, 19], fill=(160, 100, 255))
        d.ellipse([ex+3, 15, ex+7, 19], fill=(10, 6, 20))
        d.ellipse([ex+2, 14, ex+4, 16], fill=(255, 255, 255, 180))

    # NOSE
    d.ellipse([44, 19, 52, 25], fill=SKIN_D)

    return img


# ---------------------------------------------------------------------------
# Enemy Imp — small flying devil
# ---------------------------------------------------------------------------

def enemy_imp() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    RED, RED_D, RED_H = (195, 35, 20), (130, 18, 8), (235, 75, 50)
    WING, WING_D = (155, 18, 10), (90, 8, 4)
    EYE = (255, 195, 0)
    CLAW = (80, 50, 20)
    TAIL = (170, 28, 14)

    d.ellipse([24, 89, 72, 95], fill=(0, 0, 0, 45))

    # WINGS (spread out, bat-like)
    d.polygon([(48, 30), (4, 6), (18, 38), (38, 36)], fill=WING)
    d.polygon([(48, 30), (4, 6), (12, 28), (30, 32)], fill=WING_D)
    d.polygon([(48, 30), (92, 6), (78, 38), (58, 36)], fill=WING)
    d.polygon([(48, 30), (92, 6), (84, 28), (66, 32)], fill=WING_D)
    # Wing bone lines
    d.line([(48, 30), (4, 6)], fill=RED_D, width=2)
    d.line([(48, 30), (92, 6)], fill=RED_D, width=2)
    d.line([(20, 38), (4, 6)], fill=RED_D, width=1)
    d.line([(76, 38), (92, 6)], fill=RED_D, width=1)

    # TAIL (curling to the right)
    d.line([(56, 64), (70, 72), (78, 66), (82, 76)], fill=TAIL, width=4)
    d.polygon([(78, 72), (86, 70), (82, 80)], fill=RED_D)   # barb

    # BODY (small, round)
    d.ellipse([30, 38, 66, 76], fill=RED)
    d.ellipse([30, 38, 44, 56], fill=RED_H)   # left hi
    d.ellipse([52, 52, 66, 68], fill=RED_D)   # right shadow

    # ARMS / CLAWS
    d.rounded_rectangle([14, 42, 30, 56], radius=5, fill=RED)
    d.rounded_rectangle([66, 42, 82, 56], radius=5, fill=RED)
    # Claws left
    for cx, cy in [(8, 54), (11, 58), (15, 60)]:
        d.polygon([(14, 52), (cx, cy), (16, 54)], fill=CLAW)
    # Claws right
    for cx, cy in [(88, 54), (85, 58), (81, 60)]:
        d.polygon([(82, 52), (cx, cy), (80, 54)], fill=CLAW)

    # LEGS (small, clawed)
    d.rounded_rectangle([34, 72, 44, 84], radius=4, fill=RED)
    d.rounded_rectangle([52, 72, 62, 84], radius=4, fill=RED)
    for cx, cy in [(29, 86), (34, 90), (40, 88)]:
        d.polygon([(34, 84), (cx, cy), (38, 84)], fill=CLAW)
    for cx, cy in [(57, 90), (63, 86), (67, 90)]:
        d.polygon([(58, 84), (cx, cy), (62, 84)], fill=CLAW)

    # HEAD (large relative to body, with horns)
    d.ellipse([30, 24, 66, 52], fill=RED)
    d.ellipse([30, 24, 44, 40], fill=RED_H)

    # HORNS
    d.polygon([(34, 26), (28, 8), (40, 24)], fill=RED_D)
    d.polygon([(62, 26), (68, 8), (56, 24)], fill=RED_D)

    # EYES — large, menacing
    for ex in [33, 51]:
        d.ellipse([ex, 32, ex+12, 44], fill=(12, 6, 2))
        d.ellipse([ex+1, 33, ex+11, 43], fill=EYE)
        d.ellipse([ex+2, 34, ex+10, 42], fill=(255, 220, 50))
        d.ellipse([ex+3, 35, ex+9, 41], fill=(10, 4, 2))
        d.ellipse([ex+2, 33, ex+4, 35], fill=(255, 255, 255, 180))

    # MOUTH (jagged grin)
    d.arc([34, 40, 62, 54], start=10, end=170, fill=RED_D, width=2)
    for tx in [37, 42, 47, 52, 57]:
        d.polygon([(tx, 44), (tx+2, 48), (tx+4, 44)], fill=(230, 215, 195))

    return img


# ---------------------------------------------------------------------------
# Enemy Goblin — small green brute
# ---------------------------------------------------------------------------

def enemy_goblin() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    GREEN, GREEN_D, GREEN_H = (75, 145, 50), (45, 92, 28), (105, 185, 70)
    EYE = (255, 190, 0)
    LEATHER, LEATHER_D = (75, 50, 22), (50, 32, 12)
    METAL = (100, 95, 85)
    CLUB = (105, 72, 28)
    BOOT = (45, 28, 12)
    TOOTH = (220, 215, 185)

    d.ellipse([24, 89, 72, 95], fill=(0, 0, 0, 55))

    # CLUB (left hand, raised)
    d.rectangle([5, 8, 13, 58], fill=CLUB)
    d.rectangle([6, 8, 10, 58], fill=(135, 95, 40))
    d.ellipse([0, 2, 18, 22], fill=CLUB)
    d.ellipse([2, 4, 14, 18], fill=(135, 95, 40))
    # Studs on club
    for sy in [6, 10, 14]:
        d.ellipse([1, sy, 5, sy+4], fill=METAL)
        d.ellipse([13, sy, 17, sy+4], fill=METAL)
    # Club wrap
    for wy in [26, 34, 42, 50]:
        d.rectangle([4, wy, 14, wy+3], fill=LEATHER_D)

    # BOOTS
    d.rounded_rectangle([28, 79, 46, 92], radius=4, fill=BOOT)
    d.rounded_rectangle([50, 79, 68, 92], radius=4, fill=BOOT)

    # LEGS (squat, bowed)
    d.ellipse([26, 60, 46, 84], fill=GREEN)
    d.ellipse([50, 60, 70, 84], fill=GREEN)
    d.rectangle([26, 60, 32, 80], fill=GREEN_H)

    # BELT (wide, studded)
    d.rounded_rectangle([24, 55, 72, 63], radius=2, fill=LEATHER)
    for bx in [28, 36, 50, 58, 66]:
        d.ellipse([bx, 57, bx+4, 61], fill=METAL)
    d.rectangle([44, 54, 52, 64], fill=LEATHER_D)

    # TORSO (leather chest plate)
    d.rounded_rectangle([24, 30, 72, 58], radius=5, fill=LEATHER)
    d.rectangle([24, 30, 30, 58], fill=(95, 65, 28))
    d.rectangle([66, 30, 72, 58], fill=LEATHER_D)
    # Chest stitching
    d.line([(44, 31), (44, 57)], fill=LEATHER_D, width=2)
    d.rectangle([28, 36, 42, 50], fill=LEATHER_D)   # patch
    d.rectangle([52, 38, 64, 50], fill=LEATHER_D)

    # EARS (big, pointed)
    d.polygon([(22, 24), (4, 12), (8, 36), (22, 34)], fill=GREEN)
    d.polygon([(22, 24), (6, 14), (8, 30)], fill=GREEN_H)
    d.polygon([(74, 24), (92, 12), (88, 36), (74, 34)], fill=GREEN)
    d.polygon([(74, 24), (90, 14), (88, 30)], fill=GREEN_D)

    # LEFT ARM
    d.rounded_rectangle([10, 28, 24, 54], radius=6, fill=GREEN)
    d.rectangle([10, 28, 15, 54], fill=GREEN_H)

    # RIGHT ARM + BUCKLER SHIELD
    d.rounded_rectangle([72, 28, 88, 54], radius=6, fill=GREEN)
    d.ellipse([76, 50, 94, 68], fill=LEATHER)
    d.ellipse([78, 52, 92, 66], fill=LEATHER_D)
    d.ellipse([82, 56, 88, 62], fill=METAL)
    d.ellipse([83, 57, 87, 61], fill=(150, 140, 120))

    # NECK
    d.rounded_rectangle([40, 22, 56, 32], radius=4, fill=GREEN)

    # CRUDE HELMET
    d.ellipse([26, 8, 70, 30], fill=METAL)
    d.rectangle([26, 16, 70, 30], fill=METAL)
    d.rectangle([26, 16, 30, 30], fill=(130, 125, 110))
    d.ellipse([26, 10, 40, 22], fill=(128, 122, 108))
    # Helmet rivets
    for hx in [32, 48, 64]:
        d.ellipse([hx, 11, hx+4, 15], fill=(140, 130, 110))

    # HEAD
    d.ellipse([27, 12, 69, 36], fill=GREEN)
    d.ellipse([27, 12, 40, 26], fill=GREEN_H)
    d.ellipse([56, 16, 69, 30], fill=GREEN_D)

    # BROW RIDGE
    d.rectangle([29, 22, 42, 26], fill=GREEN_D)
    d.rectangle([54, 22, 67, 26], fill=GREEN_D)

    # EYES (beady yellow, slit pupil)
    for ex in [30, 52]:
        d.ellipse([ex, 24, ex+14, 34], fill=(10, 6, 2))
        d.ellipse([ex+1, 25, ex+13, 33], fill=EYE)
        d.ellipse([ex+2, 26, ex+12, 32], fill=(255, 210, 40))
        d.rectangle([ex+6, 25, ex+8, 33], fill=(10, 6, 2))   # slit pupil
        d.ellipse([ex+2, 25, ex+4, 27], fill=(255, 255, 255, 160))

    # NOSE (flat, wide)
    d.ellipse([43, 30, 53, 36], fill=GREEN_D)
    d.ellipse([43, 33, 46, 36], fill=(30, 60, 18))
    d.ellipse([50, 33, 53, 36], fill=(30, 60, 18))

    # MOUTH (jagged grin)
    d.arc([32, 34, 64, 46], start=15, end=165, fill=GREEN_D, width=2)
    for tx in [35, 40, 48, 56]:
        d.polygon([(tx, 37), (tx+2, 42), (tx+4, 37)], fill=TOOTH)
    # Tusk
    d.polygon([(46, 37), (50, 47), (54, 37)], fill=(235, 228, 200))

    return img


# ---------------------------------------------------------------------------
# Enemy Skeleton — undead warrior
# ---------------------------------------------------------------------------

def enemy_skeleton() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    BONE, BONE_D, BONE_H = (225, 215, 188), (155, 142, 118), (245, 238, 218)
    RUST, RUST_D = (110, 75, 40), (70, 45, 22)
    EYE = (220, 50, 20)
    BLADE = (175, 182, 192)

    d.ellipse([24, 89, 72, 95], fill=(0, 0, 0, 55))

    # SWORD (right hand, held upright)
    d.rectangle([75, 10, 80, 68], fill=BLADE)
    d.rectangle([76, 10, 78, 68], fill=(210, 218, 228))
    d.rectangle([68, 38, 87, 44], fill=(130, 90, 35))   # crossguard
    d.rounded_rectangle([74, 62, 81, 74], radius=3, fill=(100, 70, 28)) # grip
    d.rectangle([75, 62, 79, 74], fill=(130, 95, 40))
    d.ellipse([74, 72, 81, 79], fill=(120, 85, 30))     # pommel

    # BOOTS (foot bones)
    d.rounded_rectangle([28, 80, 46, 92], radius=3, fill=BONE_D)
    d.rounded_rectangle([50, 80, 68, 92], radius=3, fill=BONE_D)
    for bx in [29, 34, 39]:
        d.rectangle([bx, 80, bx+3, 84], fill=BONE)
    for bx in [51, 56, 61]:
        d.rectangle([bx, 80, bx+3, 84], fill=BONE)

    # SHIN BONES
    d.rectangle([32, 60, 38, 82], fill=BONE)
    d.rectangle([33, 60, 36, 82], fill=BONE_H)
    d.rectangle([58, 60, 64, 82], fill=BONE)
    d.rectangle([59, 60, 62, 82], fill=BONE_H)

    # KNEE CAPS
    d.ellipse([29, 55, 42, 65], fill=BONE)
    d.ellipse([54, 55, 67, 65], fill=BONE)

    # THIGH BONES
    d.rectangle([30, 44, 40, 62], fill=BONE)
    d.rectangle([56, 44, 66, 62], fill=BONE)
    d.rectangle([31, 44, 34, 62], fill=BONE_H)

    # PELVIS
    d.ellipse([28, 42, 68, 58], fill=BONE)
    d.ellipse([32, 46, 46, 56], fill=BONE_D)   # left socket
    d.ellipse([50, 46, 64, 56], fill=BONE_D)

    # RUSTY CHAINMAIL / BREASTPLATE
    d.rounded_rectangle([26, 26, 70, 46], radius=4, fill=RUST)
    d.rectangle([26, 26, 32, 46], fill=(130, 90, 50))
    d.rectangle([64, 26, 70, 46], fill=RUST_D)
    # Chainmail texture
    for ry in range(28, 44, 4):
        for rx in range(28, 68, 4):
            d.ellipse([rx, ry, rx+3, ry+3], fill=RUST_D)

    # RIBS (visible below mail)
    for rib_y in [27, 31, 35, 39, 43]:
        d.arc([28, rib_y, 46, rib_y+6], start=180, end=360, fill=BONE, width=2)
        d.arc([50, rib_y, 68, rib_y+6], start=0, end=180, fill=BONE, width=2)

    # SPINE (center)
    for sy in [26, 32, 38, 44]:
        d.ellipse([45, sy, 51, sy+4], fill=BONE)

    # LEFT ARM BONES
    d.rounded_rectangle([10, 24, 26, 44], radius=6, fill=BONE)
    d.rectangle([11, 24, 14, 44], fill=BONE_H)
    d.ellipse([8, 22, 22, 28], fill=BONE)   # shoulder
    # Hand bones
    for hb in [8, 12, 16]:
        d.rectangle([hb, 44, hb+3, 54], fill=BONE)
    d.rectangle([8, 42, 20, 46], fill=BONE)

    # RIGHT ARM (sword arm)
    d.rounded_rectangle([70, 24, 86, 44], radius=6, fill=BONE)
    d.rectangle([82, 24, 85, 44], fill=BONE_H)
    d.ellipse([74, 22, 88, 28], fill=BONE)

    # NECK
    for nv in [26, 30, 34]:
        d.ellipse([44, nv, 52, nv+4], fill=BONE)

    # SKULL
    d.ellipse([28, 2, 68, 30], fill=BONE)
    d.ellipse([28, 2, 44, 18], fill=BONE_H)
    d.ellipse([52, 4, 68, 22], fill=BONE_D)
    # Jaw
    d.rounded_rectangle([34, 22, 62, 32], radius=4, fill=BONE_D)

    # EYE SOCKETS (hollow, glowing)
    d.ellipse([32, 10, 46, 22], fill=(20, 8, 4))
    d.ellipse([50, 10, 64, 22], fill=(20, 8, 4))
    d.ellipse([34, 12, 44, 20], fill=EYE)
    d.ellipse([52, 12, 62, 20], fill=EYE)
    d.ellipse([35, 13, 43, 19], fill=(255, 90, 40))
    d.ellipse([53, 13, 61, 19], fill=(255, 90, 40))

    # NOSE CAVITY
    d.polygon([(44, 22), (48, 28), (52, 22)], fill=(18, 8, 4))

    # TEETH
    for tx in [37, 41, 45, 49, 53, 57]:
        d.rectangle([tx, 28, tx+3, 34], fill=BONE_H)

    return img


# ---------------------------------------------------------------------------
# Enemy Demon — large crimson brute
# ---------------------------------------------------------------------------

def enemy_demon() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    RED, RED_D, RED_H = (165, 22, 12), (105, 10, 5), (215, 60, 38)
    HORN = (55, 32, 18)
    EYE = (255, 145, 0)
    FIRE = (255, 180, 0)
    FIRE2 = (255, 100, 10)
    CLAW = (60, 38, 18)

    d.ellipse([20, 89, 76, 95], fill=(0, 0, 0, 65))

    # FIRE AURA (behind body)
    for fx, fy, fr in [(48, 78, 18), (32, 70, 12), (64, 72, 14), (48, 90, 10)]:
        d.ellipse([fx-fr, fy-fr, fx+fr, fy+fr], fill=(255, 80, 0, 60))
    for fx, fy, fr in [(48, 80, 10), (34, 72, 7), (62, 74, 8)]:
        d.ellipse([fx-fr, fy-fr, fx+fr, fy+fr], fill=(255, 160, 0, 80))

    # TAIL (spiked, wraps right side)
    d.line([(62, 58), (78, 66), (84, 60), (88, 72), (84, 82)], fill=RED_D, width=5)
    d.polygon([(82, 78), (90, 74), (86, 86)], fill=RED_D)

    # LEGS (massive)
    d.rounded_rectangle([26, 56, 48, 88], radius=8, fill=RED)
    d.rounded_rectangle([52, 56, 74, 88], radius=8, fill=RED)
    d.rectangle([26, 56, 34, 88], fill=RED_H)
    d.rectangle([66, 56, 74, 88], fill=RED_D)
    # Clawed feet
    for cx, cy in [(20, 88), (26, 92), (32, 90), (38, 94)]:
        d.polygon([(28, 86), (cx, cy), (34, 86)], fill=CLAW)
    for cx, cy in [(58, 88), (64, 92), (70, 90), (76, 94)]:
        d.polygon([(58, 86), (cx, cy), (70, 86)], fill=CLAW)

    # BODY (huge, muscular)
    d.ellipse([18, 26, 78, 62], fill=RED)
    d.ellipse([18, 26, 36, 46], fill=RED_H)
    d.ellipse([60, 32, 78, 56], fill=RED_D)
    # Muscle definition
    d.arc([22, 32, 44, 54], start=200, end=340, fill=RED_D, width=3)
    d.arc([52, 32, 74, 54], start=200, end=340, fill=RED_D, width=3)

    # LEFT ARM (claw forward, aggressive)
    d.rounded_rectangle([2, 22, 22, 54], radius=8, fill=RED)
    d.rectangle([2, 22, 8, 54], fill=RED_H)
    # Claws
    for cx, cy in [(0, 54), (4, 60), (8, 62), (14, 60)]:
        d.polygon([(4, 52), (cx, cy), (12, 52)], fill=CLAW)

    # RIGHT ARM (raised, menacing)
    d.rounded_rectangle([74, 14, 94, 48], radius=8, fill=RED)
    d.rectangle([88, 14, 94, 48], fill=RED_D)
    # Claws raised
    for cx, cy in [(76, 8), (82, 4), (88, 6), (94, 10)]:
        d.polygon([(80, 16), (cx, cy), (90, 16)], fill=CLAW)

    # NECK
    d.rounded_rectangle([38, 18, 58, 30], radius=5, fill=RED)

    # HEAD (imposing, horned)
    d.ellipse([24, 4, 72, 32], fill=RED)
    d.ellipse([24, 4, 40, 20], fill=RED_H)
    d.ellipse([58, 6, 72, 24], fill=RED_D)

    # HORNS (large curving)
    d.polygon([(30, 8), (8, 0), (22, 22), (34, 18)], fill=HORN)
    d.polygon([(30, 8), (10, 2), (18, 18)], fill=(80, 50, 25))
    d.polygon([(66, 8), (88, 0), (74, 22), (62, 18)], fill=HORN)
    d.polygon([(66, 8), (86, 2), (78, 18)], fill=(80, 50, 25))

    # EYES (burning orange)
    for ex in [30, 54]:
        d.ellipse([ex, 14, ex+14, 24], fill=(14, 4, 2))
        d.ellipse([ex+1, 15, ex+13, 23], fill=EYE)
        d.ellipse([ex+2, 16, ex+12, 22], fill=(255, 190, 40))
        d.ellipse([ex+4, 17, ex+10, 21], fill=(14, 4, 2))
        d.ellipse([ex+2, 15, ex+4, 17], fill=(255, 255, 200, 200))
        # Fire pupils
        d.polygon([(ex+5, 16), (ex+7, 14), (ex+9, 16), (ex+7, 22)], fill=FIRE2)

    # NOSE (broad)
    d.ellipse([44, 22, 52, 28], fill=RED_D)
    d.ellipse([44, 25, 47, 28], fill=(80, 8, 4))
    d.ellipse([49, 25, 52, 28], fill=(80, 8, 4))

    # MOUTH (fanged snarl)
    d.arc([30, 26, 66, 36], start=10, end=170, fill=RED_D, width=2)
    for tx in [33, 38, 44, 52, 58]:
        d.polygon([(tx, 28), (tx+2, 35), (tx+4, 28)], fill=(235, 220, 200))

    return img


# ---------------------------------------------------------------------------
# Enemy Golem — stone construct
# ---------------------------------------------------------------------------

def enemy_golem() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    STONE, STONE_D, STONE_H = (120, 112, 102), (72, 66, 58), (162, 154, 140)
    RUNE, RUNE2 = (80, 165, 210), (140, 220, 255)
    CRACK = (50, 44, 38)
    MOSS = (62, 110, 52)

    d.ellipse([18, 89, 78, 96], fill=(0, 0, 0, 80))

    # LEGS (pillar-like, massive)
    d.rounded_rectangle([22, 58, 48, 90], radius=6, fill=STONE)
    d.rounded_rectangle([52, 58, 78, 90], radius=6, fill=STONE)
    d.rectangle([22, 58, 30, 90], fill=STONE_H)
    d.rectangle([70, 58, 78, 90], fill=STONE_D)
    # Cracks on legs
    d.line([(30, 60), (26, 72), (32, 80)], fill=CRACK, width=2)
    d.line([(64, 62), (68, 74), (64, 84)], fill=CRACK, width=2)
    # Moss on legs
    d.ellipse([22, 84, 35, 90], fill=MOSS)
    d.ellipse([60, 86, 72, 91], fill=MOSS)

    # BODY (massive cube-ish torso)
    d.rounded_rectangle([14, 26, 82, 62], radius=6, fill=STONE)
    d.rectangle([14, 26, 24, 62], fill=STONE_H)
    d.rectangle([72, 26, 82, 62], fill=STONE_D)
    # Body cracks
    d.line([(38, 28), (34, 40), (42, 52)], fill=CRACK, width=2)
    d.line([(58, 30), (62, 45), (56, 58)], fill=CRACK, width=2)
    d.line([(24, 44), (30, 50)], fill=CRACK, width=1)
    # Glowing rune on chest
    d.ellipse([36, 36, 60, 54], fill=RUNE)
    d.ellipse([38, 38, 58, 52], fill=STONE)
    d.ellipse([40, 40, 56, 50], fill=RUNE)
    d.ellipse([44, 44, 52, 46], fill=RUNE2)
    # Rune lines
    d.line([(48, 36), (48, 54)], fill=RUNE2, width=2)
    d.line([(36, 45), (60, 45)], fill=RUNE2, width=2)
    d.line([(39, 39), (57, 51)], fill=RUNE, width=1)
    d.line([(57, 39), (39, 51)], fill=RUNE, width=1)

    # LEFT ARM (massive, dragging on ground)
    d.rounded_rectangle([0, 24, 20, 70], radius=6, fill=STONE)
    d.rectangle([0, 24, 6, 70], fill=STONE_H)
    d.rectangle([14, 24, 20, 70], fill=STONE_D)
    # Rocky fist
    d.rounded_rectangle([0, 66, 22, 82], radius=4, fill=STONE_D)
    d.ellipse([0, 66, 10, 74], fill=STONE)

    # RIGHT ARM (raised to strike)
    d.rounded_rectangle([76, 14, 96, 60], radius=6, fill=STONE)
    d.rectangle([90, 14, 96, 60], fill=STONE_D)
    d.rectangle([76, 14, 82, 60], fill=STONE_H)
    # Raised fist
    d.rounded_rectangle([76, 8, 96, 22], radius=4, fill=STONE_D)
    d.ellipse([86, 8, 96, 18], fill=STONE)

    # NECK (stone column)
    d.rounded_rectangle([36, 18, 60, 28], radius=4, fill=STONE)

    # HEAD (rough cube)
    d.rounded_rectangle([22, 2, 74, 24], radius=4, fill=STONE)
    d.rectangle([22, 2, 32, 24], fill=STONE_H)
    d.rectangle([64, 2, 74, 24], fill=STONE_D)

    # Head cracks/details
    d.line([(42, 4), (38, 14), (44, 20)], fill=CRACK, width=2)
    d.line([(54, 6), (58, 16)], fill=CRACK, width=1)

    # EYES (glowing rune slots)
    d.rectangle([28, 8, 44, 18], fill=CRACK)
    d.rectangle([52, 8, 68, 18], fill=CRACK)
    d.rectangle([30, 10, 42, 16], fill=RUNE)
    d.rectangle([54, 10, 66, 16], fill=RUNE)
    d.rectangle([33, 11, 39, 15], fill=RUNE2)
    d.rectangle([57, 11, 63, 15], fill=RUNE2)

    # Mouth (grill of cracks)
    d.rectangle([30, 20, 66, 24], fill=CRACK)
    for mx in [33, 39, 45, 51, 57]:
        d.rectangle([mx, 20, mx+4, 24], fill=STONE_D)

    # Moss on head
    d.ellipse([22, 2, 36, 10], fill=MOSS)
    d.ellipse([62, 2, 74, 10], fill=MOSS)

    return img


# ---------------------------------------------------------------------------
# Boss — Dungeon Lord (floors 1–6)
# ---------------------------------------------------------------------------

def enemy_boss_dungeon_lord() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    ARMOR, ARMOR_D, ARMOR_H = (20, 14, 32), (10, 6, 18), (44, 32, 68)
    GOLD, GOLD_D = (210, 165, 20), (150, 110, 8)
    CAPE, CAPE_H = (140, 20, 30), (185, 35, 45)
    SKIN, SKIN_D = (165, 100, 60), (115, 65, 30)
    PURPLE, PURPLE_H = (160, 50, 220), (200, 100, 255)
    EYE = (220, 160, 255)
    BLADE = (190, 200, 215)

    d.ellipse([22, 89, 74, 96], fill=(0, 0, 0, 65))

    # CAPE (dramatic, flowing behind)
    d.polygon([(24, 28), (72, 28), (84, 92), (12, 92)], fill=CAPE)
    d.polygon([(24, 28), (40, 28), (32, 92), (14, 92)], fill=CAPE_H)
    d.rectangle([12, 28, 20, 92], fill=CAPE_H)

    # GREAT SWORD (behind, upright)
    d.rectangle([4, 2, 12, 72], fill=BLADE)
    d.rectangle([5, 2, 9, 72], fill=(220, 230, 245))
    d.rectangle([0, 34, 16, 40], fill=GOLD)         # crossguard
    d.polygon([(4, 2), (8, 2), (8, 14), (4, 14)], fill=(215, 225, 240))  # tip detail
    d.rounded_rectangle([5, 66, 11, 78], radius=3, fill=GOLD)

    # BOOTS (armored greaves)
    d.rounded_rectangle([26, 78, 46, 92], radius=4, fill=ARMOR)
    d.rounded_rectangle([50, 78, 70, 92], radius=4, fill=ARMOR)
    d.rectangle([26, 78, 32, 88], fill=ARMOR_H)
    # Gold trim on boots
    d.rectangle([26, 78, 46, 81], fill=GOLD)
    d.rectangle([50, 78, 70, 81], fill=GOLD)

    # ARMORED LEGS
    d.rounded_rectangle([26, 58, 46, 80], radius=5, fill=ARMOR)
    d.rounded_rectangle([50, 58, 70, 80], radius=5, fill=ARMOR)
    d.rectangle([26, 58, 32, 80], fill=ARMOR_H)
    d.rectangle([64, 58, 70, 80], fill=ARMOR_D)

    # BELT/SKIRT of armor
    d.rounded_rectangle([22, 54, 74, 62], radius=3, fill=ARMOR_D)
    for bx in [26, 34, 42, 50, 58, 66]:
        d.rectangle([bx, 54, bx+6, 62], fill=ARMOR)
    d.rectangle([44, 53, 52, 63], fill=GOLD)

    # BREASTPLATE
    d.rounded_rectangle([20, 24, 76, 58], radius=6, fill=ARMOR)
    d.rectangle([20, 24, 28, 58], fill=ARMOR_H)
    d.rectangle([68, 24, 76, 58], fill=ARMOR_D)
    # Armor details
    d.rounded_rectangle([30, 30, 66, 50], radius=4, fill=ARMOR_D)
    d.rounded_rectangle([32, 32, 64, 48], radius=3, fill=ARMOR)
    # Purple gem center
    d.ellipse([42, 35, 54, 47], fill=PURPLE)
    d.ellipse([43, 36, 53, 46], fill=PURPLE_H)
    d.ellipse([45, 38, 51, 44], fill=(240, 220, 255))
    # Armor trim gold
    d.rectangle([20, 24, 76, 27], fill=GOLD)
    d.rectangle([20, 54, 76, 57], fill=GOLD)

    # PAULDRONS (shoulder armor, large)
    d.ellipse([6, 18, 28, 36], fill=ARMOR)
    d.ellipse([6, 18, 16, 28], fill=ARMOR_H)
    d.ellipse([68, 18, 90, 36], fill=ARMOR)
    d.ellipse([78, 18, 90, 28], fill=ARMOR_D)
    # Gold trim on pauldrons
    d.arc([6, 18, 28, 36], start=180, end=360, fill=GOLD, width=2)
    d.arc([68, 18, 90, 36], start=180, end=360, fill=GOLD, width=2)

    # LEFT ARM (gauntleted)
    d.rounded_rectangle([8, 30, 22, 58], radius=6, fill=ARMOR)
    d.rectangle([8, 30, 14, 58], fill=ARMOR_H)
    # Gauntlet
    d.rounded_rectangle([6, 54, 20, 66], radius=4, fill=ARMOR_D)
    d.rectangle([6, 54, 12, 66], fill=ARMOR)

    # RIGHT ARM (gauntleted, raised)
    d.rounded_rectangle([74, 22, 88, 50], radius=6, fill=ARMOR)
    d.rectangle([82, 22, 88, 50], fill=ARMOR_D)
    d.rounded_rectangle([74, 18, 88, 30], radius=4, fill=ARMOR_D)

    # NECK (gorget)
    d.rounded_rectangle([38, 16, 58, 26], radius=4, fill=ARMOR)
    d.rectangle([38, 16, 44, 26], fill=ARMOR_H)

    # CROWN
    for cx in [28, 36, 48, 60, 68]:
        h = 8 if cx == 48 else 5
        d.rectangle([cx, 4 - h, cx + 5, 8], fill=GOLD)
        d.ellipse([cx, 2 - h, cx+5, 4 - h + 2], fill=GOLD_D)
    d.rectangle([26, 8, 70, 14], fill=GOLD)
    d.rectangle([26, 8, 30, 14], fill=(235, 195, 35))
    # Crown gems
    d.ellipse([32, 7, 38, 13], fill=PURPLE)
    d.ellipse([54, 7, 60, 13], fill=PURPLE)
    d.ellipse([44, 5, 52, 11], fill=EYE)

    # HEAD (helmeted, menacing)
    d.ellipse([28, 8, 68, 28], fill=SKIN)
    d.ellipse([28, 8, 42, 22], fill=SKIN)
    d.ellipse([54, 10, 68, 24], fill=SKIN_D)

    # EYES (glowing purple)
    for ex in [32, 52]:
        d.ellipse([ex, 14, ex+12, 24], fill=(14, 6, 22))
        d.ellipse([ex+1, 15, ex+11, 23], fill=PURPLE)
        d.ellipse([ex+2, 16, ex+10, 22], fill=PURPLE_H)
        d.ellipse([ex+3, 17, ex+9, 21], fill=(14, 6, 22))
        d.ellipse([ex+2, 15, ex+4, 17], fill=(255, 255, 255, 200))

    # Dark NOSE and MOUTH (shadowed, severe)
    d.ellipse([44, 22, 52, 26], fill=SKIN_D)
    d.rectangle([38, 26, 58, 29], fill=(50, 20, 10))

    # Aura of dark magic
    for ax, ay, ar in [(48, 48, 30), (48, 78, 20), (22, 58, 14), (74, 58, 14)]:
        overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse([ax-ar, ay-ar, ax+ar, ay+ar], fill=(120, 20, 200, 25))
        img = Image.alpha_composite(img, overlay)
        d = ImageDraw.Draw(img)

    return img


# ---------------------------------------------------------------------------
# Boss — The Warden (floors 7–12)
# ---------------------------------------------------------------------------

def enemy_boss_warden() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    PLATE, PLATE_D, PLATE_H = (55, 60, 65), (28, 32, 35), (90, 96, 102)
    GOLD, GOLD_D = (195, 155, 15), (140, 105, 8)
    EYE = (255, 200, 0)
    CHAIN = (72, 78, 82)
    HALBERD = (160, 168, 178)
    RED = (180, 30, 20)

    d.ellipse([18, 89, 78, 96], fill=(0, 0, 0, 75))

    # HALBERD (held upright)
    d.rectangle([78, 4, 84, 82], fill=(90, 60, 24))
    d.rectangle([79, 4, 82, 82], fill=(120, 85, 35))
    # Halberd head
    d.polygon([(74, 4), (88, 4), (90, 24), (78, 28), (74, 24)], fill=HALBERD)
    d.polygon([(76, 4), (86, 4), (86, 20), (78, 24)], fill=(195, 205, 218))
    d.polygon([(88, 14), (96, 8), (92, 22)], fill=HALBERD)  # side spike
    d.rectangle([76, 26, 90, 30], fill=GOLD)                 # socket ring

    # GREAVES
    d.rounded_rectangle([24, 76, 46, 92], radius=5, fill=PLATE)
    d.rounded_rectangle([50, 76, 72, 92], radius=5, fill=PLATE)
    d.rectangle([24, 76, 32, 90], fill=PLATE_H)
    d.rectangle([64, 76, 72, 90], fill=PLATE_D)
    # Kneeplate
    d.ellipse([26, 70, 44, 80], fill=PLATE)
    d.ellipse([28, 71, 42, 79], fill=PLATE_H)
    d.ellipse([52, 70, 70, 80], fill=PLATE)

    # ARMORED LEGS (full plate)
    d.rounded_rectangle([24, 56, 46, 78], radius=5, fill=PLATE)
    d.rounded_rectangle([50, 56, 72, 78], radius=5, fill=PLATE)
    d.rectangle([24, 56, 30, 78], fill=PLATE_H)
    d.rectangle([66, 56, 72, 78], fill=PLATE_D)

    # TASSETS (waist armor plates)
    d.rounded_rectangle([20, 52, 76, 60], radius=3, fill=PLATE_D)
    for bx in [22, 32, 44, 54, 64]:
        d.rounded_rectangle([bx, 52, bx+8, 60], radius=2, fill=PLATE)
    d.rectangle([20, 52, 28, 60], fill=PLATE_H)
    d.rectangle([44, 50, 52, 62], fill=GOLD)   # center badge

    # BREASTPLATE (massive, imposing)
    d.rounded_rectangle([16, 20, 80, 56], radius=6, fill=PLATE)
    d.rectangle([16, 20, 26, 56], fill=PLATE_H)
    d.rectangle([70, 20, 80, 56], fill=PLATE_D)
    # Chest ridges
    for ry in [24, 32, 40, 48]:
        d.rectangle([18, ry, 78, ry+4], fill=PLATE_D)
        d.rectangle([18, ry, 24, ry+4], fill=PLATE_H)
    # Gold trim
    d.rectangle([16, 20, 80, 24], fill=GOLD)
    d.rectangle([16, 52, 80, 56], fill=GOLD)
    d.rectangle([16, 20, 20, 56], fill=GOLD)
    d.rectangle([76, 20, 80, 56], fill=GOLD)
    # Center emblem — red cross
    d.rectangle([44, 28, 52, 48], fill=RED)
    d.rectangle([38, 34, 58, 42], fill=RED)
    d.rectangle([46, 30, 50, 46], fill=(220, 40, 28))

    # PAULDRONS (massive tower shoulders)
    d.rounded_rectangle([0, 14, 20, 42], radius=5, fill=PLATE)
    d.rectangle([0, 14, 6, 42], fill=PLATE_H)
    d.rectangle([14, 14, 20, 42], fill=PLATE_D)
    d.rectangle([0, 14, 20, 18], fill=GOLD)
    d.rounded_rectangle([76, 14, 96, 42], radius=5, fill=PLATE)
    d.rectangle([90, 14, 96, 42], fill=PLATE_D)
    d.rectangle([76, 14, 82, 42], fill=PLATE_H)
    d.rectangle([76, 14, 96, 18], fill=GOLD)

    # ARMS
    d.rounded_rectangle([6, 28, 18, 56], radius=5, fill=PLATE)
    d.rounded_rectangle([78, 20, 90, 48], radius=5, fill=PLATE)
    # Gauntlets
    d.rounded_rectangle([4, 52, 18, 66], radius=4, fill=PLATE_D)
    d.rounded_rectangle([78, 44, 92, 56], radius=4, fill=PLATE_D)
    d.rectangle([4, 52, 10, 66], fill=PLATE)
    # Gold gauntlet trim
    d.rectangle([4, 52, 18, 55], fill=GOLD)
    d.rectangle([78, 44, 92, 47], fill=GOLD)

    # HELM (full face close helmet)
    d.rounded_rectangle([20, 2, 76, 24], radius=6, fill=PLATE)
    d.rectangle([20, 2, 28, 24], fill=PLATE_H)
    d.rectangle([68, 2, 76, 24], fill=PLATE_D)
    # Visor
    d.rectangle([26, 10, 70, 18], fill=PLATE_D)
    d.rectangle([26, 10, 32, 18], fill=PLATE)
    # EYE SLITS (glowing yellow)
    d.rectangle([30, 11, 46, 16], fill=(14, 10, 2))
    d.rectangle([50, 11, 66, 16], fill=(14, 10, 2))
    d.rectangle([32, 12, 44, 15], fill=EYE)
    d.rectangle([52, 12, 64, 15], fill=EYE)
    d.rectangle([34, 12, 38, 15], fill=(255, 230, 80))
    d.rectangle([54, 12, 58, 15], fill=(255, 230, 80))
    # Helm crest / ridge
    d.rectangle([45, 2, 51, 12], fill=GOLD)
    d.rectangle([46, 2, 50, 12], fill=(230, 188, 28))
    # Chin guard
    d.rounded_rectangle([26, 18, 70, 26], radius=3, fill=PLATE)
    d.rectangle([26, 18, 32, 26], fill=PLATE_H)
    # Gold collar
    d.rectangle([20, 22, 76, 26], fill=GOLD)

    return img


# ---------------------------------------------------------------------------
# Boss — Abyss Keeper (floors 13–18)
# ---------------------------------------------------------------------------

def enemy_boss_abyss_keeper() -> Image.Image:
    img = new_img()
    d = ImageDraw.Draw(img)

    BODY, BODY_D, BODY_H = (24, 8, 48), (12, 2, 28), (50, 20, 90)
    TENT, TENT_D = (40, 12, 70), (20, 4, 40)
    EYE1, EYE2 = (220, 80, 255), (160, 20, 200)
    GLOW = (180, 60, 255)
    GLOW2 = (120, 10, 180)
    ORB = (250, 200, 255)

    d.ellipse([20, 89, 76, 96], fill=(0, 0, 0, 80))

    # DARK AURA (atmospheric glow behind)
    for ax, ay, ar, alpha in [(48, 50, 42, 40), (48, 70, 30, 30), (20, 60, 20, 25), (76, 58, 18, 25)]:
        overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse([ax-ar, ay-ar, ax+ar, ay+ar], fill=(120, 0, 200, alpha))
        img = Image.alpha_composite(img, overlay)
    d = ImageDraw.Draw(img)

    # TENTACLES (many, spread from body)
    tentacle_data = [
        # (start_x, start_y, mid_x, mid_y, end_x, end_y)
        (30, 62, 8, 72, 4, 88),
        (28, 64, 10, 80, 12, 92),
        (38, 68, 20, 82, 14, 90),
        (66, 62, 88, 72, 92, 88),
        (68, 64, 86, 80, 84, 92),
        (58, 68, 76, 82, 82, 90),
        (44, 68, 36, 84, 28, 90),
        (52, 68, 60, 84, 68, 90),
    ]
    for sx, sy, mx, my, ex, ey in tentacle_data:
        d.line([(sx, sy), (mx, my), (ex, ey)], fill=TENT, width=5)
        d.line([(sx, sy), (mx, my), (ex, ey)], fill=TENT_D, width=2)
        # Sucker spots
        mid_bx = (sx + mx) // 2
        mid_by = (sy + my) // 2
        d.ellipse([mid_bx-2, mid_by-2, mid_bx+2, mid_by+2], fill=EYE2)

    # CLOAK / BODY MASS (dark shroud)
    d.ellipse([16, 34, 80, 74], fill=BODY)
    d.ellipse([16, 34, 36, 56], fill=BODY_H)
    d.ellipse([60, 44, 80, 68], fill=BODY_D)
    # Body flow lines
    d.arc([18, 36, 50, 68], start=200, end=320, fill=BODY_H, width=2)
    d.arc([46, 38, 78, 70], start=20, end=160, fill=BODY_D, width=2)

    # FLOATING DARK ENERGY ORBS
    for ox, oy, or_ in [(10, 36, 7), (86, 38, 6), (14, 58, 5), (82, 62, 5)]:
        d.ellipse([ox-or_, oy-or_, ox+or_, oy+or_], fill=GLOW)
        d.ellipse([ox-or_+2, oy-or_+2, ox+or_-2, oy+or_-2], fill=ORB)

    # ARMS (shadowy tendrils reaching out)
    d.polygon([(16, 40), (2, 30), (8, 52), (20, 50)], fill=BODY)
    d.polygon([(16, 40), (4, 32), (8, 48)], fill=BODY_H)
    d.polygon([(80, 40), (94, 30), (88, 52), (76, 50)], fill=BODY)
    d.polygon([(80, 40), (92, 32), (88, 48)], fill=BODY_D)
    # Claw fingers
    for cx, cy in [(0, 28), (2, 24), (6, 26), (10, 24)]:
        d.line([(8, 34), (cx, cy)], fill=TENT_D, width=2)
    for cx, cy in [(96, 28), (94, 24), (90, 26), (86, 24)]:
        d.line([(88, 34), (cx, cy)], fill=TENT_D, width=2)

    # NECK / UPPER BODY
    d.ellipse([34, 18, 62, 42], fill=BODY)
    d.ellipse([34, 18, 46, 32], fill=BODY_H)

    # HEAD (alien, multi-eyed)
    d.ellipse([24, 2, 72, 36], fill=BODY)
    d.ellipse([24, 2, 40, 18], fill=BODY_H)
    d.ellipse([56, 6, 72, 26], fill=BODY_D)
    # Ethereal crown/tentacles from head
    for hx, hy in [(28, 4), (38, 2), (48, 0), (58, 2), (68, 4)]:
        d.polygon([(hx, 8), (hx-3, hy), (hx+3, hy)], fill=TENT)
        d.ellipse([hx-2, hy-2, hx+2, hy+2], fill=EYE1)

    # MAIN EYES (3 large glowing eyes)
    # Left eye
    d.ellipse([26, 10, 42, 24], fill=(10, 2, 18))
    d.ellipse([27, 11, 41, 23], fill=EYE2)
    d.ellipse([29, 13, 39, 21], fill=EYE1)
    d.ellipse([31, 14, 37, 20], fill=(10, 2, 18))
    d.ellipse([30, 13, 33, 16], fill=(255, 255, 255, 200))

    # Right eye
    d.ellipse([54, 10, 70, 24], fill=(10, 2, 18))
    d.ellipse([55, 11, 69, 23], fill=EYE2)
    d.ellipse([57, 13, 67, 21], fill=EYE1)
    d.ellipse([59, 14, 65, 20], fill=(10, 2, 18))
    d.ellipse([58, 13, 61, 16], fill=(255, 255, 255, 200))

    # Center eye (largest, most horrifying)
    d.ellipse([40, 14, 56, 28], fill=(10, 2, 18))
    d.ellipse([41, 15, 55, 27], fill=EYE2)
    d.ellipse([43, 17, 53, 25], fill=EYE1)
    d.ellipse([44, 18, 52, 24], fill=ORB)
    d.ellipse([46, 19, 50, 23], fill=(10, 2, 18))
    d.ellipse([44, 18, 47, 21], fill=(255, 255, 255, 220))

    # MOUTH (toothy rift)
    d.arc([32, 26, 64, 38], start=10, end=170, fill=(8, 2, 14), width=3)
    for tx in [35, 40, 46, 52, 58]:
        d.polygon([(tx, 30), (tx+2, 36), (tx+4, 30)], fill=EYE1)

    # Small extra eyes scattered on body
    for ex, ey, er in [(20, 46, 4), (74, 44, 4), (24, 60, 3), (70, 58, 3)]:
        d.ellipse([ex-er, ey-er, ex+er, ey+er], fill=(8, 2, 14))
        d.ellipse([ex-er+1, ey-er+1, ex+er-1, ey+er-1], fill=EYE2)
        d.ellipse([ex-1, ey-1, ex+1, ey+1], fill=(8, 2, 14))

    # Legacy boss sprite (placeholder alias)
    return img


# ---------------------------------------------------------------------------
# Main — generate all sprites
# ---------------------------------------------------------------------------

SPRITES = {
    "hero_brawler":              hero_brawler,
    "hero_rogue":                hero_rogue,
    "hero_arcanist":             hero_arcanist,
    "enemy_imp":                 enemy_imp,
    "enemy_goblin":              enemy_goblin,
    "enemy_skeleton":            enemy_skeleton,
    "enemy_demon":               enemy_demon,
    "enemy_golem":               enemy_golem,
    "enemy_boss_dungeon_lord":   enemy_boss_dungeon_lord,
    "enemy_boss_warden":         enemy_boss_warden,
    "enemy_boss_abyss_keeper":   enemy_boss_abyss_keeper,
    "enemy_boss":                enemy_boss_dungeon_lord,   # legacy alias
}

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Generating sprites → {OUTPUT_DIR}/")
    for name, fn in SPRITES.items():
        img = fn()
        save(img, name)
    print("Done.")
