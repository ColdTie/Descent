#!/usr/bin/env python3
"""Generate Floor-3 ally sprites: Marcus (knight) and Lina (hexweaver).
These two NPCs join Carl temporarily for the first boss fight on Floor 3.
Distinct silhouettes vs hero classes so it's obvious they're separate allies.
Outputs:
  assets/sprites/ally_marcus.png  (192x192 RGBA)  - knight with shield + sword
  assets/sprites/ally_lina.png    (192x192 RGBA)  - hooded mage with staff
"""

from PIL import Image, ImageDraw
import os

W, H = 192, 192
os.makedirs("assets/sprites", exist_ok=True)

# ── Shared palette helpers ─────────────────────────────────────────────────────
OUTLINE = (18, 14, 24, 255)
SHADOW  = (12, 10, 18, 220)


def _make_img():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# ── Marcus the Steadfast — knight ally ─────────────────────────────────────────
def gen_marcus():
    img, d = _make_img()
    cx = W // 2

    SKIN       = (224, 184, 138, 255)
    SKIN_DARK  = (170, 120, 78, 255)
    ARMOR      = (170, 188, 210, 255)   # cool steel
    ARMOR_HI   = (218, 232, 245, 255)
    ARMOR_LO   = (90, 110, 138, 255)
    CLOAK      = (38, 80, 130, 255)     # deep blue cloak
    CLOAK_HI   = (72, 122, 178, 255)
    GOLD       = (242, 198, 64, 255)
    GOLD_DARK  = (158, 116, 22, 255)
    SHIELD_RED = (172, 38, 44, 255)
    SHIELD_HI  = (220, 90, 96, 255)
    BLADE      = (224, 232, 240, 255)
    BLADE_HI   = (255, 255, 255, 255)
    HILT       = (104, 64, 30, 255)

    # ── Cloak (behind body) ────────────────────────────────────────────────────
    d.polygon([(56, 98), (44, 168), (84, 178), (96, 100)], fill=CLOAK, outline=OUTLINE)
    d.polygon([(136, 98), (148, 168), (108, 178), (96, 100)], fill=CLOAK, outline=OUTLINE)
    d.polygon([(70, 110), (62, 160), (80, 168), (88, 112)], fill=CLOAK_HI)

    # ── Legs ───────────────────────────────────────────────────────────────────
    d.rectangle([78, 150, 92, 178], fill=ARMOR, outline=OUTLINE)
    d.rectangle([100, 150, 114, 178], fill=ARMOR, outline=OUTLINE)
    d.rectangle([76, 174, 96, 182], fill=ARMOR_LO, outline=OUTLINE)   # boot
    d.rectangle([98, 174, 118, 182], fill=ARMOR_LO, outline=OUTLINE)  # boot

    # ── Torso / chestplate ─────────────────────────────────────────────────────
    d.rectangle([66, 96, 126, 152], fill=ARMOR, outline=OUTLINE)
    # Chest highlights
    d.polygon([(72, 102), (96, 102), (96, 144), (72, 130)], fill=ARMOR_HI)
    # Belt
    d.rectangle([66, 144, 126, 154], fill=GOLD_DARK, outline=OUTLINE)
    d.rectangle([90, 146, 102, 152], fill=GOLD)
    # Center crest cross
    d.polygon([(94, 108), (102, 108), (102, 140), (94, 140)], fill=GOLD)
    d.polygon([(86, 118), (110, 118), (110, 126), (86, 126)], fill=GOLD)

    # ── Pauldrons (shoulder plates) ────────────────────────────────────────────
    d.ellipse([56, 90, 84, 116], fill=ARMOR, outline=OUTLINE)
    d.ellipse([108, 90, 136, 116], fill=ARMOR, outline=OUTLINE)
    d.ellipse([60, 92, 74, 102], fill=ARMOR_HI)
    d.ellipse([114, 92, 128, 102], fill=ARMOR_HI)

    # ── Sword arm (right side of image) holds upright blade ────────────────────
    d.rectangle([124, 104, 138, 146], fill=ARMOR, outline=OUTLINE)
    # Blade
    d.polygon([(127, 42), (135, 42), (135, 108), (127, 108)], fill=BLADE, outline=OUTLINE)
    d.line([(131, 46), (131, 104)], fill=BLADE_HI, width=2)
    # Crossguard
    d.rectangle([118, 106, 144, 114], fill=GOLD, outline=OUTLINE)
    d.rectangle([125, 113, 137, 132], fill=HILT, outline=OUTLINE)
    d.ellipse([124, 130, 138, 142], fill=GOLD, outline=OUTLINE)

    # ── Shield arm (left side of image) ────────────────────────────────────────
    d.rectangle([54, 104, 68, 146], fill=ARMOR, outline=OUTLINE)
    # Kite shield
    d.polygon([(28, 100), (66, 96), (66, 152), (44, 160), (28, 138)],
              fill=SHIELD_RED, outline=OUTLINE)
    d.polygon([(34, 106), (60, 104), (60, 124), (40, 122)], fill=SHIELD_HI)
    # Gold cross on shield
    d.rectangle([42, 110, 50, 148], fill=GOLD, outline=OUTLINE)
    d.rectangle([32, 122, 60, 130], fill=GOLD, outline=OUTLINE)

    # ── Neck + head ────────────────────────────────────────────────────────────
    d.rectangle([90, 86, 106, 98], fill=SKIN_DARK, outline=OUTLINE)
    # Great helm (rounded top, flat bottom, narrow visor slit)
    d.ellipse([78, 38, 118, 76], fill=ARMOR, outline=OUTLINE)
    d.rectangle([78, 56, 118, 92], fill=ARMOR, outline=OUTLINE)
    # Crown crest
    d.polygon([(86, 38), (98, 24), (110, 38)], fill=GOLD, outline=OUTLINE)
    d.line([(98, 24), (98, 36)], fill=GOLD_DARK, width=2)
    # Visor slit (T-shape)
    d.rectangle([86, 64, 110, 70], fill=OUTLINE)
    d.rectangle([95, 70, 101, 84], fill=OUTLINE)
    # Helmet highlight
    d.line([(82, 50), (90, 44)], fill=ARMOR_HI, width=3)

    # ── Save ───────────────────────────────────────────────────────────────────
    img.save("assets/sprites/ally_marcus.png")
    print("Generated ally_marcus.png (192x192 — knight ally)")


# ── Lina Hexweaver — hooded mage ally ──────────────────────────────────────────
def gen_lina():
    img, d = _make_img()
    cx = W // 2

    SKIN      = (240, 208, 174, 255)
    SKIN_DARK = (190, 150, 116, 255)
    ROBE      = (76, 36, 118, 255)        # deep purple
    ROBE_HI   = (138, 88, 196, 255)
    ROBE_LO   = (38, 14, 70, 255)
    HOOD      = (50, 22, 88, 255)
    GOLD      = (244, 200, 78, 255)
    GOLD_DARK = (164, 122, 24, 255)
    STAFF_WD  = (96, 60, 30, 255)
    STAFF_DK  = (54, 30, 12, 255)
    ORB       = (160, 250, 232, 255)      # arcane teal
    ORB_HI    = (255, 255, 255, 255)
    ORB_GLOW  = (90, 220, 210, 130)
    EYE_GLOW  = (180, 252, 232, 255)

    # ── Magic orb glow halo (behind everything, top-right) ─────────────────────
    d.ellipse([20, 30, 80, 90], fill=ORB_GLOW)
    d.ellipse([28, 38, 72, 82], fill=(150, 230, 220, 90))

    # ── Robe lower (wide, tapered floor-length) ────────────────────────────────
    d.polygon([(58, 110), (40, 184), (152, 184), (134, 110)],
              fill=ROBE, outline=OUTLINE)
    # Robe inner shadow
    d.polygon([(64, 122), (52, 178), (86, 178), (88, 122)], fill=ROBE_LO)
    # Mid robe highlight stripe
    d.polygon([(98, 116), (110, 116), (118, 180), (104, 180)], fill=ROBE_HI)
    # Hem trim
    d.rectangle([40, 178, 152, 184], fill=GOLD, outline=OUTLINE)

    # ── Sleeves / arms ─────────────────────────────────────────────────────────
    # Staff-holding arm (left side of image): bent across body to grip staff
    d.polygon([(60, 110), (40, 130), (52, 156), (74, 138)],
              fill=ROBE, outline=OUTLINE)
    # Hand
    d.ellipse([42, 124, 58, 140], fill=SKIN, outline=OUTLINE)
    # Other arm tucked into front of robe
    d.polygon([(118, 112), (140, 130), (132, 156), (110, 140)],
              fill=ROBE, outline=OUTLINE)
    d.ellipse([130, 126, 146, 142], fill=SKIN, outline=OUTLINE)

    # ── Staff (held diagonally on the left) ────────────────────────────────────
    d.line([(34, 168), (62, 28)], fill=STAFF_DK, width=8)
    d.line([(34, 168), (62, 28)], fill=STAFF_WD, width=4)
    # Staff orb (glowing crystal)
    d.ellipse([42, 30, 78, 66], fill=ORB, outline=OUTLINE, width=2)
    d.ellipse([48, 36, 60, 48], fill=ORB_HI)
    # Curled gold prongs cradling the orb
    d.arc([38, 26, 82, 70], start=90, end=180, fill=GOLD, width=3)
    d.arc([38, 26, 82, 70], start=0, end=90, fill=GOLD, width=3)

    # ── Hood drapery (covers head, shadowed within) ────────────────────────────
    # Outer hood silhouette
    d.polygon([(76, 60), (60, 110), (132, 110), (116, 60), (96, 50)],
              fill=HOOD, outline=OUTLINE)
    # Inner shadow of hood
    d.polygon([(86, 76), (76, 108), (116, 108), (106, 76), (96, 70)],
              fill=ROBE_LO)
    # Gold trim around hood opening
    d.line([(86, 76), (76, 108)], fill=GOLD, width=2)
    d.line([(106, 76), (116, 108)], fill=GOLD, width=2)

    # ── Face (mostly in shadow under hood) ─────────────────────────────────────
    d.ellipse([85, 80, 107, 104], fill=SKIN_DARK)
    # Glowing eyes peek from shadow
    d.ellipse([88, 88, 94, 94], fill=EYE_GLOW)
    d.ellipse([98, 88, 104, 94], fill=EYE_GLOW)
    d.ellipse([90, 90, 92, 92], fill=OUTLINE)
    d.ellipse([100, 90, 102, 92], fill=OUTLINE)

    # ── Pendant / hex amulet ───────────────────────────────────────────────────
    d.line([(96, 110), (96, 126)], fill=GOLD_DARK, width=1)
    d.polygon([(92, 126), (100, 126), (104, 132), (100, 138), (92, 138), (88, 132)],
              fill=GOLD, outline=OUTLINE)
    d.ellipse([93, 128, 99, 134], fill=ORB)

    # ── Save ───────────────────────────────────────────────────────────────────
    img.save("assets/sprites/ally_lina.png")
    print("Generated ally_lina.png (192x192 — hexweaver ally)")


if __name__ == "__main__":
    gen_marcus()
    gen_lina()
