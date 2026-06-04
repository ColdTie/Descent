#!/usr/bin/env python3
"""Generate the Floor-6 boss sprite: a massive lizard titan.

Two of these spawn on Floor 6 as the only enemies. The art is intentionally
chunky — pixel-style 192×192 with a heavy dark outline so the giant reads as
"boss" even on a busy hex grid.

Output: assets/sprites/enemy_boss_lizard_titan.png
"""

from PIL import Image, ImageDraw
import os

W, H = 192, 192
os.makedirs("assets/sprites", exist_ok=True)

OUTLINE      = (10, 18, 12, 255)
SCALE_MID    = (62, 130, 70, 255)
SCALE_HI     = (110, 188, 96, 255)
SCALE_HI2    = (170, 226, 132, 255)
SCALE_LO     = (28, 78, 44, 255)
BELLY        = (200, 210, 140, 255)
BELLY_LO     = (140, 156, 90, 255)
SPINE        = (240, 220, 90, 255)
SPINE_HI     = (255, 246, 178, 255)
SPINE_LO     = (168, 132, 22, 255)
EYE_RING     = (255, 220, 70, 255)
EYE_BG       = (250, 240, 180, 255)
EYE_SLIT     = (28, 18, 10, 255)
TOOTH        = (240, 232, 218, 255)
CLAW         = (40, 36, 30, 255)
MAW          = (74, 22, 28, 255)
MAW_HI       = (138, 42, 48, 255)


def gen_lizard_titan() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ── Shadow on ground ────────────────────────────────────────────────────
    d.ellipse([34, 170, 158, 186], fill=(8, 6, 12, 150))

    # ── Massive tail curling behind ─────────────────────────────────────────
    tail_pts = [
        (40, 158), (24, 140), (18, 116), (24, 94),
        (44, 84), (62, 96), (66, 122), (58, 148), (50, 160),
    ]
    d.polygon(tail_pts, fill=SCALE_MID, outline=OUTLINE)
    d.polygon([(28, 132), (22, 118), (30, 102), (44, 96), (52, 110), (40, 128)], fill=SCALE_LO)

    # ── Hind legs ───────────────────────────────────────────────────────────
    # Right (viewer left)
    d.polygon([(46, 142), (38, 168), (60, 174), (66, 150)], fill=SCALE_MID, outline=OUTLINE)
    d.polygon([(46, 142), (54, 150), (62, 156), (66, 150)], fill=SCALE_HI)
    # claws right foot
    for cx in (40, 46, 52, 58):
        d.polygon([(cx, 174), (cx - 3, 184), (cx + 3, 184)], fill=CLAW)
    # Left (viewer right)
    d.polygon([(126, 142), (134, 168), (156, 174), (150, 144)], fill=SCALE_MID, outline=OUTLINE)
    d.polygon([(126, 142), (134, 150), (144, 156), (150, 144)], fill=SCALE_HI)
    for cx in (134, 140, 146, 152):
        d.polygon([(cx, 174), (cx - 3, 184), (cx + 3, 184)], fill=CLAW)

    # ── Bulky body ──────────────────────────────────────────────────────────
    body_pts = [
        (54, 108), (44, 134), (52, 158), (96, 168),
        (140, 158), (150, 134), (140, 106), (118, 96), (76, 96),
    ]
    d.polygon(body_pts, fill=SCALE_MID, outline=OUTLINE)
    # belly underside
    belly_pts = [
        (66, 138), (60, 154), (96, 164), (132, 154), (126, 138),
        (110, 148), (82, 148),
    ]
    d.polygon(belly_pts, fill=BELLY, outline=OUTLINE)
    # belly stripes
    for y in (146, 152, 158):
        d.line([(72, y), (120, y)], fill=BELLY_LO, width=1)

    # scale highlights on back
    d.polygon([(80, 100), (74, 116), (96, 122), (118, 116), (112, 100)], fill=SCALE_HI)
    for sx, sy in [(82, 108), (94, 112), (108, 110), (118, 106)]:
        d.ellipse([sx - 3, sy - 2, sx + 3, sy + 2], fill=SCALE_HI2)

    # ── Front legs / arms ───────────────────────────────────────────────────
    d.polygon([(56, 116), (44, 128), (52, 144), (68, 134)], fill=SCALE_MID, outline=OUTLINE)
    d.polygon([(136, 116), (148, 128), (140, 144), (124, 134)], fill=SCALE_MID, outline=OUTLINE)
    for cx in (40, 46, 52):
        d.polygon([(cx, 144), (cx - 3, 152), (cx + 3, 152)], fill=CLAW)
    for cx in (140, 146, 152):
        d.polygon([(cx, 144), (cx - 3, 152), (cx + 3, 152)], fill=CLAW)

    # ── Dorsal spines (yellow row down the back) ────────────────────────────
    spine_xs = [70, 84, 98, 112, 126]
    for sx in spine_xs:
        d.polygon(
            [(sx - 6, 100), (sx + 6, 100), (sx, 78)],
            fill=SPINE,
            outline=OUTLINE,
        )
        d.polygon(
            [(sx - 4, 100), (sx, 86), (sx + 1, 100)],
            fill=SPINE_HI,
        )
        d.polygon(
            [(sx + 1, 100), (sx + 5, 100), (sx + 3, 92)],
            fill=SPINE_LO,
        )

    # ── Massive head ────────────────────────────────────────────────────────
    head_pts = [
        (60, 76), (52, 60), (60, 38), (80, 28),
        (114, 28), (134, 38), (142, 60), (134, 76),
        (124, 90), (70, 90),
    ]
    d.polygon(head_pts, fill=SCALE_MID, outline=OUTLINE)
    # forehead highlight
    d.polygon([(72, 50), (86, 36), (108, 36), (122, 50), (116, 64), (78, 64)], fill=SCALE_HI)
    # jaw
    d.polygon(
        [(64, 76), (130, 76), (122, 96), (98, 102), (74, 96)],
        fill=SCALE_LO, outline=OUTLINE,
    )

    # ── Open maw with teeth ────────────────────────────────────────────────
    d.polygon([(76, 78), (118, 78), (110, 92), (84, 92)], fill=MAW, outline=OUTLINE)
    d.polygon([(82, 80), (112, 80), (108, 86), (86, 86)], fill=MAW_HI)
    # upper teeth
    for tx in (80, 86, 92, 98, 104, 110, 116):
        d.polygon([(tx - 2, 78), (tx + 2, 78), (tx, 84)], fill=TOOTH, outline=OUTLINE)
    # lower teeth
    for tx in (84, 92, 100, 108):
        d.polygon([(tx - 2, 92), (tx + 2, 92), (tx, 86)], fill=TOOTH, outline=OUTLINE)

    # ── Eyes (yellow with vertical slit) ────────────────────────────────────
    for eye_cx in (76, 118):
        d.ellipse([eye_cx - 9, 44, eye_cx + 9, 60], fill=EYE_RING, outline=OUTLINE)
        d.ellipse([eye_cx - 7, 46, eye_cx + 7, 58], fill=EYE_BG)
        d.rectangle([eye_cx - 2, 46, eye_cx + 2, 58], fill=EYE_SLIT)
        # tiny glint
        d.rectangle([eye_cx + 3, 48, eye_cx + 5, 50], fill=(255, 255, 255, 255))

    # ── Nostrils ────────────────────────────────────────────────────────────
    d.ellipse([90, 68, 96, 74], fill=EYE_SLIT)
    d.ellipse([98, 68, 104, 74], fill=EYE_SLIT)

    # ── Horns (small swept-back pair) ───────────────────────────────────────
    d.polygon([(60, 36), (50, 18), (62, 30)], fill=SCALE_LO, outline=OUTLINE)
    d.polygon([(134, 36), (144, 18), (132, 30)], fill=SCALE_LO, outline=OUTLINE)

    img.save("assets/sprites/enemy_boss_lizard_titan.png")
    print("wrote assets/sprites/enemy_boss_lizard_titan.png")


if __name__ == "__main__":
    gen_lizard_titan()
