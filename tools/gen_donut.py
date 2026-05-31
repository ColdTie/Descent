#!/usr/bin/env python3
"""Generate Donut companion sprite — princess cat with tiara and big dark sunglasses.
Based on the DCC character: orange tabby, gold tiara, oversized round shades, red collar + bell.
Clean, compact, clearly-a-cat seated silhouette centered in the canvas.
Output: assets/sprites/companion_donut.png  (192×192 RGBA)
"""

from PIL import Image, ImageDraw
import os

W, H = 192, 192
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
cx = W // 2  # 96

# ── Palette ────────────────────────────────────────────────────────────────────
FUR        = (224, 132, 42, 255)    # orange tabby base
FUR_LIGHT  = (250, 198, 132, 255)   # light chest/face/muzzle
FUR_STRIPE = (158, 82, 20, 255)     # dark tabby stripe
OUTLINE    = (40, 20, 6, 255)       # dark outline
EAR_INNER  = (236, 158, 150, 255)   # pink inner ear
GLASS_LENS = (16, 16, 18, 235)      # very dark sunglass lens
GLASS_FRAME= (60, 40, 14, 255)      # dark-gold frame
SHINE      = (255, 255, 255, 170)   # lens highlight
GOLD       = (250, 200, 36, 255)    # tiara gold
JEWEL_P    = (170, 42, 200, 255)    # purple jewel (center)
JEWEL_R    = (205, 32, 52, 255)     # red jewel (sides)
NOSE       = (222, 112, 132, 255)   # pink nose
COLLAR     = (182, 30, 58, 255)     # red collar
BELL_GOLD  = (250, 204, 40, 255)    # gold bell

# A clean seated cat: compact teardrop body, round head, two ears, curled tail.
# Everything kept centered and within a tidy footprint so the silhouette reads.

# ── Curled tail (drawn first, behind body) ──────────────────────────────────────
d.ellipse([118, 116, 162, 158], outline=FUR, width=12)        # curl
d.ellipse([118, 116, 162, 158], outline=OUTLINE, width=2)
d.ellipse([148, 138, 164, 154], fill=FUR_LIGHT, outline=OUTLINE, width=2)  # tail tip

# ── Body (compact seated teardrop) ──────────────────────────────────────────────
d.ellipse([62, 96, 130, 162], fill=FUR, outline=OUTLINE, width=2)
# Chest/belly patch
d.ellipse([76, 108, 116, 156], fill=FUR_LIGHT)
# A couple of subtle body stripes
for ys in [118, 130]:
    d.arc([78, ys, 114, ys + 10], start=20, end=160, fill=FUR_STRIPE, width=2)

# ── Front paws ──────────────────────────────────────────────────────────────────
d.ellipse([78, 150, 96, 164], fill=FUR_LIGHT, outline=OUTLINE, width=2)
d.ellipse([100, 150, 118, 164], fill=FUR_LIGHT, outline=OUTLINE, width=2)
for pc in [87, 109]:
    for tx in [-3, 0, 3]:
        d.line([(pc + tx, 156), (pc + tx, 162)], fill=OUTLINE, width=1)

# ── Ears (clear triangles) ──────────────────────────────────────────────────────
# Left
d.polygon([(66, 70), (60, 40), (86, 60)], fill=FUR, outline=OUTLINE)
d.polygon([(70, 64), (66, 47), (82, 59)], fill=EAR_INNER)
# Right
d.polygon([(126, 70), (132, 40), (106, 60)], fill=FUR, outline=OUTLINE)
d.polygon([(122, 64), (126, 47), (110, 59)], fill=EAR_INNER)

# ── Head (round, slightly wider than tall) ──────────────────────────────────────
hx, hy = cx, 70
hw, hh = 34, 30   # half-width, half-height
d.ellipse([hx - hw, hy - hh, hx + hw, hy + hh], fill=FUR, outline=OUTLINE, width=2)
# Light muzzle/lower face
d.ellipse([hx - 22, hy - 6, hx + 22, hy + hh - 2], fill=FUR_LIGHT)
# Forehead stripes
for xo in [-12, 0, 12]:
    d.line([(hx + xo, hy - hh + 4), (hx + int(xo * 0.6), hy - 10)], fill=FUR_STRIPE, width=2)

# ── Tiara ─────────────────────────────────────────────────────────────────────
ty0 = hy - hh + 6
d.arc([hx - 24, ty0 - 4, hx + 24, ty0 + 8], start=200, end=340, fill=GOLD, width=4)
# Center spike + jewel
d.polygon([(hx - 4, ty0), (hx + 4, ty0), (hx, ty0 - 16)], fill=GOLD, outline=OUTLINE, width=1)
d.ellipse([hx - 4, ty0 - 18, hx + 4, ty0 - 10], fill=JEWEL_P, outline=OUTLINE, width=1)
# Side spikes + jewels
for sx in [-16, 16]:
    d.polygon([(hx + sx - 4, ty0), (hx + sx + 4, ty0), (hx + sx, ty0 - 10)],
              fill=GOLD, outline=OUTLINE, width=1)
    d.ellipse([hx + sx - 4, ty0 - 9, hx + sx + 4, ty0 - 1], fill=JEWEL_R, outline=OUTLINE, width=1)

# ── Big round sunglasses (signature feature) ────────────────────────────────────
eye_cy = hy + 2
gr = 15
lx, rx = hx - 16, hx + 16
for ex in [lx, rx]:
    d.ellipse([ex - gr, eye_cy - gr, ex + gr, eye_cy + gr],
              fill=GLASS_LENS, outline=GLASS_FRAME, width=3)
    d.ellipse([ex - gr + 3, eye_cy - gr + 3, ex - gr + 9, eye_cy - gr + 9], fill=SHINE)
# Bridge + temple arms
d.line([(lx + gr, eye_cy), (rx - gr, eye_cy)], fill=GLASS_FRAME, width=3)
d.line([(lx - gr, eye_cy - 2), (lx - gr - 12, eye_cy - 6)], fill=GLASS_FRAME, width=3)
d.line([(rx + gr, eye_cy - 2), (rx + gr + 12, eye_cy - 6)], fill=GLASS_FRAME, width=3)

# ── Nose + mouth ────────────────────────────────────────────────────────────────
nose_y = eye_cy + gr + 3
d.polygon([(hx, nose_y + 4), (hx - 4, nose_y), (hx + 4, nose_y)],
          fill=NOSE, outline=OUTLINE, width=1)
d.arc([hx - 6, nose_y + 1, hx + 6, nose_y + 9], start=10, end=170, fill=OUTLINE, width=2)

# ── Collar + bell ───────────────────────────────────────────────────────────────
col_y = hy + hh - 2
d.arc([hx - 26, col_y - 4, hx + 26, col_y + 8], start=30, end=150, fill=COLLAR, width=6)
d.ellipse([hx - 5, col_y + 4, hx + 5, col_y + 14], fill=BELL_GOLD, outline=OUTLINE, width=1)
d.line([(hx, col_y + 7), (hx, col_y + 12)], fill=OUTLINE, width=1)

# ── Save ──────────────────────────────────────────────────────────────────────
os.makedirs("assets/sprites", exist_ok=True)
img.save("assets/sprites/companion_donut.png")
print("Generated companion_donut.png (192x192 — clean compact princess cat)")
