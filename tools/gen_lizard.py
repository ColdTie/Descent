#!/usr/bin/env python3
"""Generate the Floor-6 boss sprite: a lean, predatory lizard raptor.

Two of these spawn on Floor 6 as the only enemies. Re-design: lean upright
raptor silhouette, glowing cyan eye, segmented blue-scale belly, sweeping
tail, sickle claws. Reads as "fast hunter," not the chubby cartoon frog
the first pass produced.

Output: assets/sprites/enemy_boss_lizard_titan.png  (192x192 RGBA)
"""

from PIL import Image, ImageDraw
import os

W, H = 192, 192
os.makedirs("assets/sprites", exist_ok=True)

OUTLINE     = (12, 18, 14, 255)
SHADOW_DK   = (8, 10, 14, 220)

# Body — deep emerald / forest scales
SCALE_DK    = (24, 58, 38, 255)
SCALE_MID   = (52, 110, 70, 255)
SCALE_HI    = (96, 168, 108, 255)
SCALE_HI2   = (160, 220, 150, 255)

# Belly + throat — pale cyan undersides (gives the blue HP-bar outline
# a visual partner on the sprite itself)
BELLY_DK    = (66, 112, 132, 255)
BELLY_MID   = (108, 168, 188, 255)
BELLY_HI    = (172, 218, 230, 255)

# Dorsal crest spines / claws / horns
CREST_DK    = (78, 22, 26, 255)
CREST_MID   = (148, 42, 50, 255)
CREST_HI    = (224, 96, 88, 255)
CLAW_BLK    = (22, 18, 22, 255)
CLAW_HI     = (170, 168, 180, 255)
TOOTH       = (240, 232, 218, 255)

# Eye — cyan with vertical slit
EYE_GLOW    = (88, 220, 240, 255)
EYE_HI      = (220, 248, 252, 255)
EYE_SLIT    = (10, 14, 22, 255)
MAW         = (54, 16, 22, 255)
MAW_HI      = (118, 38, 44, 255)


def gen_lizard_titan() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ── Ground shadow ──────────────────────────────────────────────────────
    d.ellipse([54, 168, 142, 184], fill=SHADOW_DK)

    # ── Tail: sweeps from behind the body out to the upper-right ──────────
    tail_pts = [
        (118, 110), (148, 96), (170, 72), (174, 50),
        (160, 56), (152, 80), (130, 100), (114, 122),
    ]
    d.polygon(tail_pts, fill=SCALE_MID, outline=OUTLINE)
    # tail underside (lighter ridge)
    d.polygon(
        [(150, 88), (164, 70), (170, 54), (164, 56), (152, 80), (140, 96)],
        fill=SCALE_DK,
    )
    # tail crest spines
    for tx, ty in [(150, 78), (158, 66), (164, 56)]:
        d.polygon([(tx - 4, ty), (tx + 4, ty), (tx + 1, ty - 8)], fill=CREST_MID, outline=OUTLINE)

    # ── Hind legs (powerful, drawn-up raptor pose) ────────────────────────
    # Thigh (right-side viewer-left)
    d.polygon(
        [(56, 108), (44, 140), (60, 170), (90, 168), (88, 130)],
        fill=SCALE_MID, outline=OUTLINE,
    )
    # Highlights
    d.polygon([(58, 116), (52, 138), (66, 146), (78, 134)], fill=SCALE_HI)
    # Shin
    d.polygon([(60, 158), (54, 172), (80, 176), (84, 158)], fill=SCALE_DK, outline=OUTLINE)
    # Foot toes (3 forward sickle claws)
    for cx in (58, 68, 80):
        d.polygon(
            [(cx - 4, 176), (cx + 4, 176), (cx + 2, 188), (cx - 2, 188)],
            fill=SCALE_DK, outline=OUTLINE,
        )
        # claw tip
        d.polygon([(cx + 1, 188), (cx + 5, 188), (cx + 6, 184)], fill=CLAW_BLK)

    # Second leg behind
    d.polygon(
        [(96, 110), (88, 140), (104, 168), (124, 162), (122, 124)],
        fill=SCALE_DK, outline=OUTLINE,
    )
    d.polygon([(100, 158), (96, 172), (118, 174), (120, 158)], fill=SCALE_DK, outline=OUTLINE)
    for cx in (98, 108, 118):
        d.polygon(
            [(cx - 3, 174), (cx + 3, 174), (cx + 1, 184), (cx - 1, 184)],
            fill=CLAW_BLK,
        )

    # ── Torso: lean, slightly forward-leaning ─────────────────────────────
    body_pts = [
        (60, 86), (54, 116), (66, 136), (94, 140),
        (118, 130), (124, 108), (118, 86), (96, 76), (74, 78),
    ]
    d.polygon(body_pts, fill=SCALE_MID, outline=OUTLINE)
    # Back highlights along the upper edge
    d.polygon(
        [(72, 84), (88, 78), (110, 82), (118, 92), (108, 96), (84, 92)],
        fill=SCALE_HI,
    )
    # Scale flecks
    for sx, sy in [(78, 88), (94, 86), (108, 90), (96, 102), (86, 108)]:
        d.ellipse([sx - 2, sy - 2, sx + 2, sy + 2], fill=SCALE_HI2)

    # Belly plates (pale cyan, paired with the blue HP-bar frame)
    belly_pts = [
        (74, 116), (66, 132), (90, 138), (114, 130), (114, 116),
    ]
    d.polygon(belly_pts, fill=BELLY_MID, outline=OUTLINE)
    # belly highlight
    d.polygon([(80, 118), (76, 130), (92, 134), (108, 128), (108, 118)], fill=BELLY_HI)
    # plate stripes
    for y in (122, 128, 134):
        d.line([(78, y), (110, y)], fill=BELLY_DK, width=1)

    # Throat patch (lighter blue tucked under jaw)
    d.polygon([(78, 78), (86, 88), (104, 88), (110, 78), (96, 74)], fill=BELLY_MID, outline=OUTLINE)
    d.polygon([(82, 80), (90, 86), (102, 86), (106, 80)], fill=BELLY_HI)

    # ── Dorsal crest: tall red spines down the back ───────────────────────
    crest_spine_xs = [(72, 76), (84, 70), (96, 66), (108, 70), (118, 78)]
    for cx, cy in crest_spine_xs:
        d.polygon(
            [(cx - 5, cy + 6), (cx + 5, cy + 6), (cx, cy - 12)],
            fill=CREST_MID, outline=OUTLINE,
        )
        d.polygon([(cx - 3, cy + 4), (cx, cy - 8), (cx + 1, cy + 4)], fill=CREST_HI)
        d.polygon([(cx + 1, cy + 4), (cx + 4, cy + 4), (cx + 3, cy - 2)], fill=CREST_DK)

    # ── Forelegs (small, raptor-style) ────────────────────────────────────
    # Right (viewer-left) arm reaching forward
    d.polygon([(54, 110), (44, 128), (52, 138), (66, 124)], fill=SCALE_DK, outline=OUTLINE)
    # claws on right arm
    for cx, cy in [(42, 132), (44, 138), (48, 142)]:
        d.polygon([(cx, cy), (cx - 3, cy + 6), (cx + 2, cy + 4)], fill=CLAW_BLK)
    # Left arm
    d.polygon([(122, 110), (132, 124), (124, 138), (110, 126)], fill=SCALE_DK, outline=OUTLINE)
    for cx, cy in [(134, 130), (132, 138), (128, 142)]:
        d.polygon([(cx, cy), (cx + 3, cy + 6), (cx - 2, cy + 4)], fill=CLAW_BLK)

    # ── Head: angular raptor skull, slight forward jut ────────────────────
    head_pts = [
        (72, 74), (66, 56), (76, 36), (96, 28), (118, 36),
        (128, 56), (124, 74), (108, 80), (88, 80),
    ]
    d.polygon(head_pts, fill=SCALE_MID, outline=OUTLINE)
    # snout block
    d.polygon([(86, 74), (84, 86), (112, 86), (112, 74)], fill=SCALE_MID, outline=OUTLINE)
    # upper-snout highlight
    d.polygon([(88, 76), (98, 74), (108, 76), (106, 80), (90, 80)], fill=SCALE_HI)
    # crown highlight
    d.polygon([(80, 50), (98, 38), (114, 50), (108, 60), (84, 60)], fill=SCALE_HI)

    # Jaw plate (lower)
    d.polygon([(86, 86), (88, 96), (108, 96), (112, 86)], fill=SCALE_DK, outline=OUTLINE)

    # ── Open maw + teeth ──────────────────────────────────────────────────
    d.polygon([(90, 86), (108, 86), (104, 94), (94, 94)], fill=MAW, outline=OUTLINE)
    d.polygon([(92, 87), (106, 87), (102, 91), (96, 91)], fill=MAW_HI)
    # upper teeth (sharp)
    for tx in (90, 95, 99, 103, 108):
        d.polygon([(tx - 2, 86), (tx + 2, 86), (tx, 91)], fill=TOOTH, outline=OUTLINE)
    # lower fangs
    for tx in (93, 105):
        d.polygon([(tx - 2, 94), (tx + 2, 94), (tx, 88)], fill=TOOTH, outline=OUTLINE)

    # ── Eye: single cyan glow w/ vertical slit (forward-facing predator) ─
    for ecx in (84, 110):
        # socket shadow
        d.polygon(
            [(ecx - 10, 46), (ecx - 4, 40), (ecx + 6, 42), (ecx + 8, 52), (ecx - 2, 56)],
            fill=SCALE_DK, outline=OUTLINE,
        )
        # eye orb
        d.ellipse([ecx - 6, 44, ecx + 6, 56], fill=EYE_GLOW, outline=OUTLINE)
        d.ellipse([ecx - 4, 46, ecx + 4, 54], fill=EYE_HI)
        d.rectangle([ecx - 1, 45, ecx + 1, 55], fill=EYE_SLIT)
        # glint
        d.rectangle([ecx + 2, 47, ecx + 3, 49], fill=(255, 255, 255, 255))

    # Nostril
    d.ellipse([94, 76, 100, 80], fill=EYE_SLIT)
    d.ellipse([103, 76, 109, 80], fill=EYE_SLIT)

    # ── Head crest: backward-swept horns ──────────────────────────────────
    d.polygon([(66, 40), (52, 22), (62, 32), (74, 44)], fill=SCALE_DK, outline=OUTLINE)
    d.polygon([(128, 40), (142, 22), (132, 32), (120, 44)], fill=SCALE_DK, outline=OUTLINE)
    # smaller central horn
    d.polygon([(94, 30), (88, 16), (104, 16), (100, 30)], fill=SCALE_DK, outline=OUTLINE)

    img.save("assets/sprites/enemy_boss_lizard_titan.png")
    print("wrote assets/sprites/enemy_boss_lizard_titan.png")


if __name__ == "__main__":
    gen_lizard_titan()
