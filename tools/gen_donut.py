#!/usr/bin/env python3
"""Generate Donut companion sprite — princess cat with tiara and large dark sunglasses.
Based on the DCC book character: orange tabby, gold tiara with jewels, oversized round shades.
Output: assets/sprites/companion_donut.png  (192×192 RGBA)
"""

from PIL import Image, ImageDraw
import math
import os

W, H = 192, 192
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
cx = W // 2  # 96

# ── Palette ────────────────────────────────────────────────────────────────────
FUR        = (220, 128, 38, 255)    # orange tabby base
FUR_BELLY  = (252, 196, 128, 255)   # light chest/face
FUR_STRIPE = (155, 80, 18, 255)     # dark tabby stripe
OUTLINE    = (38, 18, 4, 255)       # dark outline
GLASS_LENS = (12, 12, 12, 225)      # very dark sunglass lens
GLASS_FRAME= (58, 38, 12, 255)      # dark-gold frame
SHINE      = (255, 255, 255, 160)   # lens highlight
GOLD       = (248, 196, 32, 255)    # tiara gold
GOLD_DARK  = (180, 130, 10, 255)    # tiara shadow
JEWEL_P    = (165, 38, 195, 255)    # purple jewel (center)
JEWEL_R    = (200, 28, 48, 255)     # red jewel (sides)
NOSE       = (218, 108, 128, 255)   # pink nose
WHISKER    = (210, 188, 165, 170)   # whiskers
COLLAR     = (178, 28, 55, 255)     # red collar
BELL_GOLD  = (248, 200, 35, 255)    # gold bell

# ── Body ───────────────────────────────────────────────────────────────────────
# Plump seated body
d.ellipse([42, 98, 150, 180], fill=FUR, outline=OUTLINE, width=2)
# Belly patch
d.ellipse([60, 116, 132, 172], fill=FUR_BELLY)
# Body tabby stripes
for ys in [124, 137, 150]:
    d.arc([62, ys, 130, ys + 9], start=20, end=160, fill=FUR_STRIPE, width=2)

# ── Tail ───────────────────────────────────────────────────────────────────────
pts = []
for t in range(22):
    angle = math.pi * 0.6 + t * 0.14
    r = 22 + t * 1.1
    tx = cx + 52 + int(r * math.cos(angle))
    ty = 138 + int(r * math.sin(angle) * 0.55) - t * 2
    pts.append((tx, ty))
if len(pts) > 1:
    d.line(pts, fill=FUR, width=11)
    d.line(pts, fill=OUTLINE, width=2)
# Tail tip
d.ellipse([136, 113, 158, 133], fill=FUR_BELLY, outline=OUTLINE, width=2)

# ── Head ───────────────────────────────────────────────────────────────────────
hx, hy, hr = cx, 70, 37
d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=FUR, outline=OUTLINE, width=2)
# Forehead highlight
d.ellipse([hx - 21, hy - 29, hx + 21, hy + 6], fill=FUR_BELLY)
# Head stripes
for xo in [-16, -4, 8]:
    d.line([(hx + xo, hy - 34), (hx + int(xo * 0.65), hy - 9)], fill=FUR_STRIPE, width=2)

# ── Ears ───────────────────────────────────────────────────────────────────────
# Left ear
d.polygon([(55, 40), (41, 14), (70, 30)], fill=FUR, outline=OUTLINE)
d.polygon([(57, 36), (47, 18), (66, 28)], fill=FUR_BELLY)
# Right ear
d.polygon([(137, 40), (151, 14), (122, 30)], fill=FUR, outline=OUTLINE)
d.polygon([(135, 36), (145, 18), (126, 28)], fill=FUR_BELLY)

# ── Tiara ─────────────────────────────────────────────────────────────────────
ty0 = hy - hr + 5
# Base band arc
d.arc([hx - 32, ty0 - 5, hx + 32, ty0 + 9], start=198, end=342, fill=GOLD, width=5)
d.arc([hx - 32, ty0 - 5, hx + 32, ty0 + 9], start=198, end=342, fill=GOLD_DARK, width=2)
# Center tall spike
c_spike = [(hx - 5, ty0 + 2), (hx + 5, ty0 + 2),
           (hx + 3, ty0 - 17), (hx, ty0 - 24), (hx - 3, ty0 - 17)]
d.polygon(c_spike, fill=GOLD, outline=OUTLINE, width=1)
# Side spikes
d.polygon([(hx - 23, ty0 + 2), (hx - 13, ty0 + 2), (hx - 18, ty0 - 12)],
          fill=GOLD, outline=OUTLINE, width=1)
d.polygon([(hx + 23, ty0 + 2), (hx + 13, ty0 + 2), (hx + 18, ty0 - 12)],
          fill=GOLD, outline=OUTLINE, width=1)
# Jewels
d.ellipse([hx - 5, ty0 - 27, hx + 5, ty0 - 14], fill=JEWEL_P, outline=OUTLINE, width=1)
d.ellipse([hx - 26, ty0 - 11, hx - 14, ty0], fill=JEWEL_R, outline=OUTLINE, width=1)
d.ellipse([hx + 14, ty0 - 11, hx + 26, ty0], fill=JEWEL_R, outline=OUTLINE, width=1)

# ── Big circular sunglasses ────────────────────────────────────────────────────
# This is Donut's most distinctive feature — oversized round dark shades
eye_cy = hy + 4
gr = 18  # large radius for that princess-cat look
lx = hx - 20
rx = hx + 20

# Left lens
d.ellipse([lx - gr, eye_cy - gr, lx + gr, eye_cy + gr],
          fill=GLASS_LENS, outline=GLASS_FRAME, width=3)
# Left lens shine
d.ellipse([lx - gr + 3, eye_cy - gr + 3, lx - gr + 10, eye_cy - gr + 10], fill=SHINE)

# Right lens
d.ellipse([rx - gr, eye_cy - gr, rx + gr, eye_cy + gr],
          fill=GLASS_LENS, outline=GLASS_FRAME, width=3)
# Right lens shine
d.ellipse([rx - gr + 3, eye_cy - gr + 3, rx - gr + 10, eye_cy - gr + 10], fill=SHINE)

# Bridge connecting the two lenses
d.line([(lx + gr, eye_cy), (rx - gr, eye_cy)], fill=GLASS_FRAME, width=3)

# Temple arms going behind ears
d.line([(lx - gr, eye_cy - 2), (lx - gr - 16, eye_cy - 7)], fill=GLASS_FRAME, width=3)
d.line([(rx + gr, eye_cy - 2), (rx + gr + 16, eye_cy - 7)], fill=GLASS_FRAME, width=3)

# ── Nose ─────────────────────────────────────────────────────────────────────
nose_y = eye_cy + gr + 4
d.polygon([(hx, nose_y + 5), (hx - 5, nose_y), (hx + 5, nose_y)],
          fill=NOSE, outline=OUTLINE, width=1)
# Mouth
d.arc([hx - 7, nose_y + 2, hx + 7, nose_y + 11], start=5, end=175, fill=OUTLINE, width=2)

# ── Whiskers ──────────────────────────────────────────────────────────────────
for x1, x2 in [(hx - 44, hx - 12), (hx + 12, hx + 44)]:
    for yo in [-3, 2]:
        d.line([(x1, nose_y + yo), (x2, nose_y + yo)], fill=WHISKER, width=1)

# ── Collar ────────────────────────────────────────────────────────────────────
col_y = hy + hr - 3
d.arc([hx - 32, col_y - 5, hx + 32, col_y + 8], start=28, end=152, fill=COLLAR, width=7)
# Gold bell
d.ellipse([hx - 6, col_y + 4, hx + 6, col_y + 15], fill=BELL_GOLD, outline=OUTLINE, width=1)
d.line([(hx, col_y + 8), (hx, col_y + 13)], fill=OUTLINE, width=1)

# ── Front paws ────────────────────────────────────────────────────────────────
d.ellipse([53, 166, 78, 181], fill=FUR, outline=OUTLINE, width=2)
d.ellipse([114, 166, 139, 181], fill=FUR, outline=OUTLINE, width=2)
for pc in [65, 126]:
    for tx in [-4, 0, 4]:
        d.line([(pc + tx, 173), (pc + tx, 179)], fill=OUTLINE, width=1)

# ── Save ──────────────────────────────────────────────────────────────────────
os.makedirs("assets/sprites", exist_ok=True)
img.save("assets/sprites/companion_donut.png")
print("Generated companion_donut.png (192x192 — princess cat with tiara and shades)")
