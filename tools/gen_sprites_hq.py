#!/usr/bin/env python3
"""High-quality sprite generator — 4× super-sampling + glow effects.

Renders at 512×512 then downsamples to 128×128 via LANCZOS for smooth,
anti-aliased edges. Eyes and magic elements get Gaussian glow layers.
Also generates 200×190 class portraits for ClassSelect.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFilter

BASE = 128
SCALE = 4
R = BASE * SCALE   # 512 render canvas

OUTPUT   = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
PORTRAIT_OUTPUT = os.path.join(os.path.dirname(__file__), "..", "assets", "portraits")


# ── Coordinate helpers ──────────────────────────────────────────────────────

def s(v):
    return int(v * SCALE)

def sb(box):
    return [s(v) for v in box]

def sp(pairs):
    return [(s(x), s(y)) for x, y in pairs]


# ── Drawing helpers ─────────────────────────────────────────────────────────

def new_canvas():
    return Image.new("RGBA", (R, R), (0, 0, 0, 0))


def glow_layer(cx, cy, radius, color, passes=3):
    """Return a blurred glow layer centred at (cx, cy) in base coords."""
    layer = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cr, cg, cb = color[:3]
    for i in range(passes, 0, -1):
        r2 = s(radius) * (i + 1) // 2
        alpha = 90 * i // passes
        d.ellipse([s(cx)-r2, s(cy)-r2, s(cx)+r2, s(cy)+r2],
                  fill=(cr, cg, cb, alpha))
    return layer.filter(ImageFilter.GaussianBlur(s(radius) * 0.7))


def composite_glow(img, cx, cy, radius, color, passes=3):
    return Image.alpha_composite(img, glow_layer(cx, cy, radius, color, passes))


def add_outline(img: Image.Image) -> Image.Image:
    """Thin dark outline on every sprite boundary."""
    alpha = img.getchannel("A")
    expanded = alpha.filter(ImageFilter.MaxFilter(5))
    outline = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    ep = expanded.load()
    ap = alpha.load()
    op = outline.load()
    BORDER = (6, 3, 12, 255)
    for y in range(R):
        for x in range(R):
            if ep[x, y] > 0 and ap[x, y] < 20:
                op[x, y] = BORDER
    result = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    result.paste(outline, (0, 0))
    result.paste(img, (0, 0), img)
    return result


def finalize(img: Image.Image) -> Image.Image:
    img = add_outline(img)
    return img.resize((BASE, BASE), Image.LANCZOS)


def save(img: Image.Image, name: str):
    os.makedirs(OUTPUT, exist_ok=True)
    final = finalize(img)
    path = os.path.join(OUTPUT, name + ".png")
    final.save(path)
    print(f"  {name}.png  ({os.path.getsize(path):,} bytes)")


# ── HERO BRAWLER ─────────────────────────────────────────────────────────────

def hero_brawler() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    SKIN   = (195, 128, 78)
    SKIN_H = (225, 158, 105)
    SKIN_D = (138, 82, 44)
    HAIR   = (20, 10, 4)
    SHIRT  = (22, 22, 22)       # black tank
    SHIRT_H= (44, 44, 44)
    JEANS  = (34, 50, 90)
    JEANS_H= (52, 70, 118)
    BOOT   = (18, 10, 5)
    BELT   = (55, 35, 14)
    BUCKLE = (120, 85, 28)
    BLOOD  = (120, 18, 18, 120)

    # shadow
    d.ellipse(sb([22, 88, 74, 95]), fill=(0,0,0,55))

    # boots
    d.rounded_rectangle(sb([27, 78, 47, 92]), radius=s(4), fill=BOOT)
    d.rounded_rectangle(sb([49, 78, 69, 92]), radius=s(4), fill=BOOT)
    d.rectangle(sb([28, 78, 34, 84]), fill=(30, 18, 8))

    # jeans
    d.rounded_rectangle(sb([28, 55, 46, 80]), radius=s(5), fill=JEANS)
    d.rounded_rectangle(sb([50, 55, 68, 80]), radius=s(5), fill=JEANS)
    d.rectangle(sb([28, 55, 34, 80]), fill=JEANS_H)
    # knee highlight
    d.ellipse(sb([29, 65, 42, 75]), fill=(44, 64, 108, 90))

    # belt
    d.rounded_rectangle(sb([25, 51, 71, 57]), radius=s(2), fill=BELT)
    d.rectangle(sb([43, 49, 53, 59]), fill=(75, 50, 18))
    d.rectangle(sb([44, 51, 52, 57]), fill=BUCKLE)

    # torso — black tank top
    d.rounded_rectangle(sb([23, 24, 73, 54]), radius=s(5), fill=SHIRT)
    d.rectangle(sb([23, 24, 30, 54]), fill=SHIRT_H)
    d.rectangle(sb([66, 24, 73, 54]), fill=(12, 12, 12))
    # v-neck
    d.polygon(sp([(37, 24), (59, 24), (48, 35)]), fill=(14, 14, 14))
    # muscle shading — pec lines
    d.arc(sb([25, 28, 48, 48]), start=200, end=340, fill=(12,12,12), width=s(1))
    d.arc(sb([48, 28, 71, 48]), start=200, end=340, fill=(12,12,12), width=s(1))
    # tank straps
    d.rounded_rectangle(sb([28, 14, 38, 26]), radius=s(3), fill=SHIRT)
    d.rounded_rectangle(sb([58, 14, 68, 26]), radius=s(3), fill=SHIRT)

    # left arm — punching forward
    d.rounded_rectangle(sb([3, 22, 24, 52]), radius=s(8), fill=SKIN)
    d.rectangle(sb([3, 22, 10, 52]), fill=SKIN_H)
    d.rounded_rectangle(sb([1, 48, 22, 64]), radius=s(4), fill=SKIN_D)
    d.rectangle(sb([2, 49, 9, 63]), fill=SKIN)
    for ky in [52, 56, 60]:
        d.line(sp([(2, ky), (20, ky)]), fill=(95, 48, 14), width=s(1))

    # right arm — raised guard
    d.rounded_rectangle(sb([72, 10, 93, 42]), radius=s(8), fill=SKIN)
    d.rectangle(sb([72, 10, 79, 42]), fill=SKIN_H)
    d.rounded_rectangle(sb([72, 4, 93, 20]), radius=s(4), fill=SKIN_D)
    d.rectangle(sb([73, 5, 80, 19]), fill=SKIN)
    for ky in [9, 13, 17]:
        d.line(sp([(73, ky), (91, ky)]), fill=(95, 48, 14), width=s(1))

    # neck
    d.rounded_rectangle(sb([40, 14, 56, 26]), radius=s(4), fill=SKIN)

    # head
    d.ellipse(sb([27, 0, 69, 28]), fill=SKIN)
    d.ellipse(sb([27, 2, 41, 18]), fill=SKIN_H)
    d.ellipse(sb([55, 4, 69, 20]), fill=SKIN_D)

    # cheek bruise (Carl's always a bit beat up)
    bruise = Image.new("RGBA", (R, R), (0,0,0,0))
    bd = ImageDraw.Draw(bruise)
    bd.ellipse(sb([53, 16, 65, 24]), fill=(60, 30, 110, 65))
    img = Image.alpha_composite(img, bruise)
    d = ImageDraw.Draw(img)

    # hair
    d.ellipse(sb([25, 0, 71, 14]), fill=HAIR)
    d.ellipse(sb([23, 0, 37, 12]), fill=HAIR)
    d.ellipse(sb([59, 0, 73, 12]), fill=HAIR)

    # stubble
    d.rectangle(sb([36, 22, 60, 28]), fill=(24, 13, 5))

    # brows — heavy and furrowed
    d.polygon(sp([(29, 10), (43, 13), (41, 15), (30, 13)]), fill=HAIR)
    d.polygon(sp([(67, 10), (53, 13), (55, 15), (66, 13)]), fill=HAIR)

    # eyes — brown, intense
    for ex in [35, 53]:
        d.ellipse(sb([ex, 13, ex+11, 21]), fill=(10, 6, 2))
        d.ellipse(sb([ex+1, 14, ex+10, 20]), fill=(75, 42, 14))
        d.ellipse(sb([ex+2, 15, ex+9, 19]), fill=(115, 62, 18))
        d.ellipse(sb([ex+3, 15, ex+8, 19]), fill=(8, 4, 1))
        # catchlight
        d.ellipse(sb([ex+2, 14, ex+4, 16]), fill=(255, 255, 255, 170))

    # nose
    d.ellipse(sb([43, 19, 53, 25]), fill=SKIN_D)
    d.ellipse(sb([43, 22, 47, 25]), fill=(95, 50, 18))
    d.ellipse(sb([49, 22, 53, 25]), fill=(95, 50, 18))

    # mouth — grim
    d.rectangle(sb([38, 25, 58, 28]), fill=(80, 28, 8))
    d.rectangle(sb([39, 25, 57, 26]), fill=(125, 48, 14))

    return img


# ── HERO ROGUE ────────────────────────────────────────────────────────────────

def hero_rogue() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    CLOAK  = (32, 20, 48)
    CLOAK_H= (52, 36, 72)
    CLOAK_D= (16, 8, 26)
    BLADE  = (198, 208, 222)
    BLADE_H= (238, 244, 255)
    BOOT   = (18, 12, 8)
    ACCENT = (155, 110, 215)
    SKIN   = (175, 135, 95)
    EYE_C  = (100, 215, 188)

    d.ellipse(sb([22, 88, 74, 95]), fill=(0,0,0,55))

    # boots
    d.rounded_rectangle(sb([28, 79, 46, 92]), radius=s(4), fill=BOOT)
    d.rounded_rectangle(sb([50, 79, 68, 92]), radius=s(4), fill=BOOT)

    # legs (cloak covers most)
    d.rounded_rectangle(sb([29, 56, 45, 81]), radius=s(5), fill=CLOAK_D)
    d.rounded_rectangle(sb([51, 56, 67, 81]), radius=s(5), fill=CLOAK_D)

    # main cloak — wide sweeping shape
    d.polygon(sp([(18, 28), (78, 28), (82, 92), (14, 92)]), fill=CLOAK)
    d.polygon(sp([(20, 28), (36, 28), (30, 92), (14, 92)]), fill=CLOAK_H)
    d.rectangle(sb([18, 28, 24, 92]), fill=CLOAK_H)
    d.rectangle(sb([72, 28, 78, 92]), fill=CLOAK_D)

    # cloak accent trim lines
    d.line(sp([(18, 28), (14, 92)]), fill=ACCENT, width=s(1))
    d.line(sp([(78, 28), (82, 92)]), fill=ACCENT, width=s(1))

    # left dagger
    d.rectangle(sb([5, 44, 9, 78]), fill=(88, 58, 20))
    d.rectangle(sb([6, 50, 8, 64]), fill=(130, 92, 32))
    d.rectangle(sb([3, 42, 11, 46]), fill=(130, 105, 42))
    d.polygon(sp([(4, 20), (8, 20), (6, 42)]), fill=BLADE)
    d.polygon(sp([(5, 22), (7, 22), (6, 30)]), fill=BLADE_H)

    # right dagger (partially visible)
    d.rectangle(sb([87, 48, 91, 78]), fill=(88, 58, 20))
    d.rectangle(sb([85, 46, 93, 50]), fill=(130, 105, 42))
    d.polygon(sp([(86, 26), (90, 26), (88, 46)]), fill=BLADE)
    d.polygon(sp([(87, 28), (89, 28), (88, 36)]), fill=BLADE_H)

    # left arm holding dagger
    d.rounded_rectangle(sb([8, 26, 22, 52]), radius=s(6), fill=CLOAK)
    d.rectangle(sb([8, 26, 14, 52]), fill=CLOAK_H)

    # right arm
    d.rounded_rectangle(sb([74, 26, 88, 52]), radius=s(6), fill=CLOAK)
    d.rectangle(sb([82, 26, 88, 52]), fill=CLOAK_D)

    # hood (dark outer, slightly lighter inner framing face)
    d.ellipse(sb([20, 2, 76, 38]), fill=CLOAK_D)
    d.ellipse(sb([26, 8, 70, 36]), fill=CLOAK)
    d.ellipse(sb([20, 2, 46, 22]), fill=CLOAK_H)

    # face (shadowed under hood)
    d.ellipse(sb([30, 14, 66, 38]), fill=(125, 92, 60))
    d.ellipse(sb([30, 14, 44, 28]), fill=(155, 118, 80))
    # lower face mask
    d.rectangle(sb([30, 28, 66, 38]), fill=CLOAK_D)

    # hood clasp
    d.ellipse(sb([43, 30, 53, 38]), fill=ACCENT)
    d.ellipse(sb([45, 32, 51, 36]), fill=(130, 88, 190))

    # eyes — glowing teal
    img = composite_glow(img, 37, 22, 6, EYE_C, passes=4)
    img = composite_glow(img, 59, 22, 6, EYE_C, passes=4)
    d = ImageDraw.Draw(img)
    for ex in [33, 55]:
        d.ellipse(sb([ex, 18, ex+12, 28]), fill=(8, 4, 16))
        d.ellipse(sb([ex+1, 19, ex+11, 27]), fill=EYE_C)
        d.ellipse(sb([ex+2, 20, ex+10, 26]), fill=(180, 248, 230))
        d.ellipse(sb([ex+4, 21, ex+8, 25]), fill=(8, 4, 16))
        d.ellipse(sb([ex+2, 19, ex+4, 21]), fill=(255, 255, 255, 180))

    return img


# ── HERO ARCANIST ─────────────────────────────────────────────────────────────

def hero_arcanist() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    SKIN   = (192, 152, 108)
    SKIN_D = (142, 102, 62)
    ROBE   = (46, 26, 86)
    ROBE_H = (68, 42, 118)
    ROBE_D = (26, 12, 54)
    BEARD  = (208, 202, 192)
    HAT    = (36, 20, 68)
    GLOW   = (165, 108, 252)
    GLOW_H = (215, 175, 255)
    WOOD   = (85, 58, 20)
    GOLD   = (195, 155, 28)

    d.ellipse(sb([22, 88, 74, 95]), fill=(0,0,0,55))

    # robe (wide flowing bottom)
    d.polygon(sp([(20, 32), (76, 32), (84, 92), (12, 92)]), fill=ROBE)
    d.polygon(sp([(22, 32), (46, 32), (38, 92), (14, 92)]), fill=ROBE_H)
    d.rectangle(sb([20, 32, 26, 90]), fill=ROBE_H)
    d.rectangle(sb([70, 32, 76, 90]), fill=ROBE_D)
    # gold hem trim
    d.rectangle(sb([12, 89, 84, 92]), fill=GOLD)
    # robe belt
    d.rounded_rectangle(sb([28, 50, 68, 56]), radius=s(3), fill=ROBE_D)
    # arcane rune on robe
    d.ellipse(sb([40, 60, 56, 76]), fill=(120, 70, 210))
    d.ellipse(sb([42, 62, 54, 74]), fill=ROBE)
    d.ellipse(sb([46, 66, 50, 70]), fill=GLOW)

    # staff (left side)
    d.rectangle(sb([4, 8, 10, 80]), fill=WOOD)
    d.rectangle(sb([5, 8, 8, 80]), fill=(115, 80, 32))
    d.rectangle(sb([3, 24, 11, 28]), fill=GOLD)
    d.rectangle(sb([3, 50, 11, 54]), fill=GOLD)
    # orb glow
    img = composite_glow(img, 7, 6, 10, GLOW, passes=5)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([0, 0, 14, 14]), fill=GLOW)
    d.ellipse(sb([2, 2, 12, 12]), fill=GLOW_H)
    d.ellipse(sb([4, 4, 8, 8]), fill=(245, 230, 255, 220))

    # left arm holding staff
    d.rounded_rectangle(sb([10, 30, 24, 58]), radius=s(6), fill=ROBE)
    d.rectangle(sb([10, 30, 16, 58]), fill=ROBE_H)

    # right arm — casting pose, hand glowing
    d.rounded_rectangle(sb([72, 26, 88, 52]), radius=s(6), fill=ROBE)
    d.rectangle(sb([82, 26, 88, 52]), fill=ROBE_D)
    img = composite_glow(img, 84, 56, 8, GLOW, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([78, 50, 92, 62]), fill=GLOW)
    d.ellipse(sb([80, 52, 90, 60]), fill=GLOW_H)

    # neck
    d.rounded_rectangle(sb([39, 20, 57, 32]), radius=s(4), fill=SKIN)

    # head
    d.ellipse(sb([28, 4, 68, 26]), fill=SKIN)
    d.ellipse(sb([28, 4, 42, 18]), fill=SKIN)
    d.ellipse(sb([54, 6, 68, 20]), fill=SKIN_D)

    # wizard hat
    d.polygon(sp([(48, 0), (26, 22), (70, 22)]), fill=HAT)
    d.polygon(sp([(48, 0), (28, 20), (48, 20)]), fill=(56, 36, 92))
    d.ellipse(sb([24, 18, 72, 28]), fill=HAT)
    d.ellipse(sb([24, 18, 46, 26]), fill=(56, 36, 92))
    # star on hat tip
    img = composite_glow(img, 48, 2, 6, GLOW, passes=3)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([44, 0, 52, 6]), fill=GLOW_H)

    # beard
    d.polygon(sp([(31, 22), (65, 22), (62, 40), (34, 40)]), fill=BEARD)
    d.rectangle(sb([31, 22, 37, 40]), fill=(230, 226, 216))

    # brows (bushy white)
    d.rectangle(sb([31, 10, 43, 14]), fill=(185, 180, 170))
    d.rectangle(sb([53, 10, 65, 14]), fill=(185, 180, 170))

    # eyes — glowing purple-blue
    img = composite_glow(img, 38, 18, 5, GLOW, passes=3)
    img = composite_glow(img, 58, 18, 5, GLOW, passes=3)
    d = ImageDraw.Draw(img)
    for ex in [33, 53]:
        d.ellipse(sb([ex, 14, ex+12, 22]), fill=(8, 4, 18))
        d.ellipse(sb([ex+1, 15, ex+11, 21]), fill=(80, 48, 168))
        d.ellipse(sb([ex+2, 16, ex+10, 20]), fill=(155, 98, 252))
        d.ellipse(sb([ex+4, 16, ex+8, 20]), fill=(8, 4, 18))
        d.ellipse(sb([ex+2, 15, ex+4, 17]), fill=(255, 255, 255, 185))

    # nose
    d.ellipse(sb([43, 19, 53, 25]), fill=SKIN_D)

    return img


# ── ENEMY IMP ────────────────────────────────────────────────────────────────

def enemy_imp() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    RED   = (198, 35, 18)
    RED_H = (238, 78, 52)
    RED_D = (128, 16, 6)
    WING  = (148, 16, 8)
    WING_D= (82, 6, 2)
    EYE_C = (255, 198, 0)
    CLAW  = (75, 48, 18)
    TAIL  = (168, 26, 12)

    d.ellipse(sb([22, 88, 74, 95]), fill=(0,0,0,45))

    # wings (spread bat-like)
    d.polygon(sp([(48, 30), (4, 4), (16, 38), (38, 36)]), fill=WING)
    d.polygon(sp([(48, 30), (4, 4), (10, 26), (28, 32)]), fill=WING_D)
    d.polygon(sp([(48, 30), (92, 4), (80, 38), (58, 36)]), fill=WING)
    d.polygon(sp([(48, 30), (92, 4), (86, 26), (68, 32)]), fill=WING_D)
    d.line(sp([(48, 30), (4, 4)]), fill=RED_D, width=s(2))
    d.line(sp([(48, 30), (92, 4)]), fill=RED_D, width=s(2))
    d.line(sp([(18, 38), (4, 4)]), fill=RED_D, width=s(1))
    d.line(sp([(78, 38), (92, 4)]), fill=RED_D, width=s(1))

    # tail
    d.line(sp([(56, 64), (70, 72), (78, 64), (82, 76)]), fill=TAIL, width=s(4))
    d.polygon(sp([(76, 72), (86, 68), (80, 80)]), fill=RED_D)

    # body
    d.ellipse(sb([28, 36, 68, 76]), fill=RED)
    d.ellipse(sb([28, 36, 44, 56]), fill=RED_H)
    d.ellipse(sb([52, 52, 68, 68]), fill=RED_D)

    # arms/claws
    d.rounded_rectangle(sb([12, 40, 28, 56]), radius=s(5), fill=RED)
    d.rounded_rectangle(sb([68, 40, 84, 56]), radius=s(5), fill=RED)
    for cx, cy in [(6, 54), (10, 58), (14, 60)]:
        d.polygon(sp([(12, 52), (cx, cy), (16, 52)]), fill=CLAW)
    for cx, cy in [(90, 54), (86, 58), (82, 60)]:
        d.polygon(sp([(84, 52), (cx, cy), (80, 52)]), fill=CLAW)

    # legs
    d.rounded_rectangle(sb([32, 72, 43, 84]), radius=s(4), fill=RED)
    d.rounded_rectangle(sb([53, 72, 64, 84]), radius=s(4), fill=RED)
    for cx, cy in [(27, 86), (32, 90), (38, 88)]:
        d.polygon(sp([(32, 84), (cx, cy), (36, 84)]), fill=CLAW)
    for cx, cy in [(58, 90), (64, 86), (68, 90)]:
        d.polygon(sp([(58, 84), (cx, cy), (62, 84)]), fill=CLAW)

    # head
    d.ellipse(sb([28, 22, 68, 52]), fill=RED)
    d.ellipse(sb([28, 22, 44, 40]), fill=RED_H)

    # horns
    d.polygon(sp([(33, 26), (26, 6), (40, 24)]), fill=RED_D)
    d.polygon(sp([(63, 26), (70, 6), (56, 24)]), fill=RED_D)

    # eye glow
    img = composite_glow(img, 40, 36, 7, EYE_C, passes=4)
    img = composite_glow(img, 56, 36, 7, EYE_C, passes=4)
    d = ImageDraw.Draw(img)
    for ex in [32, 50]:
        d.ellipse(sb([ex, 30, ex+14, 44]), fill=(10, 4, 1))
        d.ellipse(sb([ex+1, 31, ex+13, 43]), fill=EYE_C)
        d.ellipse(sb([ex+2, 32, ex+12, 42]), fill=(255, 224, 52))
        d.ellipse(sb([ex+4, 34, ex+10, 40]), fill=(8, 2, 0))
        d.ellipse(sb([ex+2, 31, ex+5, 34]), fill=(255, 255, 255, 185))

    # jagged grin
    d.arc(sb([32, 40, 64, 54]), start=10, end=170, fill=RED_D, width=s(2))
    for tx in [35, 40, 46, 52, 57]:
        d.polygon(sp([(tx, 43), (tx+2, 48), (tx+4, 43)]), fill=(228, 214, 192))

    return img


# ── ENEMY GOBLIN ─────────────────────────────────────────────────────────────

def enemy_goblin() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    GREEN  = (72, 142, 48)
    GREEN_H= (102, 182, 68)
    GREEN_D= (44, 90, 26)
    EYE_C  = (255, 192, 0)
    LEATHER= (72, 48, 20)
    LEATH_D= (48, 30, 10)
    METAL  = (98, 92, 82)
    CLUB   = (100, 68, 26)
    BOOT   = (42, 26, 10)
    TOOTH  = (218, 212, 182)

    d.ellipse(sb([22, 88, 74, 95]), fill=(0,0,0,55))

    # club (left, raised high)
    d.rectangle(sb([4, 8, 12, 58]), fill=CLUB)
    d.rectangle(sb([5, 8, 9, 58]), fill=(132, 92, 38))
    d.ellipse(sb([0, 0, 16, 20]), fill=CLUB)
    d.ellipse(sb([2, 2, 14, 18]), fill=(132, 92, 38))
    for sy in [5, 9, 13]:
        d.ellipse(sb([1, sy, 5, sy+4]), fill=METAL)
        d.ellipse(sb([11, sy, 15, sy+4]), fill=METAL)
    for wy in [24, 32, 40, 48]:
        d.rectangle(sb([3, wy, 13, wy+3]), fill=LEATH_D)

    # boots
    d.rounded_rectangle(sb([27, 79, 46, 92]), radius=s(4), fill=BOOT)
    d.rounded_rectangle(sb([50, 79, 69, 92]), radius=s(4), fill=BOOT)

    # legs (squat, bowed)
    d.ellipse(sb([25, 60, 46, 84]), fill=GREEN)
    d.ellipse(sb([50, 60, 71, 84]), fill=GREEN)
    d.rectangle(sb([25, 60, 31, 80]), fill=GREEN_H)

    # belt
    d.rounded_rectangle(sb([22, 55, 74, 63]), radius=s(2), fill=LEATHER)
    for bx in [26, 35, 50, 59, 67]:
        d.ellipse(sb([bx, 57, bx+4, 61]), fill=METAL)
    d.rectangle(sb([43, 53, 53, 65]), fill=LEATH_D)

    # leather torso
    d.rounded_rectangle(sb([22, 28, 74, 58]), radius=s(5), fill=LEATHER)
    d.rectangle(sb([22, 28, 28, 58]), fill=(92, 62, 26))
    d.rectangle(sb([68, 28, 74, 58]), fill=LEATH_D)
    d.line(sp([(44, 29), (44, 57)]), fill=LEATH_D, width=s(2))
    d.rectangle(sb([26, 34, 41, 48]), fill=LEATH_D)
    d.rectangle(sb([53, 36, 66, 48]), fill=LEATH_D)

    # big pointy ears
    d.polygon(sp([(22, 22), (4, 10), (6, 36), (22, 32)]), fill=GREEN)
    d.polygon(sp([(22, 22), (6, 12), (6, 30)]), fill=GREEN_H)
    d.polygon(sp([(74, 22), (92, 10), (90, 36), (74, 32)]), fill=GREEN)
    d.polygon(sp([(74, 22), (90, 12), (90, 30)]), fill=GREEN_D)

    # arms
    d.rounded_rectangle(sb([9, 27, 23, 54]), radius=s(6), fill=GREEN)
    d.rectangle(sb([9, 27, 15, 54]), fill=GREEN_H)
    d.rounded_rectangle(sb([73, 27, 87, 54]), radius=s(6), fill=GREEN)
    # right arm buckler
    d.ellipse(sb([75, 50, 93, 68]), fill=LEATHER)
    d.ellipse(sb([77, 52, 91, 66]), fill=LEATH_D)
    d.ellipse(sb([81, 56, 89, 64]), fill=METAL)
    d.ellipse(sb([83, 58, 87, 62]), fill=(148, 138, 118))

    # neck + crude helmet
    d.rounded_rectangle(sb([40, 20, 56, 30]), radius=s(4), fill=GREEN)
    d.ellipse(sb([25, 8, 71, 30]), fill=METAL)
    d.rectangle(sb([25, 16, 71, 30]), fill=METAL)
    d.rectangle(sb([25, 16, 29, 30]), fill=(128, 122, 108))
    d.ellipse(sb([25, 10, 40, 22]), fill=(126, 120, 106))
    for hx in [31, 47, 63]:
        d.ellipse(sb([hx, 11, hx+4, 15]), fill=(138, 128, 108))

    # head
    d.ellipse(sb([26, 12, 70, 36]), fill=GREEN)
    d.ellipse(sb([26, 12, 40, 26]), fill=GREEN_H)
    d.ellipse(sb([56, 16, 70, 30]), fill=GREEN_D)

    # brow ridge
    d.rectangle(sb([28, 22, 42, 26]), fill=GREEN_D)
    d.rectangle(sb([54, 22, 68, 26]), fill=GREEN_D)

    # eyes (beady yellow, slit pupil) with glow
    img = composite_glow(img, 36, 28, 6, EYE_C, passes=3)
    img = composite_glow(img, 60, 28, 6, EYE_C, passes=3)
    d = ImageDraw.Draw(img)
    for ex in [29, 53]:
        d.ellipse(sb([ex, 24, ex+14, 34]), fill=(8, 4, 1))
        d.ellipse(sb([ex+1, 25, ex+13, 33]), fill=EYE_C)
        d.ellipse(sb([ex+2, 26, ex+12, 32]), fill=(255, 212, 42))
        d.rectangle(sb([ex+6, 25, ex+8, 33]), fill=(8, 4, 1))
        d.ellipse(sb([ex+2, 25, ex+4, 27]), fill=(255, 255, 255, 165))

    # flat nose
    d.ellipse(sb([42, 30, 54, 36]), fill=GREEN_D)
    d.ellipse(sb([42, 33, 46, 36]), fill=(28, 58, 16))
    d.ellipse(sb([50, 33, 54, 36]), fill=(28, 58, 16))

    # jagged grin + tusk
    d.arc(sb([30, 33, 66, 46]), start=15, end=165, fill=GREEN_D, width=s(2))
    for tx in [33, 38, 48, 57]:
        d.polygon(sp([(tx, 36), (tx+2, 41), (tx+4, 36)]), fill=TOOTH)
    d.polygon(sp([(45, 36), (50, 48), (55, 36)]), fill=(232, 226, 198))

    return img


# ── ENEMY SKELETON ────────────────────────────────────────────────────────────

def enemy_skeleton() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    BONE   = (222, 212, 185)
    BONE_H = (245, 238, 218)
    BONE_D = (152, 140, 115)
    RUST   = (108, 72, 38)
    RUST_D = (68, 42, 20)
    EYE_C  = (215, 48, 18)
    BLADE  = (172, 180, 192)
    BLADE_H= (208, 218, 228)

    d.ellipse(sb([22, 88, 74, 95]), fill=(0,0,0,55))

    # sword (right, upright)
    d.rectangle(sb([74, 8, 80, 68]), fill=BLADE)
    d.rectangle(sb([75, 8, 78, 68]), fill=BLADE_H)
    d.rectangle(sb([67, 36, 87, 42]), fill=(128, 88, 32))
    d.rounded_rectangle(sb([73, 62, 81, 74]), radius=s(3), fill=(98, 68, 26))
    d.ellipse(sb([73, 72, 81, 80]), fill=(118, 82, 28))

    # feet (bone toes)
    d.rounded_rectangle(sb([27, 80, 46, 92]), radius=s(3), fill=BONE_D)
    d.rounded_rectangle(sb([50, 80, 69, 92]), radius=s(3), fill=BONE_D)
    for bx in [28, 33, 38]:
        d.rectangle(sb([bx, 80, bx+3, 84]), fill=BONE)
    for bx in [51, 56, 61]:
        d.rectangle(sb([bx, 80, bx+3, 84]), fill=BONE)

    # shin bones
    d.rectangle(sb([31, 60, 37, 82]), fill=BONE)
    d.rectangle(sb([32, 60, 35, 82]), fill=BONE_H)
    d.rectangle(sb([59, 60, 65, 82]), fill=BONE)
    d.rectangle(sb([60, 60, 63, 82]), fill=BONE_H)

    # knee caps
    d.ellipse(sb([28, 54, 42, 65]), fill=BONE)
    d.ellipse(sb([54, 54, 68, 65]), fill=BONE)

    # thigh bones
    d.rectangle(sb([30, 44, 40, 62]), fill=BONE)
    d.rectangle(sb([56, 44, 66, 62]), fill=BONE)
    d.rectangle(sb([31, 44, 34, 62]), fill=BONE_H)

    # pelvis
    d.ellipse(sb([27, 42, 69, 58]), fill=BONE)
    d.ellipse(sb([31, 46, 46, 56]), fill=BONE_D)
    d.ellipse(sb([50, 46, 65, 56]), fill=BONE_D)

    # rusty breastplate
    d.rounded_rectangle(sb([25, 26, 71, 46]), radius=s(4), fill=RUST)
    d.rectangle(sb([25, 26, 31, 46]), fill=(128, 88, 48))
    d.rectangle(sb([65, 26, 71, 46]), fill=RUST_D)
    for ry in range(28, 44, 4):
        for rx in range(28, 68, 4):
            d.ellipse(sb([rx, ry, rx+3, ry+3]), fill=RUST_D)

    # visible ribs (peek around armor)
    for rib_y in [27, 31, 35, 39, 43]:
        d.arc(sb([27, rib_y, 46, rib_y+6]), start=180, end=360, fill=BONE, width=s(2))
        d.arc(sb([50, rib_y, 69, rib_y+6]), start=0, end=180, fill=BONE, width=s(2))

    # spine
    for sy in [26, 32, 38, 44]:
        d.ellipse(sb([44, sy, 52, sy+5]), fill=BONE)

    # left arm bones
    d.rounded_rectangle(sb([10, 24, 26, 44]), radius=s(6), fill=BONE)
    d.rectangle(sb([11, 24, 14, 44]), fill=BONE_H)
    d.ellipse(sb([8, 22, 22, 28]), fill=BONE)
    for hb in [8, 12, 16]:
        d.rectangle(sb([hb, 44, hb+3, 54]), fill=BONE)
    d.rectangle(sb([8, 42, 20, 46]), fill=BONE)

    # right arm
    d.rounded_rectangle(sb([70, 24, 86, 44]), radius=s(6), fill=BONE)
    d.rectangle(sb([82, 24, 85, 44]), fill=BONE_H)
    d.ellipse(sb([74, 22, 88, 28]), fill=BONE)

    # neck vertebrae
    for nv in [26, 30, 34]:
        d.ellipse(sb([44, nv, 52, nv+4]), fill=BONE)

    # skull
    d.ellipse(sb([28, 2, 68, 30]), fill=BONE)
    d.ellipse(sb([28, 2, 44, 18]), fill=BONE_H)
    d.ellipse(sb([52, 4, 68, 22]), fill=BONE_D)
    d.rounded_rectangle(sb([34, 22, 62, 32]), radius=s(4), fill=BONE_D)

    # eye glow (red soul fire)
    img = composite_glow(img, 37, 15, 8, EYE_C, passes=5)
    img = composite_glow(img, 59, 15, 8, EYE_C, passes=5)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([31, 10, 46, 22]), fill=(18, 6, 2))
    d.ellipse(sb([50, 10, 65, 22]), fill=(18, 6, 2))
    d.ellipse(sb([33, 12, 44, 20]), fill=EYE_C)
    d.ellipse(sb([52, 12, 63, 20]), fill=EYE_C)
    d.ellipse(sb([34, 13, 43, 19]), fill=(255, 92, 42))
    d.ellipse(sb([53, 13, 62, 19]), fill=(255, 92, 42))

    # nasal cavity
    d.polygon(sp([(44, 22), (48, 28), (52, 22)]), fill=(16, 6, 2))

    # teeth
    for tx in [36, 40, 44, 48, 52, 56]:
        d.rectangle(sb([tx, 28, tx+3, 34]), fill=BONE_H)

    return img


# ── ENEMY DEMON ──────────────────────────────────────────────────────────────

def enemy_demon() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    RED   = (162, 20, 10)
    RED_H = (212, 58, 36)
    RED_D = (102, 8, 4)
    HORN  = (52, 30, 16)
    EYE_C = (255, 148, 0)
    FIRE  = (255, 182, 0)
    FIRE2 = (255, 98, 8)
    CLAW  = (58, 36, 16)

    d.ellipse(sb([18, 88, 78, 95]), fill=(0,0,0,65))

    # fire aura behind body
    for fx, fy, fr in [(48, 80, 20), (30, 72, 12), (66, 74, 14)]:
        aura = glow_layer(fx, fy, fr, (255, 80, 0), passes=3)
        img = Image.alpha_composite(img, aura)
    d = ImageDraw.Draw(img)

    # tail
    d.line(sp([(62, 58), (78, 66), (84, 58), (88, 72), (84, 82)]), fill=RED_D, width=s(5))
    d.polygon(sp([(82, 78), (90, 73), (86, 86)]), fill=RED_D)

    # legs (massive)
    d.rounded_rectangle(sb([24, 56, 48, 88]), radius=s(8), fill=RED)
    d.rounded_rectangle(sb([52, 56, 76, 88]), radius=s(8), fill=RED)
    d.rectangle(sb([24, 56, 32, 88]), fill=RED_H)
    d.rectangle(sb([68, 56, 76, 88]), fill=RED_D)
    for cx, cy in [(18, 88), (24, 92), (30, 90), (36, 94)]:
        d.polygon(sp([(24, 86), (cx, cy), (32, 86)]), fill=CLAW)
    for cx, cy in [(60, 88), (66, 92), (72, 90), (78, 94)]:
        d.polygon(sp([(60, 86), (cx, cy), (72, 86)]), fill=CLAW)

    # body (huge, muscular)
    d.ellipse(sb([16, 24, 80, 62]), fill=RED)
    d.ellipse(sb([16, 24, 34, 44]), fill=RED_H)
    d.ellipse(sb([62, 32, 80, 56]), fill=RED_D)
    d.arc(sb([20, 30, 44, 54]), start=200, end=340, fill=RED_D, width=s(3))
    d.arc(sb([52, 30, 76, 54]), start=200, end=340, fill=RED_D, width=s(3))

    # left arm (claw forward, aggressive)
    d.rounded_rectangle(sb([0, 20, 20, 54]), radius=s(8), fill=RED)
    d.rectangle(sb([0, 20, 6, 54]), fill=RED_H)
    for cx, cy in [(0, 54), (4, 60), (8, 62), (14, 60)]:
        d.polygon(sp([(2, 52), (cx, cy), (12, 52)]), fill=CLAW)

    # right arm (raised, menacing)
    d.rounded_rectangle(sb([76, 12, 96, 48]), radius=s(8), fill=RED)
    d.rectangle(sb([90, 12, 96, 48]), fill=RED_D)
    for cx, cy in [(78, 8), (84, 4), (90, 6), (96, 10)]:
        d.polygon(sp([(82, 14), (cx, cy), (92, 14)]), fill=CLAW)

    # fire fists glow
    img = composite_glow(img, 8, 54, 10, FIRE, passes=4)
    img = composite_glow(img, 88, 8, 10, FIRE, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([0, 48, 16, 64]), fill=FIRE2)
    d.ellipse(sb([2, 50, 14, 62]), fill=FIRE)
    d.ellipse(sb([80, 2, 96, 18]), fill=FIRE2)
    d.ellipse(sb([82, 4, 94, 16]), fill=FIRE)

    # neck
    d.rounded_rectangle(sb([36, 18, 60, 28]), radius=s(5), fill=RED)

    # head
    d.ellipse(sb([22, 4, 74, 32]), fill=RED)
    d.ellipse(sb([22, 4, 40, 20]), fill=RED_H)
    d.ellipse(sb([56, 6, 74, 24]), fill=RED_D)

    # horns (large)
    d.polygon(sp([(28, 8), (6, 0), (20, 22), (32, 18)]), fill=HORN)
    d.polygon(sp([(28, 8), (8, 2), (16, 18)]), fill=(78, 48, 23))
    d.polygon(sp([(68, 8), (90, 0), (76, 22), (64, 18)]), fill=HORN)
    d.polygon(sp([(68, 8), (88, 2), (80, 18)]), fill=(78, 48, 23))

    # eyes (burning orange)
    img = composite_glow(img, 37, 18, 8, EYE_C, passes=5)
    img = composite_glow(img, 61, 18, 8, EYE_C, passes=5)
    d = ImageDraw.Draw(img)
    for ex in [28, 52]:
        d.ellipse(sb([ex, 13, ex+16, 25]), fill=(12, 2, 1))
        d.ellipse(sb([ex+1, 14, ex+15, 24]), fill=EYE_C)
        d.ellipse(sb([ex+2, 15, ex+14, 23]), fill=(255, 192, 42))
        d.ellipse(sb([ex+4, 16, ex+12, 22]), fill=(12, 2, 1))
        d.ellipse(sb([ex+2, 14, ex+5, 17]), fill=(255, 255, 200, 200))
        d.polygon(sp([(ex+6, 15), (ex+8, 13), (ex+10, 15), (ex+8, 23)]), fill=FIRE2)

    # nose and fanged mouth
    d.ellipse(sb([43, 22, 53, 28]), fill=RED_D)
    d.arc(sb([28, 26, 68, 36]), start=10, end=170, fill=RED_D, width=s(2))
    for tx in [31, 37, 44, 53, 59]:
        d.polygon(sp([(tx, 28), (tx+2, 35), (tx+4, 28)]), fill=(232, 218, 198))

    return img


# ── ENEMY GOLEM ──────────────────────────────────────────────────────────────

def enemy_golem() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    STONE  = (116, 108, 98)
    STONE_H= (158, 150, 136)
    STONE_D= (70, 62, 54)
    RUNE   = (78, 162, 208)
    RUNE2  = (138, 218, 255)
    CRACK  = (48, 42, 36)
    MOSS   = (60, 108, 50)
    LAVA   = (255, 88, 0)
    LAVA2  = (255, 175, 0)

    d.ellipse(sb([16, 88, 80, 96]), fill=(0,0,0,80))

    # legs (pillar-like)
    d.rounded_rectangle(sb([20, 58, 47, 90]), radius=s(6), fill=STONE)
    d.rounded_rectangle(sb([53, 58, 80, 90]), radius=s(6), fill=STONE)
    d.rectangle(sb([20, 58, 28, 90]), fill=STONE_H)
    d.rectangle(sb([72, 58, 80, 90]), fill=STONE_D)
    d.line(sp([(28, 60), (24, 72), (30, 80)]), fill=CRACK, width=s(2))
    d.line(sp([(64, 62), (68, 74), (64, 84)]), fill=CRACK, width=s(2))
    # lava cracks on legs
    img = composite_glow(img, 26, 70, 4, LAVA, passes=3)
    img = composite_glow(img, 66, 76, 4, LAVA, passes=3)
    d = ImageDraw.Draw(img)
    d.line(sp([(22, 62), (26, 72)]), fill=LAVA, width=s(1))
    d.line(sp([(66, 64), (70, 76)]), fill=LAVA, width=s(1))
    d.ellipse(sb([20, 84, 35, 90]), fill=MOSS)
    d.ellipse(sb([60, 86, 74, 91]), fill=MOSS)

    # body (massive cube torso)
    d.rounded_rectangle(sb([12, 26, 84, 62]), radius=s(6), fill=STONE)
    d.rectangle(sb([12, 26, 22, 62]), fill=STONE_H)
    d.rectangle(sb([74, 26, 84, 62]), fill=STONE_D)
    # body cracks
    d.line(sp([(36, 28), (32, 40), (40, 52)]), fill=CRACK, width=s(2))
    d.line(sp([(60, 30), (64, 45), (58, 58)]), fill=CRACK, width=s(2))
    # lava crack glow on body
    img = composite_glow(img, 36, 40, 5, LAVA, passes=4)
    img = composite_glow(img, 48, 44, 4, LAVA2, passes=3)
    d = ImageDraw.Draw(img)
    d.line(sp([(18, 44), (38, 40), (44, 60)]), fill=LAVA, width=s(2))
    d.line(sp([(60, 30), (64, 45)]), fill=LAVA, width=s(2))
    # glowing rune circle on chest
    img = composite_glow(img, 48, 44, 12, RUNE, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([36, 34, 60, 54]), fill=RUNE)
    d.ellipse(sb([38, 36, 58, 52]), fill=STONE)
    d.ellipse(sb([40, 38, 56, 50]), fill=RUNE)
    d.ellipse(sb([44, 42, 52, 46]), fill=RUNE2)
    d.line(sp([(48, 34), (48, 54)]), fill=RUNE2, width=s(2))
    d.line(sp([(36, 44), (60, 44)]), fill=RUNE2, width=s(2))
    d.line(sp([(39, 37), (57, 51)]), fill=RUNE, width=s(1))
    d.line(sp([(57, 37), (39, 51)]), fill=RUNE, width=s(1))

    # arms (massive)
    d.rounded_rectangle(sb([0, 22, 16, 72]), radius=s(6), fill=STONE)
    d.rectangle(sb([0, 22, 6, 72]), fill=STONE_H)
    d.rectangle(sb([10, 22, 16, 72]), fill=STONE_D)
    d.rounded_rectangle(sb([0, 68, 18, 82]), radius=s(4), fill=STONE_D)
    d.rounded_rectangle(sb([80, 12, 96, 62]), radius=s(6), fill=STONE)
    d.rectangle(sb([86, 12, 96, 62]), fill=STONE_D)
    d.rectangle(sb([80, 12, 86, 62]), fill=STONE_H)
    d.rounded_rectangle(sb([80, 6, 96, 20]), radius=s(4), fill=STONE_D)

    # neck column
    d.rounded_rectangle(sb([35, 18, 61, 28]), radius=s(4), fill=STONE)

    # head (rough cube)
    d.rounded_rectangle(sb([20, 2, 76, 24]), radius=s(4), fill=STONE)
    d.rectangle(sb([20, 2, 30, 24]), fill=STONE_H)
    d.rectangle(sb([66, 2, 76, 24]), fill=STONE_D)
    d.line(sp([(40, 4), (36, 14), (42, 20)]), fill=CRACK, width=s(2))
    d.line(sp([(54, 6), (58, 16)]), fill=CRACK, width=s(1))
    # moss on head corners
    d.ellipse(sb([20, 2, 36, 10]), fill=MOSS)
    d.ellipse(sb([64, 2, 76, 10]), fill=MOSS)

    # eyes (glowing rune slots)
    img = composite_glow(img, 34, 12, 8, RUNE2, passes=4)
    img = composite_glow(img, 62, 12, 8, RUNE2, passes=4)
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


# ── BOSS: DUNGEON LORD ────────────────────────────────────────────────────────

def enemy_boss_dungeon_lord() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    ARMOR  = (18, 12, 30)
    ARMOR_H= (42, 30, 64)
    ARMOR_D= (8, 4, 14)
    GOLD   = (208, 162, 18)
    GOLD_D = (148, 108, 6)
    CAPE   = (138, 18, 28)
    CAPE_H = (182, 32, 44)
    SKIN   = (162, 98, 58)
    SKIN_D = (112, 62, 28)
    PURPLE = (158, 48, 218)
    PURP_H = (198, 98, 255)
    EYE_C  = (218, 158, 255)
    BLADE  = (188, 198, 212)
    BLADE_H= (218, 228, 245)

    d.ellipse(sb([20, 88, 76, 96]), fill=(0,0,0,65))

    # dark magic aura
    for ax, ay, ar in [(48, 48, 36), (48, 78, 22), (20, 60, 16), (76, 60, 16)]:
        aura = glow_layer(ax, ay, ar, (118, 18, 198), passes=3)
        img = Image.alpha_composite(img, aura)
    d = ImageDraw.Draw(img)

    # flowing crimson cape
    d.polygon(sp([(22, 26), (74, 26), (86, 92), (10, 92)]), fill=CAPE)
    d.polygon(sp([(22, 26), (38, 26), (30, 92), (12, 92)]), fill=CAPE_H)
    d.rectangle(sb([10, 26, 18, 92]), fill=CAPE_H)
    d.rectangle(sb([78, 26, 86, 92]), fill=(108, 12, 20))

    # greatsword (behind, upright)
    d.rectangle(sb([3, 2, 11, 72]), fill=BLADE)
    d.rectangle(sb([4, 2, 8, 72]), fill=BLADE_H)
    d.rectangle(sb([0, 34, 14, 40]), fill=GOLD)
    d.polygon(sp([(3, 2), (7, 2), (7, 14), (3, 14)]), fill=BLADE_H)
    d.rounded_rectangle(sb([4, 66, 10, 78]), radius=s(3), fill=GOLD)

    # greaves
    d.rounded_rectangle(sb([24, 78, 46, 92]), radius=s(4), fill=ARMOR)
    d.rounded_rectangle(sb([50, 78, 72, 92]), radius=s(4), fill=ARMOR)
    d.rectangle(sb([24, 78, 30, 88]), fill=ARMOR_H)
    d.rectangle(sb([24, 78, 46, 81]), fill=GOLD)
    d.rectangle(sb([50, 78, 72, 81]), fill=GOLD)

    # armored legs
    d.rounded_rectangle(sb([24, 58, 46, 80]), radius=s(5), fill=ARMOR)
    d.rounded_rectangle(sb([50, 58, 72, 80]), radius=s(5), fill=ARMOR)
    d.rectangle(sb([24, 58, 30, 80]), fill=ARMOR_H)
    d.rectangle(sb([66, 58, 72, 80]), fill=ARMOR_D)

    # belt/skirt
    d.rounded_rectangle(sb([20, 54, 76, 62]), radius=s(3), fill=ARMOR_D)
    for bx in [24, 32, 40, 48, 56, 64]:
        d.rectangle(sb([bx, 54, bx+6, 62]), fill=ARMOR)
    d.rectangle(sb([43, 53, 53, 63]), fill=GOLD)

    # breastplate
    d.rounded_rectangle(sb([18, 24, 78, 58]), radius=s(6), fill=ARMOR)
    d.rectangle(sb([18, 24, 26, 58]), fill=ARMOR_H)
    d.rectangle(sb([70, 24, 78, 58]), fill=ARMOR_D)
    d.rounded_rectangle(sb([28, 30, 68, 50]), radius=s(4), fill=ARMOR_D)
    d.rounded_rectangle(sb([30, 32, 66, 48]), radius=s(3), fill=ARMOR)
    # center gem
    img = composite_glow(img, 48, 40, 8, PURPLE, passes=4)
    d = ImageDraw.Draw(img)
    d.ellipse(sb([40, 34, 56, 46]), fill=PURPLE)
    d.ellipse(sb([41, 35, 55, 45]), fill=PURP_H)
    d.ellipse(sb([44, 38, 52, 42]), fill=(240, 220, 255))
    # gold trim
    d.rectangle(sb([18, 24, 78, 27]), fill=GOLD)
    d.rectangle(sb([18, 54, 78, 57]), fill=GOLD)

    # pauldrons
    d.ellipse(sb([4, 17, 26, 36]), fill=ARMOR)
    d.ellipse(sb([4, 17, 14, 27]), fill=ARMOR_H)
    d.ellipse(sb([70, 17, 92, 36]), fill=ARMOR)
    d.ellipse(sb([80, 17, 92, 27]), fill=ARMOR_D)
    d.arc(sb([4, 17, 26, 36]), start=180, end=360, fill=GOLD, width=s(2))
    d.arc(sb([70, 17, 92, 36]), start=180, end=360, fill=GOLD, width=s(2))

    # arms
    d.rounded_rectangle(sb([6, 28, 20, 58]), radius=s(6), fill=ARMOR)
    d.rectangle(sb([6, 28, 12, 58]), fill=ARMOR_H)
    d.rounded_rectangle(sb([4, 54, 18, 66]), radius=s(4), fill=ARMOR_D)
    d.rounded_rectangle(sb([76, 22, 90, 50]), radius=s(6), fill=ARMOR)
    d.rectangle(sb([84, 22, 90, 50]), fill=ARMOR_D)
    d.rounded_rectangle(sb([76, 18, 90, 28]), radius=s(4), fill=ARMOR_D)

    # neck gorget
    d.rounded_rectangle(sb([37, 16, 59, 26]), radius=s(4), fill=ARMOR)

    # crown
    for cx in [26, 35, 47, 59, 68]:
        h = 9 if cx == 47 else 5
        d.rectangle(sb([cx, 4-h, cx+5, 8]), fill=GOLD)
        d.ellipse(sb([cx, 2-h, cx+5, 4-h+2]), fill=GOLD_D)
    d.rectangle(sb([24, 8, 72, 14]), fill=GOLD)
    d.rectangle(sb([24, 8, 28, 14]), fill=(232, 193, 33))
    d.ellipse(sb([30, 7, 38, 13]), fill=PURPLE)
    d.ellipse(sb([52, 7, 60, 13]), fill=PURPLE)
    d.ellipse(sb([42, 5, 52, 11]), fill=EYE_C)

    # head
    d.ellipse(sb([26, 8, 70, 28]), fill=SKIN)
    d.ellipse(sb([26, 8, 40, 22]), fill=SKIN)
    d.ellipse(sb([56, 10, 70, 24]), fill=SKIN_D)

    # eyes glowing purple
    img = composite_glow(img, 36, 18, 7, PURPLE, passes=5)
    img = composite_glow(img, 60, 18, 7, PURPLE, passes=5)
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


# ── BOSS: THE WARDEN ─────────────────────────────────────────────────────────

def enemy_boss_warden() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    PLATE  = (52, 58, 63)
    PLATE_H= (86, 94, 100)
    PLATE_D= (26, 30, 33)
    GOLD   = (192, 152, 13)
    GOLD_D = (138, 102, 6)
    EYE_C  = (255, 202, 0)
    CHAIN  = (70, 76, 80)
    HALB   = (158, 166, 176)
    HALB_H = (192, 202, 215)
    RED    = (178, 28, 18)

    d.ellipse(sb([16, 88, 80, 96]), fill=(0,0,0,75))

    # halberd (upright, right side)
    d.rectangle(sb([78, 4, 84, 82]), fill=(88, 58, 22))
    d.rectangle(sb([79, 4, 82, 82]), fill=(118, 83, 33))
    d.polygon(sp([(73, 4), (89, 4), (91, 24), (79, 28), (74, 24)]), fill=HALB)
    d.polygon(sp([(75, 4), (87, 4), (87, 20), (79, 24)]), fill=HALB_H)
    d.polygon(sp([(89, 13), (96, 7), (93, 22)]), fill=HALB)
    d.rectangle(sb([75, 26, 92, 30]), fill=GOLD)

    # greaves
    d.rounded_rectangle(sb([22, 76, 46, 92]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([50, 76, 74, 92]), radius=s(5), fill=PLATE)
    d.rectangle(sb([22, 76, 30, 90]), fill=PLATE_H)
    d.ellipse(sb([24, 70, 44, 80]), fill=PLATE)
    d.ellipse(sb([26, 71, 42, 79]), fill=PLATE_H)
    d.ellipse(sb([52, 70, 72, 80]), fill=PLATE)

    # armored legs
    d.rounded_rectangle(sb([22, 56, 46, 78]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([50, 56, 74, 78]), radius=s(5), fill=PLATE)
    d.rectangle(sb([22, 56, 28, 78]), fill=PLATE_H)
    d.rectangle(sb([68, 56, 74, 78]), fill=PLATE_D)

    # tassets
    d.rounded_rectangle(sb([18, 52, 78, 60]), radius=s(3), fill=PLATE_D)
    for bx in [20, 30, 42, 52, 62]:
        d.rounded_rectangle(sb([bx, 52, bx+8, 60]), radius=s(2), fill=PLATE)
    d.rectangle(sb([18, 52, 26, 60]), fill=PLATE_H)
    d.rectangle(sb([43, 50, 53, 62]), fill=GOLD)

    # massive breastplate
    d.rounded_rectangle(sb([14, 20, 82, 56]), radius=s(6), fill=PLATE)
    d.rectangle(sb([14, 20, 24, 56]), fill=PLATE_H)
    d.rectangle(sb([72, 20, 82, 56]), fill=PLATE_D)
    for ry in [24, 32, 40, 48]:
        d.rectangle(sb([16, ry, 80, ry+4]), fill=PLATE_D)
        d.rectangle(sb([16, ry, 22, ry+4]), fill=PLATE_H)
    d.rectangle(sb([14, 20, 82, 24]), fill=GOLD)
    d.rectangle(sb([14, 52, 82, 56]), fill=GOLD)
    d.rectangle(sb([14, 20, 18, 56]), fill=GOLD)
    d.rectangle(sb([78, 20, 82, 56]), fill=GOLD)
    # red cross emblem
    d.rectangle(sb([43, 28, 53, 48]), fill=RED)
    d.rectangle(sb([37, 34, 59, 42]), fill=RED)
    d.rectangle(sb([45, 30, 51, 46]), fill=(218, 38, 26))

    # tower pauldrons
    d.rounded_rectangle(sb([0, 14, 18, 42]), radius=s(5), fill=PLATE)
    d.rectangle(sb([0, 14, 6, 42]), fill=PLATE_H)
    d.rectangle(sb([12, 14, 18, 42]), fill=PLATE_D)
    d.rectangle(sb([0, 14, 18, 18]), fill=GOLD)
    d.rounded_rectangle(sb([78, 14, 96, 42]), radius=s(5), fill=PLATE)
    d.rectangle(sb([90, 14, 96, 42]), fill=PLATE_D)
    d.rectangle(sb([78, 14, 84, 42]), fill=PLATE_H)
    d.rectangle(sb([78, 14, 96, 18]), fill=GOLD)

    # arms + gauntlets
    d.rounded_rectangle(sb([4, 28, 16, 56]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([80, 20, 92, 48]), radius=s(5), fill=PLATE)
    d.rounded_rectangle(sb([2, 52, 16, 66]), radius=s(4), fill=PLATE_D)
    d.rounded_rectangle(sb([80, 44, 94, 56]), radius=s(4), fill=PLATE_D)
    d.rectangle(sb([2, 52, 8, 66]), fill=PLATE)
    d.rectangle(sb([2, 52, 16, 55]), fill=GOLD)
    d.rectangle(sb([80, 44, 94, 47]), fill=GOLD)

    # full-face closed helmet
    d.rounded_rectangle(sb([20, 2, 76, 24]), radius=s(6), fill=PLATE)
    d.rectangle(sb([20, 2, 28, 24]), fill=PLATE_H)
    d.rectangle(sb([68, 2, 76, 24]), fill=PLATE_D)
    d.rectangle(sb([26, 10, 70, 18]), fill=PLATE_D)
    d.rectangle(sb([26, 10, 32, 18]), fill=PLATE)
    # eye slit glow
    img = composite_glow(img, 38, 14, 8, EYE_C, passes=4)
    img = composite_glow(img, 58, 14, 8, EYE_C, passes=4)
    d = ImageDraw.Draw(img)
    d.rectangle(sb([30, 11, 46, 16]), fill=(12, 8, 1))
    d.rectangle(sb([50, 11, 66, 16]), fill=(12, 8, 1))
    d.rectangle(sb([32, 12, 44, 15]), fill=EYE_C)
    d.rectangle(sb([52, 12, 64, 15]), fill=EYE_C)
    d.rectangle(sb([34, 12, 38, 15]), fill=(255, 232, 82))
    d.rectangle(sb([54, 12, 58, 15]), fill=(255, 232, 82))
    # helm crest
    d.rectangle(sb([44, 2, 52, 12]), fill=GOLD)
    d.rectangle(sb([45, 2, 51, 12]), fill=(228, 186, 26))
    d.rounded_rectangle(sb([24, 18, 72, 26]), radius=s(3), fill=PLATE)
    d.rectangle(sb([24, 18, 30, 26]), fill=PLATE_H)
    d.rectangle(sb([20, 22, 76, 26]), fill=GOLD)

    return img


# ── BOSS: ABYSS KEEPER ────────────────────────────────────────────────────────

def enemy_boss_abyss_keeper() -> Image.Image:
    img = new_canvas()
    d = ImageDraw.Draw(img)

    BODY   = (22, 6, 45)
    BODY_H = (48, 18, 88)
    BODY_D = (10, 2, 25)
    TENT   = (38, 10, 68)
    TENT_D = (18, 3, 38)
    EYE1   = (218, 78, 255)
    EYE2   = (155, 18, 198)
    GLOW   = (178, 58, 255)
    GLOW2  = (118, 8, 178)
    ORB    = (248, 198, 255)

    d.ellipse(sb([18, 88, 78, 96]), fill=(0,0,0,80))

    # void aura (very wide)
    for ax, ay, ar in [(48, 48, 46), (48, 72, 32), (18, 62, 24), (78, 60, 20)]:
        aura = glow_layer(ax, ay, ar, (118, 0, 198), passes=4)
        img = Image.alpha_composite(img, aura)
    d = ImageDraw.Draw(img)

    # tentacles (spread from body base)
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
        flat = [coord for pt in pts for coord in (s(pt[0]), s(pt[1]))]
        d.line(flat, fill=TENT, width=s(5))
        d.line(flat, fill=TENT_D, width=s(2))
        # sucker spots
        mx = (pts[0][0] + pts[1][0]) // 2
        my = (pts[0][1] + pts[1][1]) // 2
        d.ellipse(sb([mx-3, my-3, mx+3, my+3]), fill=EYE2)

    # cloak/body mass
    d.ellipse(sb([14, 32, 82, 74]), fill=BODY)
    d.ellipse(sb([14, 32, 34, 54]), fill=BODY_H)
    d.ellipse(sb([62, 44, 82, 68]), fill=BODY_D)
    d.arc(sb([16, 34, 48, 66]), start=200, end=320, fill=BODY_H, width=s(2))

    # floating orbs of dark energy
    for ox, oy, or_ in [(10, 34, 7), (86, 36, 6), (12, 58, 5), (84, 62, 5)]:
        img = composite_glow(img, ox, oy, or_+4, GLOW, passes=3)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([ox-or_, oy-or_, ox+or_, oy+or_]), fill=GLOW)
        d.ellipse(sb([ox-or_+2, oy-or_+2, ox+or_-2, oy+or_-2]), fill=ORB)

    # shadowy arm tendrils
    d.polygon(sp([(14, 38), (0, 28), (6, 52), (18, 50)]), fill=BODY)
    d.polygon(sp([(14, 38), (2, 30), (6, 48)]), fill=BODY_H)
    d.polygon(sp([(82, 38), (96, 28), (90, 52), (78, 50)]), fill=BODY)
    d.polygon(sp([(82, 38), (94, 30), (90, 48)]), fill=BODY_D)
    for cx, cy in [(0, 26), (2, 22), (6, 24), (10, 22)]:
        d.line(sp([(6, 32), (cx, cy)]), fill=TENT_D, width=s(2))
    for cx, cy in [(96, 26), (94, 22), (90, 24), (86, 22)]:
        d.line(sp([(90, 32), (cx, cy)]), fill=TENT_D, width=s(2))

    # neck / upper body
    d.ellipse(sb([32, 16, 64, 42]), fill=BODY)
    d.ellipse(sb([32, 16, 44, 30]), fill=BODY_H)

    # head (alien, multi-eyed)
    d.ellipse(sb([22, 0, 74, 36]), fill=BODY)
    d.ellipse(sb([22, 0, 38, 18]), fill=BODY_H)
    d.ellipse(sb([58, 4, 74, 26]), fill=BODY_D)

    # crown tentacles from head
    for hx, hy in [(26, 4), (36, 2), (48, 0), (60, 2), (70, 4)]:
        d.polygon(sp([(hx, 8), (hx-3, hy), (hx+3, hy)]), fill=TENT)
        img = composite_glow(img, hx, hy, 4, EYE1, passes=2)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([hx-2, hy-2, hx+2, hy+2]), fill=EYE1)

    # 3 main eyes (glowing)
    for ecx, ecy, er in [(34, 15, 8), (62, 15, 8), (48, 20, 10)]:
        img = composite_glow(img, ecx, ecy, er+4, EYE1, passes=5)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([ecx-er, ecy-er, ecx+er, ecy+er]), fill=(8, 1, 15))
        d.ellipse(sb([ecx-er+1, ecy-er+1, ecx+er-1, ecy+er-1]), fill=EYE2)
        d.ellipse(sb([ecx-er+3, ecy-er+3, ecx+er-3, ecy+er-3]), fill=EYE1)
        d.ellipse(sb([ecx-3, ecy-3, ecx+3, ecy+3]), fill=(8, 1, 15))
        d.ellipse(sb([ecx-er+1, ecy-er+1, ecx-er+5, ecy-er+5]), fill=(255,255,255,200))

    # mouth (toothy rift)
    d.arc(sb([30, 26, 66, 38]), start=10, end=170, fill=(6, 1, 12), width=s(3))
    for tx in [33, 38, 44, 52, 58]:
        d.polygon(sp([(tx, 29), (tx+2, 36), (tx+4, 29)]), fill=EYE1)

    # small scattered eyes on body
    for ex, ey, er in [(18, 46, 4), (76, 44, 4), (22, 60, 3), (72, 58, 3)]:
        img = composite_glow(img, ex, ey, er+2, EYE2, passes=2)
        d = ImageDraw.Draw(img)
        d.ellipse(sb([ex-er, ey-er, ex+er, ey+er]), fill=(6, 1, 12))
        d.ellipse(sb([ex-er+1, ey-er+1, ex+er-1, ey+er-1]), fill=EYE2)
        d.ellipse(sb([ex-1, ey-1, ex+1, ey+1]), fill=(6, 1, 12))

    return img


# ── PORTRAITS ─────────────────────────────────────────────────────────────────

PORTRAIT_CONFIG: dict = {
    "brawler":  ("hero_brawler",  (44, 22, 28), (72, 36, 18), (220, 100, 30)),
    "rogue":    ("hero_rogue",    (14,  6, 24), (32, 16, 50), (138,  96, 218)),
    "arcanist": ("hero_arcanist", (16,  6, 36), (26, 10, 58), (168, 110, 255)),
}


def make_portrait(sprite_img: Image.Image,
                  bg_top: tuple, bg_bot: tuple, accent: tuple) -> Image.Image:
    """Generate a 200×190 portrait card from a 128×128 sprite."""
    PW, PH = 200, 190
    cr, cg, cb = accent[:3]

    # Gradient background
    canvas = Image.new("RGBA", (PW, PH), (0, 0, 0, 255))
    d = ImageDraw.Draw(canvas)
    for y in range(PH):
        t = y / PH
        rv = int(bg_top[0] * (1 - t) + bg_bot[0] * t)
        gv = int(bg_top[1] * (1 - t) + bg_bot[1] * t)
        bv = int(bg_top[2] * (1 - t) + bg_bot[2] * t)
        d.line([(0, y), (PW, y)], fill=(rv, gv, bv, 255))

    # Soft radial glow behind the sprite
    glow = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(5, 0, -1):
        r2 = 60 * i // 3
        al = min(255, 55 * i // 5)
        cx, cy = PW // 2, PH // 2 - 10
        gd.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(cr, cg, cb, al))
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(20)))

    # Scale sprite to 160×160 and center
    sprite_size = 160
    scaled = sprite_img.resize((sprite_size, sprite_size), Image.LANCZOS)
    sx = (PW - sprite_size) // 2
    sy = max(0, (PH - sprite_size) // 2 - 8)
    canvas.paste(scaled, (sx, sy), scaled)

    # Accent strip at bottom
    d = ImageDraw.Draw(canvas)
    d.rectangle([0, PH - 13, PW, PH], fill=(cr // 2, cg // 2, cb // 2, 255))
    d.rectangle([0, PH - 13, PW, PH - 11], fill=(cr, cg, cb, 255))

    # Single-pixel class-color border on three sides
    d.rectangle([0, 0, PW - 1, 0], fill=(cr, cg, cb, 180))
    d.rectangle([0, 0, 0, PH - 1], fill=(cr, cg, cb, 180))
    d.rectangle([PW - 1, 0, PW - 1, PH - 1], fill=(cr, cg, cb, 180))

    return canvas


# ── SPRITE REGISTRY ───────────────────────────────────────────────────────────

SPRITES = {
    "hero_brawler":             hero_brawler,
    "hero_rogue":               hero_rogue,
    "hero_arcanist":            hero_arcanist,
    "enemy_imp":                enemy_imp,
    "enemy_goblin":             enemy_goblin,
    "enemy_skeleton":           enemy_skeleton,
    "enemy_demon":              enemy_demon,
    "enemy_golem":              enemy_golem,
    "enemy_boss_dungeon_lord":  enemy_boss_dungeon_lord,
    "enemy_boss_warden":        enemy_boss_warden,
    "enemy_boss_abyss_keeper":  enemy_boss_abyss_keeper,
    "enemy_boss":               enemy_boss_dungeon_lord,
}

if __name__ == "__main__":
    os.makedirs(OUTPUT, exist_ok=True)
    os.makedirs(PORTRAIT_OUTPUT, exist_ok=True)

    print(f"=== Battle Sprites (128×128, 4× supersampled) → {OUTPUT}/")
    for name, fn in SPRITES.items():
        sys.stdout.write(f"  {name:<35} ")
        sys.stdout.flush()
        img = fn()
        save(img, name)

    print(f"\n=== Class Portraits (200×190) → {PORTRAIT_OUTPUT}/")
    for cls_id, (sprite_key, bg_top, bg_bot, accent) in PORTRAIT_CONFIG.items():
        sys.stdout.write(f"  {cls_id:<12} ")
        sys.stdout.flush()
        sprite_img = SPRITES[sprite_key]()
        sprite_final = finalize(sprite_img)
        portrait = make_portrait(sprite_final, bg_top, bg_bot, accent)
        path = os.path.join(PORTRAIT_OUTPUT, f"{cls_id}.png")
        portrait.save(path)
        print(f"✓  {os.path.getsize(path):>7,} bytes")

    print("\nDone — all assets generated.")
