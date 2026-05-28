#!/usr/bin/env python3
"""Generate pixel-art PNG sprites for DESCENT characters.

80×80 canvas with automatic dark outlines for crisp, readable sprites.
Unique boss sprites for each of the 3 boss tiers.
"""

import os
import struct
import zlib

SIZE = 80

def rgb(r, g, b):   return (r, g, b, 255)
def rgba(r, g, b, a): return (r, g, b, a)
TRANS = (0, 0, 0, 0)


class Canvas:
    def __init__(self, w=SIZE, h=SIZE):
        self.w, self.h = w, h
        self.pixels = [TRANS] * (w * h)

    def _set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.pixels[y * self.w + x] = c

    def rect(self, x, y, w, h, c):
        for dy in range(h):
            for dx in range(w):
                self._set(x + dx, y + dy, c)

    def circle(self, cx, cy, r, c):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    self._set(cx + dx, cy + dy, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for dy in range(-ry, ry + 1):
            for dx in range(-rx, rx + 1):
                if dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry:
                    self._set(cx + dx, cy + dy, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            self._set(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy; x0 += sx
            if e2 < dx:
                err += dx; y0 += sy

    def outline(self):
        """Trace every opaque pixel edge and paint adjacent transparent pixels dark.
        This single pass gives every sprite a crisp, readable silhouette."""
        BORDER = (8, 5, 14, 255)   # near-black with a hint of purple
        new_pix = list(self.pixels)
        for y in range(self.h):
            for x in range(self.w):
                if self.pixels[y * self.w + x][3] >= 80:   # solid enough
                    for ny in range(max(0, y - 1), min(self.h, y + 2)):
                        for nx in range(max(0, x - 1), min(self.w, x + 2)):
                            if self.pixels[ny * self.w + nx][3] < 30:   # transparent
                                new_pix[ny * self.w + nx] = BORDER
        self.pixels = new_pix

    def save(self, path):
        def chunk(name, data):
            crc = zlib.crc32(name + data) & 0xFFFFFFFF
            return struct.pack('>I', len(data)) + name + data + struct.pack('>I', crc)

        raw = b''
        for y in range(self.h):
            raw += b'\x00'
            for x in range(self.w):
                raw += bytes(self.pixels[y * self.w + x])

        sig = b'\x89PNG\r\n\x1a\n'
        ihdr = chunk(b'IHDR', struct.pack('>II', self.w, self.h) + bytes([8, 6, 0, 0, 0]))
        idat = chunk(b'IDAT', zlib.compress(raw, 9))
        iend = chunk(b'IEND', b'')
        with open(path, 'wb') as f:
            f.write(sig + ihdr + idat + iend)


# ─── Color palettes ───────────────────────────────────────────────────────────
# Each character has its own named palette for easy maintenance.

# Skin tones
SKIN      = rgb(178, 142, 100)
SKIN_LIT  = rgb(205, 170, 128)
SKIN_SHD  = rgb(148, 114, 78)

# Hero Brawler — blue plate, gold trim
BW_ARMOR  = rgb(68,  82,  145)
BW_LIT    = rgb(112, 132, 200)
BW_SHD    = rgb(45,  55,  100)
BW_GOLD   = rgb(218, 188, 55)
BW_GOLD_D = rgb(155, 132, 30)
BW_PANTS  = rgb(35,  42,  78)
BW_BOOT   = rgb(52,  40,  26)
BW_EYE    = rgb(255, 160, 10)   # orange glow
BW_EYE_B  = rgb(255, 235, 160)  # bright spot

# Hero Rogue — dark violet + teal eyes
RG_DARK   = rgb(28,  18,  48)
RG_MID    = rgb(45,  32,  72)
RG_BELT   = rgb(78,  55,  30)
RG_BLADE  = rgb(208, 210, 228)
RG_BLADE2 = rgb(160, 162, 180)
RG_EYE    = rgb(0,   210, 185)  # teal glow
RG_EYE_B  = rgb(180, 255, 245)  # teal bright

# Hero Arcanist — deep purple + violet magic
ARC_ROBE  = rgb(58,  35,  115)
ARC_LIT   = rgb(95,  62,  175)
ARC_SHD   = rgb(38,  22,  75)
ARC_GOLD  = rgb(202, 172, 48)
ARC_MAG   = rgb(185, 80,  255)  # magic purple
ARC_MAG2  = rgb(220, 140, 255)  # bright magic
ARC_BEARD = rgb(202, 196, 185)

# Enemy Imp — orange-red with yellow eyes
IMP_BODY  = rgb(200, 65,  28)
IMP_LIT   = rgb(235, 105, 60)
IMP_SHD   = rgb(135, 30,  10)
IMP_WING  = rgba(160, 30,  10,  185)
IMP_EYE   = rgb(255, 225, 0)
IMP_CLAW  = rgb(228, 200, 155)

# Enemy Goblin — green skin with brown gear
GOB_SKIN  = rgb(88,  118, 62)
GOB_LIT   = rgb(112, 148, 80)
GOB_SHD   = rgb(62,  85,  42)
GOB_GEAR  = rgb(88,  64,  40)
GOB_EYE   = rgb(255, 195, 10)

# Enemy Skeleton — bone with blue eye glow
SKL_BONE  = rgb(228, 220, 200)
SKL_SHD   = rgb(168, 160, 142)
SKL_JOINT = rgb(195, 188, 168)
SKL_SWORD = rgb(188, 188, 210)
SKL_EYE   = rgb(60,  100, 255)  # cold blue glow
SKL_EYE_B = rgb(160, 200, 255)

# Enemy Demon — dark crimson + fire
DEM_BODY  = rgb(118, 18,  8)
DEM_LIT   = rgb(165, 45,  25)
DEM_SHD   = rgb(78,  10,  4)
DEM_WING  = rgba(75,  8,   2,   200)
DEM_FIRE  = rgb(255, 115, 0)
DEM_EYE   = rgb(255, 95,  0)
DEM_EYE_B = rgb(255, 240, 100)

# Enemy Golem — gray stone + lava cracks
GLM_STONE = rgb(72,  58,  45)
GLM_LIT   = rgb(102, 84,  65)
GLM_SHD   = rgb(50,  40,  30)
GLM_LAVA  = rgb(255, 82,  0)
GLM_LAVA2 = rgb(255, 155, 0)   # brighter lava glow

# Boss Dungeon Lord — black gold armor + crimson eyes
DL_ARMOR  = rgb(28,  24,  50)
DL_LIT    = rgb(75,  68,  115)
DL_GOLD   = rgb(222, 190, 55)
DL_GOLD_D = rgb(158, 132, 30)
DL_CAPE   = rgb(148, 18,  18)
DL_SWORD  = rgb(195, 198, 220)
DL_EYE    = rgb(255, 38,  18)   # crimson eyes

# Boss Warden — mossy stone + green rune glow
WD_STONE  = rgb(46,  58,  50)
WD_LIT    = rgb(72,  90,  78)
WD_SHD    = rgb(30,  38,  32)
WD_RUNE   = rgb(60,  210, 85)   # green rune glow
WD_RUNE_B = rgb(160, 255, 180)  # bright glow
WD_CHAIN  = rgb(120, 100, 78)

# Boss Abyss Keeper — void black + purple
AK_ROBE   = rgb(15,  8,   30)
AK_ROBE2  = rgb(28,  15,  52)
AK_VOID   = rgb(175, 0,   255)  # void purple
AK_VOID_B = rgb(218, 128, 255)  # bright void
AK_SKULL  = rgb(222, 216, 200)
AK_SKULL2 = rgb(178, 170, 155)
AK_CROWN  = rgb(172, 145, 28)


# ─── Hero Sprites ─────────────────────────────────────────────────────────────

def hero_brawler():
    """Carl as Brawler — blue plate armor, gold chest cross, orange-glow eyes."""
    c = Canvas()
    # ground shadow
    c.ellipse(40, 76, 20, 4, rgba(0, 0, 0, 75))

    # === BOOTS ===
    c.rect(23, 67, 15, 9, BW_BOOT)
    c.rect(42, 67, 15, 9, BW_BOOT)
    c.rect(23, 67, 15, 2, rgb(82, 65, 42))   # boot top highlight

    # === LEGS — armored greaves ===
    c.rect(25, 54, 13, 15, BW_ARMOR)
    c.rect(42, 54, 13, 15, BW_ARMOR)
    c.rect(25, 54, 4,  15, BW_LIT)           # left-face shine
    c.rect(50, 54, 4,  15, BW_SHD)           # right-face shadow
    c.rect(42, 54, 4,  15, BW_LIT)
    c.rect(50, 54, 5,  15, BW_SHD)
    # knee cap
    c.rect(24, 59, 15, 6,  BW_SHD)
    c.rect(41, 59, 15, 6,  BW_SHD)
    c.rect(25, 60, 6,  4,  BW_LIT)
    c.rect(42, 60, 6,  4,  BW_LIT)

    # === BELT ===
    c.rect(21, 52, 38, 5, BW_BOOT)           # strap
    c.rect(37, 51, 6,  6, BW_GOLD)           # buckle
    c.rect(38, 52, 4,  4, BW_GOLD_D)         # buckle detail

    # === TORSO — heavy plate ===
    c.rect(19, 28, 42, 26, BW_ARMOR)         # main body
    c.rect(19, 28, 42, 4,  BW_LIT)           # top highlight
    c.rect(19, 28, 4,  26, BW_LIT)           # left highlight
    c.rect(54, 34, 7,  20, BW_SHD)           # right shadow
    c.rect(19, 48, 42, 6,  BW_SHD)           # bottom shadow
    # chest cross emblem (gold bars + dark fill + center gem)
    c.rect(36, 30, 8,  22, BW_GOLD)          # vertical gold bar
    c.rect(24, 38, 32, 7,  BW_GOLD)          # horizontal gold bar
    c.rect(37, 31, 6,  20, BW_ARMOR)         # dark fill v
    c.rect(25, 39, 30, 5,  BW_ARMOR)         # dark fill h
    c.circle(40, 42, 5, BW_GOLD)             # center gem
    c.circle(40, 42, 3, rgb(255, 235, 120))  # gem shine

    # === ARMS — raised and armored ===
    # left arm
    c.rect(5,  26, 15, 26, BW_ARMOR)
    c.rect(5,  26, 4,  26, BW_LIT)
    c.rect(16, 30, 4,  22, BW_SHD)
    # right arm
    c.rect(60, 26, 15, 26, BW_ARMOR)
    c.rect(71, 30, 4,  22, BW_SHD)

    # gauntlets (dark blue fists)
    c.rect(3,  50, 18, 14, BW_SHD)
    c.rect(3,  50, 6,  14, BW_ARMOR)         # gauntlet front face
    c.rect(59, 50, 18, 14, BW_SHD)
    c.rect(70, 50, 6,  14, BW_ARMOR)
    # knuckle ridges
    for i in range(3):
        c.rect(4,  52 + i * 4, 16, 2, BW_ARMOR)
        c.rect(60, 52 + i * 4, 16, 2, BW_ARMOR)

    # === NECK ===
    c.rect(32, 21, 16, 9, SKIN)
    c.rect(32, 21, 4,  9, SKIN_LIT)          # neck highlight

    # === HEAD — face visible below helmet brim ===
    c.rect(26, 9,  28, 16, SKIN)
    c.rect(26, 9,  5,  16, SKIN_LIT)         # left-face light
    c.rect(48, 12, 6,  13, SKIN_SHD)         # right-face shadow
    c.rect(27, 22, 26, 3,  SKIN_SHD)         # chin shadow

    # === HELMET ===
    c.rect(21, 3,  38, 18, BW_ARMOR)         # main helmet
    c.rect(21, 3,  38, 4,  BW_LIT)           # top shine
    c.rect(21, 3,  5,  18, BW_LIT)           # left shine
    c.rect(54, 7,  5,  14, BW_SHD)           # right shadow
    # cheek guards
    c.rect(21, 11, 7,  11, BW_SHD)
    c.rect(52, 11, 7,  11, BW_SHD)
    # top crest (gold)
    c.rect(36, 3,  8,  6,  BW_GOLD)
    c.rect(37, 0,  6,  5,  BW_GOLD)
    c.rect(38, 0,  4,  2,  rgb(255, 240, 140))

    # visor slit + glowing eyes
    c.rect(24, 12, 32, 8,  rgb(18, 14, 32))  # dark visor zone
    c.rect(26, 13, 12, 6,  rgb(0,  0,  0))   # left socket
    c.rect(42, 13, 12, 6,  rgb(0,  0,  0))   # right socket
    c.rect(27, 13, 10, 6,  BW_EYE)           # left glow
    c.rect(43, 13, 10, 6,  BW_EYE)           # right glow
    c.rect(29, 14, 4,  3,  BW_EYE_B)         # bright spot L
    c.rect(45, 14, 4,  3,  BW_EYE_B)         # bright spot R

    c.outline()
    return c


def hero_rogue():
    """Carl as Rogue — dark violet hood, teal glowing eyes, twin daggers."""
    c = Canvas()
    c.ellipse(40, 76, 15, 3, rgba(0, 0, 0, 70))

    # === BOOTS — pointed toe ===
    c.rect(25, 67, 12, 9,  RG_DARK)
    c.rect(37, 67, 4,  5,  RG_DARK)          # pointed boot toe L
    c.rect(43, 67, 12, 9,  RG_DARK)
    c.rect(37, 67, 2,  4,  rgb(50, 36, 75))  # sole edge

    # === LEGS — slim dark trousers ===
    c.rect(26, 53, 12, 16, RG_DARK)
    c.rect(42, 53, 12, 16, RG_DARK)
    c.rect(26, 53, 3,  16, rgb(52, 40, 80))  # faint inner highlight

    # === BELT with dagger sheaths ===
    c.rect(22, 51, 36, 4,  RG_BELT)
    c.rect(37, 50, 6,  5,  rgb(108, 82, 48)) # buckle
    # dagger hilts visible at hips
    c.rect(22, 46, 4,  8,  RG_BLADE2)        # left dagger hilt
    c.rect(54, 46, 4,  8,  RG_BLADE2)        # right dagger hilt
    c.rect(23, 44, 2,  4,  rgb(100, 72, 35)) # guard L
    c.rect(55, 44, 2,  4,  rgb(100, 72, 35)) # guard R

    # === TORSO — fitted leather ===
    c.rect(22, 28, 36, 25, RG_MID)
    c.rect(22, 28, 36, 3,  rgb(68, 50, 100)) # top highlight
    c.rect(22, 28, 4,  25, rgb(58, 44, 90))  # left edge
    c.rect(54, 32, 4,  21, RG_DARK)          # right edge shadow
    # leather panel detail
    c.rect(28, 32, 24, 16, RG_DARK)
    c.rect(28, 32, 24, 2,  rgb(62, 46, 92))
    c.rect(29, 33, 2,  14, rgb(55, 40, 85))
    # cinch lines
    for i in range(3):
        c.rect(29, 36 + i * 4, 22, 1, RG_MID)

    # === ARMS — slim + long cloak drape ===
    c.rect(10, 28, 13, 24, RG_MID)
    c.rect(10, 28, 3,  24, rgb(58, 44, 90))
    c.rect(57, 28, 13, 24, RG_MID)
    c.rect(67, 32, 3,  20, RG_DARK)
    # cloak panels hanging on sides (flared)
    c.rect(6,  32, 8,  22, RG_DARK)
    c.rect(66, 32, 8,  22, RG_DARK)
    c.rect(6,  50, 10, 6,  rgba(28, 18, 48, 180))  # tattered cloak bottom

    # === HANDS holding daggers ===
    c.rect(8,  50, 12, 7,  SKIN_SHD)          # left hand
    c.rect(60, 50, 12, 7,  SKIN_SHD)          # right hand
    # dagger blades
    c.rect(10, 36, 4,  16, RG_BLADE)          # left blade
    c.rect(62, 36, 4,  16, RG_BLADE)          # right blade
    c.rect(10, 36, 1,  16, rgb(235, 238, 255)) # blade gleam L
    c.rect(62, 36, 1,  16, rgb(235, 238, 255)) # blade gleam R
    c.rect(9,  35, 6,  3,  rgb(110, 80, 38))   # crossguard L
    c.rect(61, 35, 6,  3,  rgb(110, 80, 38))   # crossguard R

    # === NECK ===
    c.rect(33, 22, 14, 8,  SKIN_SHD)           # shadowed (hood shadow)

    # === HEAD — shadowed under hood ===
    c.rect(26, 9,  28, 15, SKIN_SHD)           # face — darker (in shadow)
    c.rect(28, 9,  4,  14, SKIN)               # small light strip nose-bridge area
    c.rect(29, 22, 22, 2,  rgb(120, 90, 62))   # chin shadow

    # === HOOD ===
    c.rect(18, 2,  44, 20, RG_DARK)            # hood main
    c.rect(18, 2,  44, 4,  rgb(45, 32, 72))    # hood brim top
    # hood drape (cloth falling down sides of face)
    c.rect(18, 10, 8,  18, rgb(22, 14, 40))    # left drape
    c.rect(54, 10, 8,  18, rgb(22, 14, 40))    # right drape
    # hood shadow inside (framing face)
    c.rect(20, 8,  8,  14, rgba(0, 0, 0, 120))
    c.rect(52, 8,  8,  14, rgba(0, 0, 0, 120))
    # hood edge highlight
    c.rect(18, 2,  4,  20, rgb(52, 40, 82))

    # === GLOWING TEAL EYES ===
    c.rect(27, 13, 10, 5,  rgba(0, 0, 0, 220))  # left socket
    c.rect(43, 13, 10, 5,  rgba(0, 0, 0, 220))  # right socket
    c.rect(28, 13, 8,  5,  RG_EYE)              # left glow
    c.rect(44, 13, 8,  5,  RG_EYE)              # right glow
    c.rect(29, 14, 3,  2,  RG_EYE_B)            # eye bright spot L
    c.rect(45, 14, 3,  2,  RG_EYE_B)            # eye bright spot R
    # slight smirk (one side of mouth)
    c.rect(32, 20, 4,  1,  rgb(100, 72, 50))
    c.rect(36, 20, 4,  2,  rgb(88, 62, 42))

    c.outline()
    return c


def hero_arcanist():
    """Carl as Arcanist — purple robes, tall wizard hat, magic glow, white beard."""
    c = Canvas()
    c.ellipse(40, 76, 17, 4, rgba(100, 50, 200, 60))  # magical shadow

    # === ROBE BOTTOM — wide hem with shimmer ===
    c.rect(16, 44, 48, 28, ARC_ROBE)
    c.rect(16, 44, 48, 3,  ARC_LIT)           # top hem highlight
    c.rect(16, 44, 3,  28, ARC_LIT)           # left edge light
    c.rect(61, 48, 3,  24, ARC_SHD)           # right edge shadow
    # robe hem panels (alternating shade for fabric folds)
    for i in range(5):
        shade = ARC_SHD if (i % 2) == 0 else ARC_ROBE
        c.rect(18 + i * 9, 58, 9, 14, shade)
    # robe border trim
    c.rect(16, 44, 48, 2, ARC_GOLD)
    c.rect(16, 70, 48, 2, ARC_GOLD)

    # === TORSO — fitted upper robe ===
    c.rect(20, 24, 40, 22, ARC_ROBE)
    c.rect(20, 24, 40, 3,  ARC_LIT)
    c.rect(20, 24, 3,  22, ARC_LIT)
    c.rect(57, 28, 3,  18, ARC_SHD)
    # chest rune circle
    c.circle(40, 36, 7, rgba(150, 60, 240, 160))
    c.circle(40, 36, 5, rgba(195, 100, 255, 200))
    c.circle(40, 36, 2, rgb(255, 220, 255))
    # rune ring detail
    c.rect(36, 29, 2, 2, ARC_MAG)
    c.rect(42, 29, 2, 2, ARC_MAG)
    c.rect(36, 42, 2, 2, ARC_MAG)
    c.rect(42, 42, 2, 2, ARC_MAG)

    # === SLEEVES ===
    c.rect(8,  24, 13, 20, ARC_ROBE)
    c.rect(8,  24, 3,  20, ARC_LIT)
    c.rect(59, 24, 13, 20, ARC_ROBE)
    c.rect(69, 28, 3,  16, ARC_SHD)
    # sleeve cuffs (gold)
    c.rect(7,  42, 14, 4,  ARC_GOLD)
    c.rect(59, 42, 14, 4,  ARC_GOLD)

    # === HANDS with magic glow ===
    c.circle(13, 50, 5, SKIN)
    c.circle(67, 50, 5, SKIN)
    c.circle(11, 49, 4, rgba(185, 80, 255, 190))  # left hand magic
    c.circle(69, 49, 4, rgba(185, 80, 255, 190))  # right hand magic
    c.circle(10, 48, 2, ARC_MAG2)
    c.circle(70, 48, 2, ARC_MAG2)

    # === STAFF (right side) ===
    c.rect(68, 6,  4,  66, rgb(72, 55, 35))   # staff shaft
    c.rect(69, 6,  1,  66, rgb(98, 78, 52))   # shaft highlight
    c.circle(70, 6,  7,  rgba(185, 65, 255, 210))  # orb glow outer
    c.circle(70, 6,  5,  ARC_MAG)             # orb mid
    c.circle(70, 6,  3,  ARC_MAG2)            # orb inner
    c.circle(70, 6,  1,  rgb(255, 240, 255))   # orb core

    # === NECK ===
    c.rect(33, 18, 14, 8,  SKIN)
    c.rect(33, 18, 4,  8,  SKIN_LIT)

    # === HEAD ===
    c.rect(27, 7,  26, 14, SKIN)
    c.rect(27, 7,  5,  14, SKIN_LIT)           # lit side
    c.rect(48, 10, 5,  11, SKIN_SHD)           # shadow side
    # cheeks + nose
    c.rect(29, 15, 3,  4,  rgb(195, 155, 108))  # cheek tint L
    c.rect(48, 15, 3,  4,  rgb(155, 118, 78))   # cheek shadow R

    # === WHITE BEARD ===
    c.rect(27, 16, 26, 5,  ARC_BEARD)
    c.rect(26, 21, 28, 4,  rgb(215, 210, 200))
    c.rect(28, 25, 24, 3,  rgb(188, 182, 170))   # beard bottom fade

    # === WIZARD HAT ===
    # brim
    c.rect(18, 6,  44, 7,  ARC_ROBE)
    c.rect(18, 6,  44, 2,  ARC_LIT)
    # hat body (tapered)
    c.rect(26, 0,  28, 8,  ARC_ROBE)
    c.rect(28, 0,  24, 3,  ARC_LIT)           # hat upper shine
    c.rect(26, 0,  3,  8,  ARC_LIT)           # hat left edge
    c.rect(50, 2,  4,  6,  ARC_SHD)           # hat right shadow
    # gold band
    c.rect(26, 7,  28, 2,  ARC_GOLD)
    # star at hat tip
    c.circle(40, 1, 3, ARC_GOLD)
    c.circle(40, 1, 1, rgb(255, 240, 140))

    # === EYES under hat brim ===
    c.rect(28, 10, 9,  5,  rgba(0, 0, 0, 180))  # left socket
    c.rect(43, 10, 9,  5,  rgba(0, 0, 0, 180))  # right socket
    c.rect(29, 10, 7,  5,  ARC_MAG)             # left eye (purple)
    c.rect(44, 10, 7,  5,  ARC_MAG)             # right eye (purple)
    c.rect(30, 11, 3,  2,  ARC_MAG2)            # bright spot L
    c.rect(45, 11, 3,  2,  ARC_MAG2)            # bright spot R

    c.outline()
    return c


# ─── Enemy Sprites ────────────────────────────────────────────────────────────

def enemy_imp():
    """Small winged devil — red-orange body, yellow glowing eyes, barbed tail."""
    c = Canvas()
    c.ellipse(40, 76, 13, 3, rgba(0, 0, 0, 80))

    # === TAIL ===
    c.line(40, 55, 56, 46, IMP_SHD)
    c.line(56, 46, 62, 36, IMP_SHD)
    # barb
    c.rect(60, 32, 6, 6, IMP_BODY)
    c.rect(62, 30, 4, 4, IMP_LIT)
    c.line(61, 34, 65, 30, IMP_SHD)  # barb spike

    # === LEGS ===
    c.rect(27, 50, 10, 16, IMP_SHD)
    c.rect(43, 50, 10, 16, IMP_SHD)
    c.rect(25, 62, 13, 6,  IMP_BODY)   # wide claw-feet
    c.rect(42, 62, 13, 6,  IMP_BODY)
    # claw toes
    c.rect(24, 65, 3, 4, IMP_CLAW)
    c.rect(28, 66, 3, 3, IMP_CLAW)
    c.rect(42, 65, 3, 4, IMP_CLAW)
    c.rect(46, 66, 3, 3, IMP_CLAW)

    # === BODY — hunched ===
    c.rect(24, 30, 32, 22, IMP_BODY)
    c.rect(24, 30, 32, 3,  IMP_LIT)    # top highlight
    c.rect(24, 30, 4,  22, IMP_LIT)    # left highlight
    c.rect(52, 34, 4,  18, IMP_SHD)    # right shadow
    c.rect(24, 48, 32, 4,  IMP_SHD)    # bottom shadow

    # === WINGS ===
    c.rect(6,  18, 20, 16, IMP_WING)
    c.rect(54, 18, 20, 16, IMP_WING)
    c.line(6,  18, 22, 30, IMP_SHD)    # wing membrane line L
    c.line(6,  22, 22, 34, IMP_SHD)
    c.line(74, 18, 58, 30, IMP_SHD)    # wing membrane line R
    c.line(74, 22, 58, 34, IMP_SHD)
    # wing bone highlight
    c.line(7,  18, 22, 28, rgba(200, 60, 20, 150))
    c.line(73, 18, 58, 28, rgba(200, 60, 20, 150))

    # === ARMS — clawed ===
    c.rect(11, 30, 14, 18, IMP_BODY)
    c.rect(11, 30, 4,  18, IMP_LIT)
    c.rect(55, 30, 14, 18, IMP_BODY)
    c.rect(65, 34, 4,  14, IMP_SHD)
    # clawed hands
    c.rect(9,  46, 13, 7,  IMP_BODY)
    c.rect(58, 46, 13, 7,  IMP_BODY)
    # claw tips
    for i, ox in enumerate([9, 13, 17]):
        c.rect(ox, 44, 2, 4, IMP_CLAW)
    for i, ox in enumerate([58, 62, 66]):
        c.rect(ox, 44, 2, 4, IMP_CLAW)

    # === NECK ===
    c.rect(32, 22, 16, 10, IMP_BODY)
    c.rect(32, 22, 4,  10, IMP_LIT)

    # === HEAD ===
    c.rect(26, 8,  28, 16, IMP_BODY)
    c.rect(26, 8,  5,  16, IMP_LIT)
    c.rect(48, 12, 6,  12, IMP_SHD)
    # cheek bumps
    c.circle(26, 20, 4, IMP_LIT)
    c.circle(54, 20, 4, IMP_SHD)

    # === HORNS ===
    c.rect(28, 2,  5,  8,  IMP_SHD)
    c.rect(47, 2,  5,  8,  IMP_SHD)
    c.rect(29, 0,  3,  4,  IMP_BODY)
    c.rect(48, 0,  3,  4,  IMP_BODY)
    # horn tip highlights
    c.rect(30, 0, 1, 2, IMP_LIT)
    c.rect(49, 0, 1, 2, IMP_LIT)

    # === GLOWING YELLOW EYES ===
    c.rect(27, 12, 10, 7,  rgba(0, 0, 0, 220))
    c.rect(43, 12, 10, 7,  rgba(0, 0, 0, 220))
    c.rect(28, 12, 8,  7,  IMP_EYE)
    c.rect(44, 12, 8,  7,  IMP_EYE)
    c.rect(29, 13, 3,  3,  rgb(255, 250, 180))  # bright spot L
    c.rect(45, 13, 3,  3,  rgb(255, 250, 180))  # bright spot R
    c.rect(34, 14, 2,  2,  rgb(200, 0,  0))     # red slit pupil L
    c.rect(50, 14, 2,  2,  rgb(200, 0,  0))     # red slit pupil R

    # === GRIN with fangs ===
    c.rect(29, 20, 22, 3,  IMP_SHD)             # mouth gap
    for i in range(4):
        c.rect(30 + i * 5, 18, 3, 4, rgb(240, 232, 200))  # fangs
    c.rect(29, 21, 22, 1, rgb(180, 30, 10))     # lip line

    c.outline()
    return c


def enemy_goblin():
    """Hunched goblin scout — green skin, big ears, leather gear, crude club."""
    c = Canvas()
    c.ellipse(40, 76, 14, 3, rgba(0, 0, 0, 80))

    # === LEGS — squat and bowed ===
    c.rect(25, 52, 12, 18, GOB_SHD)
    c.rect(43, 52, 12, 18, GOB_SHD)
    # boots / straps
    c.rect(24, 64, 14, 8,  rgb(72, 52, 34))
    c.rect(42, 64, 14, 8,  rgb(72, 52, 34))
    c.rect(24, 64, 14, 2,  rgb(102, 75, 50))

    # === BELT — wide ===
    c.rect(21, 50, 38, 5, GOB_GEAR)
    c.rect(37, 49, 6,  6, rgb(140, 108, 58))    # buckle
    c.rect(38, 50, 4,  4, rgb(105, 80, 40))      # buckle detail
    # pouch on belt
    c.rect(46, 51, 8,  6,  rgb(80, 60, 38))
    c.rect(47, 52, 6,  4,  rgb(70, 52, 32))

    # === TORSO — ragged leather armor ===
    c.rect(20, 27, 40, 25, GOB_SKIN)
    c.rect(20, 27, 40, 3,  GOB_LIT)
    c.rect(20, 27, 4,  25, GOB_LIT)
    c.rect(56, 31, 4,  21, GOB_SHD)
    # leather chest panel
    c.rect(24, 30, 32, 18, GOB_GEAR)
    c.rect(24, 30, 32, 2,  rgb(112, 85, 55))
    c.rect(24, 30, 3,  18, rgb(112, 85, 55))
    # stitches on armor
    for i in range(3):
        c.rect(25 + i * 10, 33, 2, 12, GOB_SKIN)

    # === CLUB ARM (left) ===
    c.rect(6,  27, 15, 20, GOB_SKIN)
    c.rect(6,  27, 4,  20, GOB_LIT)
    # club (crude spiked)
    c.rect(4,  12, 7,  28, rgb(85, 65, 42))     # handle
    c.circle(7, 12, 9, rgb(105, 82, 55))         # club head
    c.circle(7, 12, 7, rgb(80,  62, 40))         # head shading
    # spikes on club
    c.rect(2,  8,  3,  5,  rgb(175, 148, 105))
    c.rect(10, 6,  5,  3,  rgb(175, 148, 105))
    c.rect(13, 10, 3,  5,  rgb(175, 148, 105))

    # === SHIELD ARM (right) — small wooden buckler ===
    c.rect(59, 27, 15, 20, GOB_SKIN)
    c.rect(70, 31, 4,  16, GOB_SHD)
    # buckler
    c.circle(67, 44, 8, rgb(98, 76, 50))
    c.circle(67, 44, 6, rgb(82, 62, 38))
    c.circle(67, 44, 2, rgb(160, 128, 70))       # boss

    # === NECK ===
    c.rect(32, 21, 16, 8,  GOB_SKIN)

    # === HEAD — big with long nose ===
    c.rect(23, 7,  34, 16, GOB_SKIN)
    c.rect(23, 7,  5,  16, GOB_LIT)
    c.rect(52, 11, 5,  12, GOB_SHD)
    # snout / nose
    c.rect(30, 19, 20, 6,  GOB_LIT)
    c.rect(32, 21, 3,  3,  rgb(55, 40, 28))      # nostril L
    c.rect(45, 21, 3,  3,  rgb(55, 40, 28))      # nostril R

    # === EARS — large pointy ===
    c.rect(14, 10, 10, 12, GOB_SKIN)
    c.rect(56, 10, 10, 12, GOB_SKIN)
    c.rect(12, 8,  5,  8,  GOB_LIT)             # ear inner L
    c.rect(63, 8,  5,  8,  GOB_LIT)             # ear inner R
    # ear tip
    c.rect(10, 6,  6,  4,  GOB_SHD)
    c.rect(64, 6,  6,  4,  GOB_SHD)

    # === CRUDE HELMET — askew ===
    c.rect(23, 4,  34, 8,  rgb(82, 68, 48))
    c.rect(23, 4,  34, 2,  rgb(112, 92, 66))
    c.rect(23, 4,  3,  8,  rgb(112, 92, 66))

    # === YELLOW BEADY EYES ===
    c.rect(27, 11, 10, 7,  rgba(0, 0, 0, 210))
    c.rect(43, 11, 10, 7,  rgba(0, 0, 0, 210))
    c.rect(28, 11, 8,  7,  GOB_EYE)
    c.rect(44, 11, 8,  7,  GOB_EYE)
    c.rect(29, 12, 3,  3,  rgb(255, 240, 180))   # bright L
    c.rect(45, 12, 3,  3,  rgb(255, 240, 180))   # bright R
    c.rect(33, 13, 2,  2,  rgb(80, 40, 0))       # pupil L
    c.rect(49, 13, 2,  2,  rgb(80, 40, 0))       # pupil R

    # === JAGGED GRIN ===
    c.rect(29, 21, 22, 3,  rgb(45, 30, 18))
    for i in range(5):
        c.rect(30 + i * 4, 19, 2, 3, rgb(225, 215, 195))  # teeth

    c.outline()
    return c


def enemy_skeleton():
    """Undead warrior — visible ribcage, glowing blue eye sockets, longsword."""
    c = Canvas()
    c.ellipse(40, 76, 12, 3, rgba(0, 0, 0, 75))

    # === FEET — phalanges ===
    for i, ox in enumerate([23, 27, 31, 42, 46, 50]):
        c.rect(ox, 68, 3, 8, SKL_SHD)

    # === LEGS — tibia and fibula visible ===
    c.rect(26, 50, 7,  20, SKL_BONE)
    c.rect(47, 50, 7,  20, SKL_BONE)
    c.rect(27, 50, 2,  20, rgb(245, 238, 220))  # bone highlight
    # knee joint
    c.circle(29, 55, 4, SKL_JOINT)
    c.circle(50, 55, 4, SKL_JOINT)
    c.circle(29, 55, 2, SKL_BONE)
    c.circle(50, 55, 2, SKL_BONE)

    # === PELVIS ===
    c.rect(23, 46, 34, 6,  SKL_BONE)
    c.rect(23, 46, 34, 2,  rgb(245, 238, 220))
    # pelvis openings
    c.rect(26, 47, 10, 4,  rgba(0, 0, 0, 180))
    c.rect(44, 47, 10, 4,  rgba(0, 0, 0, 180))

    # === RIBCAGE ===
    c.rect(23, 22, 34, 26, SKL_SHD)            # ribcage fill (dark gaps between ribs)
    c.rect(23, 22, 34, 2,  rgb(245, 238, 220)) # top
    c.rect(23, 22, 3,  26, rgb(245, 238, 220)) # spine left side
    c.rect(53, 22, 3,  26, SKL_SHD)
    # individual ribs (5 pairs)
    for i in range(5):
        y = 23 + i * 5
        c.rect(26, y, 6,  3,  SKL_BONE)        # left rib
        c.rect(48, y, 6,  3,  SKL_BONE)        # right rib
        c.rect(26, y, 2,  3,  rgb(245, 238, 220))
    # sternum
    c.rect(37, 22, 6,  26, SKL_SHD)
    c.rect(38, 22, 3,  26, SKL_JOINT)
    # dark chest cavity
    c.rect(34, 24, 12, 22, rgba(0, 0, 0, 160))
    c.circle(40, 36, 3, rgba(60, 100, 255, 80)) # soul glow inside ribcage

    # === SHOULDER BLADES ===
    c.rect(15, 20, 12, 5,  SKL_BONE)
    c.rect(53, 20, 12, 5,  SKL_BONE)
    c.rect(15, 20, 4,  5,  rgb(245, 238, 220))

    # === ARMS — radius/ulna ===
    c.rect(16, 24, 6,  22, SKL_BONE)
    c.rect(17, 24, 2,  22, rgb(245, 238, 220))
    c.rect(58, 24, 6,  22, SKL_BONE)
    # joint nodes
    c.circle(19, 24, 3, SKL_JOINT)
    c.circle(19, 45, 3, SKL_JOINT)
    c.circle(61, 24, 3, SKL_JOINT)
    c.circle(61, 45, 3, SKL_JOINT)

    # === SWORD (right side) ===
    c.rect(65, 4,  5,  58, SKL_SWORD)
    c.rect(66, 4,  2,  58, rgb(218, 218, 238))  # blade gleam
    c.rect(62, 20, 11, 4,  rgb(148, 118, 55))   # crossguard
    c.rect(63, 18, 9,  3,  rgb(175, 145, 70))   # guard top highlight
    c.rect(64, 4,  5,  4,  rgb(210, 180, 75))   # pommel

    # === CLAW HAND (left) ===
    c.rect(14, 44, 8,  6,  SKL_JOINT)
    for i in range(3):
        c.rect(14 + i * 3, 42, 3, 5, SKL_BONE)   # finger bones
        c.rect(14 + i * 3, 40, 2, 3, SKL_SHD)    # fingernail/claw

    # === NECK — vertebrae ===
    c.rect(36, 16, 8,  7,  SKL_JOINT)
    c.rect(37, 16, 2,  7,  rgb(245, 238, 220))

    # === SKULL ===
    c.ellipse(40, 10, 13, 12, SKL_BONE)
    c.ellipse(40, 10, 11, 10, rgb(242, 235, 218))
    c.rect(38, 10, 5, 3, rgb(248, 242, 226))    # forehead highlight

    # === DEEP EYE SOCKETS ===
    c.ellipse(33, 10, 5, 5,  rgba(0, 0, 0, 255))
    c.ellipse(47, 10, 5, 5,  rgba(0, 0, 0, 255))
    c.circle(33, 10, 3, rgba(50, 90, 255, 220))  # blue soul glow L
    c.circle(47, 10, 3, rgba(50, 90, 255, 220))  # blue soul glow R
    c.circle(33, 10, 1, SKL_EYE_B)              # inner bright
    c.circle(47, 10, 1, SKL_EYE_B)

    # === NASAL CAVITY ===
    c.rect(38, 14, 4, 4, rgba(0, 0, 0, 220))
    c.rect(39, 15, 2, 2, rgba(0, 0, 0, 255))

    # === TEETH ===
    c.rect(29, 19, 22, 4,  rgba(0, 0, 0, 200))  # jaw gap
    for i in range(9):
        c.rect(29 + i * 2 + 1, 19, 1, 4, SKL_BONE)  # teeth
    c.rect(29, 19, 22, 1,  SKL_SHD)             # gum line

    c.outline()
    return c


def enemy_demon():
    """Massive demon — dark crimson, fire-hands, large wings, four horns."""
    c = Canvas()
    c.ellipse(40, 78, 22, 5, rgba(200, 50, 0, 80))  # hellfire glow

    # === HOOFED FEET ===
    c.rect(22, 66, 14, 10, DEM_SHD)
    c.rect(44, 66, 14, 10, DEM_SHD)
    c.rect(20, 68, 17, 6,  DEM_BODY)   # hoof
    c.rect(43, 68, 17, 6,  DEM_BODY)
    c.rect(20, 68, 5,  3,  DEM_LIT)

    # === POWERFUL LEGS ===
    c.rect(22, 50, 16, 18, DEM_BODY)
    c.rect(42, 50, 16, 18, DEM_BODY)
    c.rect(22, 50, 5,  18, DEM_LIT)
    c.rect(54, 54, 4,  14, DEM_SHD)
    # knee spikes
    c.rect(20, 54, 5,  6,  DEM_SHD)
    c.rect(55, 54, 5,  6,  DEM_SHD)
    c.rect(19, 53, 4,  4,  DEM_LIT)
    c.rect(57, 53, 4,  4,  DEM_LIT)

    # === TAIL ===
    c.line(40, 60, 60, 50, DEM_SHD)
    c.line(60, 50, 68, 38, DEM_SHD)
    c.rect(66, 32, 7, 8,   DEM_BODY)
    c.rect(68, 30, 5, 5,   DEM_LIT)
    c.line(67, 36, 73, 30, DEM_SHD)

    # === BODY — massive torso ===
    c.rect(16, 26, 48, 26, DEM_BODY)
    c.rect(16, 26, 48, 4,  DEM_LIT)
    c.rect(16, 26, 5,  26, DEM_LIT)
    c.rect(59, 30, 5,  22, DEM_SHD)
    c.rect(16, 48, 48, 4,  DEM_SHD)
    # muscle definition
    c.rect(36, 28, 8,  24, rgba(180, 50, 22, 120))  # center muscle
    c.rect(28, 28, 6,  24, rgba(145, 35, 15, 80))   # left pec division
    c.rect(46, 28, 6,  24, rgba(145, 35, 15, 80))   # right pec division
    # belly ridges
    for i in range(3):
        c.rect(18, 38 + i * 4, 44, 2, DEM_LIT)

    # === LARGE WINGS ===
    c.rect(0,  12, 18, 28, DEM_WING)
    c.rect(62, 12, 18, 28, DEM_WING)
    # wing bone structure
    c.line(0,  12, 16, 26, rgba(90, 12, 4, 220))
    c.line(0,  18, 16, 32, rgba(90, 12, 4, 220))
    c.line(0,  24, 16, 38, rgba(90, 12, 4, 220))
    c.line(80, 12, 64, 26, rgba(90, 12, 4, 220))
    c.line(80, 18, 64, 32, rgba(90, 12, 4, 220))
    c.line(80, 24, 64, 38, rgba(90, 12, 4, 220))
    # wing highlight on leading edge
    c.line(1,  12, 17, 26, rgba(165, 45, 22, 160))
    c.line(79, 12, 63, 26, rgba(165, 45, 22, 160))

    # === ARMS — thick ===
    c.rect(6,  26, 12, 26, DEM_BODY)
    c.rect(6,  26, 4,  26, DEM_LIT)
    c.rect(62, 26, 12, 26, DEM_BODY)
    c.rect(70, 30, 4,  22, DEM_SHD)

    # === FIRE FISTS ===
    c.rect(4,  50, 16, 12, DEM_LIT)
    c.rect(60, 50, 16, 12, DEM_LIT)
    # fire effects
    c.circle(10, 48, 6, rgba(255, 120, 0, 220))
    c.circle(70, 48, 6, rgba(255, 120, 0, 220))
    c.circle(10, 46, 4, rgba(255, 200, 50, 200))
    c.circle(70, 46, 4, rgba(255, 200, 50, 200))
    c.circle(10, 44, 2, rgb(255, 255, 200))
    c.circle(70, 44, 2, rgb(255, 255, 200))

    # === NECK — thick ===
    c.rect(30, 18, 20, 10, DEM_BODY)
    c.rect(30, 18, 6,  10, DEM_LIT)

    # === HEAD — fearsome ===
    c.rect(22, 4,  36, 18, DEM_BODY)
    c.rect(22, 4,  6,  18, DEM_LIT)
    c.rect(52, 8,  6,  14, DEM_SHD)
    # cheek spikes
    c.rect(20, 12, 4,  6,  DEM_LIT)
    c.rect(56, 12, 4,  6,  DEM_SHD)

    # === FOUR HORNS ===
    c.rect(22, 0,  8,  8,  DEM_SHD)
    c.rect(23, 0,  5,  5,  DEM_BODY)
    c.rect(50, 0,  8,  8,  DEM_SHD)
    c.rect(51, 0,  5,  5,  DEM_BODY)
    # inner smaller horns
    c.rect(30, 2,  6,  6,  DEM_SHD)
    c.rect(44, 2,  6,  6,  DEM_SHD)
    c.rect(31, 0,  4,  4,  DEM_BODY)
    c.rect(45, 0,  4,  4,  DEM_BODY)

    # === HELLFIRE EYES ===
    c.rect(24, 10, 14, 7,  rgba(0, 0, 0, 200))
    c.rect(42, 10, 14, 7,  rgba(0, 0, 0, 200))
    c.rect(25, 10, 12, 7,  DEM_EYE)
    c.rect(43, 10, 12, 7,  DEM_EYE)
    c.rect(27, 11, 5,  3,  DEM_EYE_B)
    c.rect(45, 11, 5,  3,  DEM_EYE_B)
    c.rect(30, 12, 2,  2,  rgba(255, 60, 0, 255))   # pupil slit L
    c.rect(48, 12, 2,  2,  rgba(255, 60, 0, 255))   # pupil slit R

    # === FANGED MOUTH ===
    c.rect(24, 18, 32, 4,  rgba(0, 0, 0, 220))
    for i in range(5):
        c.rect(25 + i * 6, 15, 4, 5, rgb(235, 228, 208))  # fangs top
        c.rect(25 + i * 6, 20, 4, 3, rgb(235, 228, 208))  # fangs bottom
    c.rect(24, 19, 32, 2,  rgb(160, 30, 10))              # gum line

    c.outline()
    return c


def enemy_golem():
    """Massive lava golem — dark stone body, glowing orange crack lines and eyes."""
    c = Canvas()
    c.ellipse(40, 78, 26, 5, rgba(0, 0, 0, 130))

    # === FEET — rough stone slabs ===
    c.rect(14, 68, 20, 10, GLM_SHD)
    c.rect(46, 68, 20, 10, GLM_SHD)
    c.rect(14, 68, 20, 3,  GLM_LIT)
    # toe cracks
    c.line(16, 72, 20, 76, GLM_LAVA)
    c.line(48, 72, 52, 76, GLM_LAVA)

    # === LEGS — stone pillars ===
    c.rect(15, 50, 20, 20, GLM_STONE)
    c.rect(45, 50, 20, 20, GLM_STONE)
    c.rect(15, 50, 6,  20, GLM_LIT)
    c.rect(61, 54, 4,  16, GLM_SHD)
    # lava cracks on legs
    c.line(18, 52, 22, 68, GLM_LAVA)
    c.line(50, 52, 54, 68, GLM_LAVA)
    c.line(20, 60, 32, 58, GLM_LAVA)
    c.circle(20, 56, 2, rgba(255, 100, 0, 200))
    c.circle(52, 62, 2, rgba(255, 120, 0, 190))

    # === BODY — enormous stone block ===
    c.rect(10, 22, 60, 30, GLM_STONE)
    c.rect(10, 22, 60, 4,  GLM_LIT)
    c.rect(10, 22, 5,  30, GLM_LIT)
    c.rect(65, 26, 5,  26, GLM_SHD)
    c.rect(10, 48, 60, 4,  GLM_SHD)
    # stone facets / chips
    c.rect(12, 26, 4,  4,  GLM_LIT)
    c.rect(64, 26, 4,  4,  GLM_SHD)
    c.rect(12, 44, 4,  4,  GLM_LIT)
    # lava crack network on body
    c.line(20, 24, 24, 50, GLM_LAVA)
    c.line(40, 22, 42, 52, GLM_LAVA)
    c.line(58, 24, 55, 50, GLM_LAVA)
    c.line(22, 38, 56, 34, GLM_LAVA)
    c.line(24, 42, 44, 46, GLM_LAVA)
    # lava glow pools at crack intersections
    c.circle(24, 38, 3, rgba(255, 90, 0, 220))
    c.circle(42, 38, 3, rgba(255, 110, 0, 200))
    c.circle(54, 34, 2, rgba(255, 80, 0, 210))
    c.circle(32, 46, 2, rgba(255, 130, 0, 190))

    # === ARMS — stone slabs extending wide ===
    c.rect(0,  22, 12, 32, GLM_STONE)
    c.rect(68, 22, 12, 32, GLM_STONE)
    c.rect(0,  22, 4,  32, GLM_LIT)
    c.rect(76, 26, 4,  28, GLM_SHD)
    # arm cracks
    c.line(2, 26, 8, 52, GLM_LAVA)
    c.line(74, 26, 70, 52, GLM_LAVA)
    c.circle(5, 40, 2, rgba(255, 80, 0, 200))
    c.circle(73, 40, 2, rgba(255, 80, 0, 200))

    # === FISTS ===
    c.rect(0,  52, 14, 12, GLM_SHD)
    c.rect(66, 52, 14, 12, GLM_SHD)
    c.rect(0,  52, 5,  12, GLM_STONE)
    c.rect(75, 56, 5,  8,  GLM_LIT)

    # === NO NECK — head sits directly on body ===
    c.rect(25, 16, 30, 8,  GLM_STONE)
    c.rect(25, 16, 8,  8,  GLM_LIT)

    # === HEAD — rectangular stone block ===
    c.rect(16, 4,  48, 16, GLM_STONE)
    c.rect(16, 4,  48, 4,  GLM_LIT)
    c.rect(16, 4,  5,  16, GLM_LIT)
    c.rect(59, 8,  5,  12, GLM_SHD)
    # head chips
    c.rect(18, 4,  4,  4,  GLM_LIT)
    c.rect(58, 6,  4,  4,  GLM_SHD)
    # head lava cracks
    c.line(22, 5, 26, 18, GLM_LAVA)
    c.line(54, 5, 52, 18, GLM_LAVA)
    c.line(28, 5, 52, 7,  GLM_LAVA)

    # === LAVA EYES — pools of molten rock ===
    c.ellipse(30, 12, 7,  6,  rgb(155, 22, 0))
    c.ellipse(50, 12, 7,  6,  rgb(155, 22, 0))
    c.ellipse(30, 12, 5,  4,  GLM_LAVA)
    c.ellipse(50, 12, 5,  4,  GLM_LAVA)
    c.ellipse(30, 12, 3,  3,  GLM_LAVA2)
    c.ellipse(50, 12, 3,  3,  GLM_LAVA2)
    c.circle(30, 12, 1, rgb(255, 220, 120))   # molten core L
    c.circle(50, 12, 1, rgb(255, 220, 120))   # molten core R

    # === MOUTH — glowing slit ===
    c.rect(22, 17, 36, 3,  rgb(120, 12, 0))
    c.rect(23, 17, 34, 1,  GLM_LAVA)

    c.outline()
    return c


# ─── Boss Sprites ─────────────────────────────────────────────────────────────

def enemy_boss_dungeon_lord():
    """Boss tier 1 (floors 1-6) — Dungeon Lord: black gold armor, crimson eyes, twin blades."""
    c = Canvas()
    c.ellipse(40, 78, 24, 5, rgba(80, 0, 0, 100))   # menacing aura

    # === BOOTS — spiked greaves ===
    c.rect(20, 66, 18, 12, DL_ARMOR)
    c.rect(42, 66, 18, 12, DL_ARMOR)
    c.rect(20, 66, 18, 3,  DL_LIT)
    # boot spikes
    c.rect(18, 62, 4,  6,  DL_GOLD)
    c.rect(58, 62, 4,  6,  DL_GOLD)
    c.rect(19, 60, 3,  4,  rgb(235, 205, 80))

    # === LEGS — heavy plate ===
    c.rect(22, 52, 16, 16, DL_ARMOR)
    c.rect(42, 52, 16, 16, DL_ARMOR)
    c.rect(22, 52, 5,  16, DL_LIT)
    c.rect(54, 56, 4,  12, rgba(0, 0, 0, 180))

    # === CRIMSON CAPE flowing behind ===
    c.rect(12, 24, 8,  52, rgba(148, 18, 18, 200))   # left cape
    c.rect(60, 24, 8,  52, rgba(148, 18, 18, 200))   # right cape
    c.rect(12, 24, 2,  52, rgba(185, 35, 35, 160))   # cape sheen
    c.rect(66, 28, 2,  48, rgba(110, 12, 12, 200))   # cape shadow

    # === BELT — gold studded ===
    c.rect(20, 50, 40, 5,  DL_ARMOR)
    c.rect(37, 49, 6,  6,  DL_GOLD)
    c.rect(38, 50, 4,  4,  DL_GOLD_D)
    # belt studs
    for i in range(6):
        c.rect(22 + i * 5, 51, 3, 3, DL_GOLD)

    # === TORSO — imposing dark plate ===
    c.rect(18, 24, 44, 28, DL_ARMOR)
    c.rect(18, 24, 44, 4,  DL_LIT)
    c.rect(18, 24, 4,  28, DL_LIT)
    c.rect(58, 28, 4,  24, rgba(0, 0, 0, 200))
    c.rect(18, 48, 44, 4,  rgba(0, 0, 0, 180))
    # black gold emblem — skull motif
    c.rect(31, 26, 18, 16, DL_GOLD)
    c.rect(32, 27, 16, 14, DL_ARMOR)
    c.ellipse(40, 34, 6, 6, DL_GOLD)
    c.ellipse(40, 34, 4, 4, DL_ARMOR)
    # skull eyes on emblem
    c.rect(36, 31, 3, 3, DL_GOLD_D)
    c.rect(41, 31, 3, 3, DL_GOLD_D)
    c.rect(37, 32, 1, 2, rgba(0,0,0,255))
    c.rect(42, 32, 1, 2, rgba(0,0,0,255))
    # shoulder plates (large)
    c.rect(10, 24, 10, 8,  DL_GOLD)
    c.rect(60, 24, 10, 8,  DL_GOLD)
    c.rect(10, 24, 4,  8,  rgb(235, 205, 80))
    c.rect(66, 28, 4,  4,  DL_GOLD_D)

    # === ARMS ===
    c.rect(8,  30, 12, 22, DL_ARMOR)
    c.rect(8,  30, 4,  22, DL_LIT)
    c.rect(60, 30, 12, 22, DL_ARMOR)
    c.rect(68, 34, 4,  18, rgba(0,0,0,180))

    # === TWIN SWORDS ===
    # left sword (diagonal raise)
    c.line(4, 62, 16, 12, DL_SWORD)
    c.line(5, 62, 17, 12, DL_SWORD)
    c.line(5, 62, 18, 12, rgb(228, 230, 250))  # gleam
    c.rect(4, 60, 6, 4,   rgb(148, 115, 40))   # pommel
    c.rect(2, 56, 10, 3,  DL_GOLD)             # crossguard
    # right sword (held lower)
    c.line(76, 58, 62, 14, DL_SWORD)
    c.line(75, 58, 61, 14, DL_SWORD)
    c.line(74, 58, 60, 14, rgb(228, 230, 250))
    c.rect(70, 56, 6, 4,   rgb(148, 115, 40))
    c.rect(68, 52, 10, 3,  DL_GOLD)

    # === GAUNTLETS ===
    c.rect(6,  50, 14, 12, DL_GOLD)
    c.rect(60, 50, 14, 12, DL_GOLD)
    c.rect(6,  50, 5,  12, rgb(235, 205, 80))
    c.rect(70, 54, 4,  8,  DL_GOLD_D)
    for i in range(3):
        c.rect(7,  52 + i * 3, 12, 2, DL_GOLD_D)
        c.rect(61, 52 + i * 3, 12, 2, DL_GOLD_D)

    # === NECK ===
    c.rect(33, 20, 14, 6,  DL_ARMOR)

    # === HEAD ===
    c.rect(26, 8,  28, 14, rgb(22, 18, 42))     # face in shadow (menacing)

    # === HORNED CROWN HELM ===
    c.rect(20, 4,  40, 18, DL_ARMOR)
    c.rect(20, 4,  40, 4,  DL_LIT)
    c.rect(20, 4,  4,  18, DL_LIT)
    c.rect(56, 8,  4,  14, rgba(0,0,0,200))
    # crown top
    c.rect(26, 0,  28, 6,  DL_GOLD)
    c.rect(26, 0,  4,  6,  rgb(240, 210, 90))
    # crown spikes
    for i in range(4):
        c.rect(27 + i * 7, 0, 5, 4, DL_GOLD)
        c.rect(28 + i * 7, 0, 3, 2, rgb(248, 225, 100))
    # crown gems
    c.circle(30, 3, 2, rgb(220, 0,  0))   # ruby
    c.circle(40, 2, 2, rgba(100, 200, 255, 255))  # sapphire
    c.circle(50, 3, 2, rgb(220, 0,  0))   # ruby
    # face slot / visor
    c.rect(24, 12, 32, 8,  rgb(15, 10, 28))
    # CRIMSON EYES
    c.rect(26, 13, 12, 6,  rgba(0, 0, 0, 255))
    c.rect(42, 13, 12, 6,  rgba(0, 0, 0, 255))
    c.rect(27, 13, 10, 6,  DL_EYE)
    c.rect(43, 13, 10, 6,  DL_EYE)
    c.rect(29, 14, 4,  3,  rgb(255, 175, 160))  # bright
    c.rect(45, 14, 4,  3,  rgb(255, 175, 160))

    c.outline()
    return c


def enemy_boss_warden():
    """Boss tier 2 (floors 7-12) — The Warden: massive mossy stone giant with rune chains."""
    c = Canvas()
    c.ellipse(40, 78, 30, 5, rgba(50, 180, 75, 90))   # green rune aura

    # === FEET — stone slabs ===
    c.rect(10, 68, 24, 10, WD_SHD)
    c.rect(46, 68, 24, 10, WD_SHD)
    c.rect(10, 68, 24, 3,  WD_LIT)
    c.rect(11, 74, 22, 4,  WD_SHD)
    # rune crack on feet
    c.line(14, 70, 20, 76, WD_RUNE)
    c.line(50, 70, 56, 76, WD_RUNE)

    # === LEGS — massive stone columns ===
    c.rect(10, 48, 24, 22, WD_STONE)
    c.rect(46, 48, 24, 22, WD_STONE)
    c.rect(10, 48, 7,  22, WD_LIT)
    c.rect(66, 52, 4,  18, WD_SHD)
    # rune carvings on legs
    c.line(15, 50, 20, 68, WD_RUNE)
    c.line(54, 50, 58, 68, WD_RUNE)
    c.circle(17, 58, 2, rgba(60, 220, 90, 220))
    c.circle(56, 62, 2, rgba(60, 220, 90, 200))

    # === CHAINS wrapped around torso ===
    # chain links (alternating rects)
    for i in range(6):
        x = 6 + i * 12
        c.rect(x,    42, 8, 3, WD_CHAIN)
        c.rect(x+3,  45, 3, 5, WD_CHAIN)
        c.rect(x+68-i*12, 42, 8, 3, WD_CHAIN)
    c.rect(8,  45, 4, 8, WD_CHAIN)   # chain ends
    c.rect(68, 45, 4, 8, WD_CHAIN)
    c.circle(10, 46, 3, rgba(140, 118, 90, 180))
    c.circle(70, 46, 3, rgba(140, 118, 90, 180))

    # === BODY — enormous, fills most of canvas ===
    c.rect(8,  18, 64, 32, WD_STONE)
    c.rect(8,  18, 64, 5,  WD_LIT)
    c.rect(8,  18, 6,  32, WD_LIT)
    c.rect(66, 22, 6,  28, WD_SHD)
    c.rect(8,  46, 64, 4,  WD_SHD)
    # massive rune carvings across chest
    c.line(18, 20, 22, 50, WD_RUNE)
    c.line(38, 18, 40, 52, WD_RUNE)
    c.line(58, 20, 56, 50, WD_RUNE)
    c.line(18, 36, 62, 30, WD_RUNE)
    c.line(20, 44, 60, 40, WD_RUNE)
    # rune glow at intersections
    for pos in [(22, 36), (40, 30), (58, 36), (30, 42), (50, 44)]:
        c.circle(pos[0], pos[1], 3, rgba(60, 220, 90, 200))
        c.circle(pos[0], pos[1], 1, WD_RUNE_B)
    # moss patches
    c.rect(14, 22, 8,  6,  rgba(45, 78, 48, 200))
    c.rect(58, 30, 8,  6,  rgba(45, 78, 48, 180))
    c.rect(30, 44, 6,  4,  rgba(45, 78, 48, 160))

    # === ARMS — wide stone slabs ===
    c.rect(0,  18, 10, 36, WD_STONE)
    c.rect(70, 18, 10, 36, WD_STONE)
    c.rect(0,  18, 4,  36, WD_LIT)
    c.rect(76, 22, 4,  32, WD_SHD)
    # rune on arms
    c.line(2, 22, 8, 52, WD_RUNE)
    c.line(78, 22, 72, 52, WD_RUNE)
    c.circle(5,  36, 2, rgba(60, 220, 90, 210))
    c.circle(75, 36, 2, rgba(60, 220, 90, 210))

    # === FISTS ===
    c.rect(0,  52, 12, 12, WD_SHD)
    c.rect(68, 52, 12, 12, WD_SHD)
    c.rect(0,  52, 5,  12, WD_STONE)
    c.rect(75, 56, 5,  8,  WD_LIT)
    # fist rune
    c.circle(5,  58, 2, rgba(60, 220, 90, 220))
    c.circle(75, 58, 2, rgba(60, 220, 90, 220))

    # === NECK — stone pillar ===
    c.rect(28, 12, 24, 8,  WD_STONE)
    c.rect(28, 12, 7,  8,  WD_LIT)

    # === HEAD — massive stone block ===
    c.rect(14, 2,  52, 14, WD_STONE)
    c.rect(14, 2,  52, 4,  WD_LIT)
    c.rect(14, 2,  5,  14, WD_LIT)
    c.rect(61, 5,  5,  11, WD_SHD)
    # head chips and age cracks
    c.rect(16, 2,  4,  4,  WD_LIT)
    c.rect(60, 4,  4,  4,  WD_SHD)
    c.line(20, 3, 24, 14, WD_RUNE)
    c.line(56, 3, 52, 14, WD_RUNE)
    c.line(28, 2, 52, 5,  WD_RUNE)

    # === RUNE-GLOW EYES ===
    c.ellipse(30, 10, 8, 6,  rgba(0, 0, 0, 255))
    c.ellipse(50, 10, 8, 6,  rgba(0, 0, 0, 255))
    c.ellipse(30, 10, 6, 4,  WD_RUNE)
    c.ellipse(50, 10, 6, 4,  WD_RUNE)
    c.circle(30, 10, 3, rgba(100, 240, 125, 230))
    c.circle(50, 10, 3, rgba(100, 240, 125, 230))
    c.circle(30, 10, 1, WD_RUNE_B)
    c.circle(50, 10, 1, WD_RUNE_B)

    # === STONE MOUTH SLAB ===
    c.rect(22, 13, 36, 3,  rgba(0, 0, 0, 200))
    c.rect(23, 13, 34, 1,  WD_RUNE)              # rune mouth-line

    c.outline()
    return c


def enemy_boss_abyss_keeper():
    """Boss tier 3 (floors 13-18) — Abyss Keeper: floating lich with void crown and staff."""
    c = Canvas()
    # void aura — large purple radiance
    c.ellipse(40, 72, 28, 6, rgba(120, 0, 200, 110))
    c.ellipse(40, 68, 20, 4, rgba(160, 0, 255, 80))

    # === ROBE — tattered void fabric ===
    c.rect(16, 38, 48, 38, AK_ROBE)
    c.rect(16, 38, 48, 3,  AK_ROBE2)
    c.rect(16, 38, 3,  38, AK_ROBE2)
    c.rect(61, 42, 3,  34, rgba(0,0,0,200))
    # tattered hem (uneven robe bottom)
    for i in range(7):
        h = 4 + (i % 3) * 3
        shade = AK_VOID if (i % 2) == 0 else AK_ROBE
        c.rect(16 + i * 7, 68, 6, h, shade)
    c.rect(16, 72, 48, 4, rgba(100, 0, 200, 120))  # void hem glow

    # === VOID ENERGY wisps around robe ===
    c.ellipse(24, 52, 5, 3, rgba(160, 0, 255, 100))
    c.ellipse(56, 58, 5, 3, rgba(160, 0, 255, 90))
    c.circle(20, 56, 3, rgba(200, 80, 255, 80))
    c.circle(60, 48, 3, rgba(200, 80, 255, 80))

    # === BODY — armored ===
    c.rect(20, 22, 40, 18, AK_ROBE2)
    c.rect(20, 22, 40, 3,  rgba(45, 25, 80, 255))
    c.rect(20, 22, 3,  18, rgba(45, 25, 80, 255))
    # bone armor ribbing on chest
    c.rect(20, 22, 2,  18, AK_SKULL2)
    c.rect(58, 22, 2,  18, AK_SKULL2)
    for i in range(3):
        c.rect(22, 26 + i * 5, 36, 2, AK_SKULL2)
    # soul crystal on chest
    c.circle(40, 32, 6, rgba(140, 0, 240, 220))
    c.circle(40, 32, 4, AK_VOID)
    c.circle(40, 32, 2, AK_VOID_B)
    c.circle(40, 32, 1, rgb(255, 240, 255))

    # === BONE ARMS — skeletal ===
    c.rect(8,  22, 13, 16, AK_ROBE2)
    c.rect(8,  22, 2,  16, AK_SKULL2)
    c.rect(18, 22, 2,  16, AK_SKULL2)
    c.rect(59, 22, 13, 16, AK_ROBE2)
    c.rect(59, 22, 2,  16, AK_SKULL2)
    c.rect(70, 22, 2,  16, AK_SKULL2)

    # === VOID STAFF (left side) ===
    c.rect(3,  4,  5,  72, rgb(44, 28, 68))      # staff shaft
    c.rect(4,  4,  1,  72, rgb(68, 45, 105))      # shaft highlight
    # void orb at top
    c.circle(5,  5,  9, rgba(120, 0, 220, 220))
    c.circle(5,  5,  7, AK_VOID)
    c.circle(5,  5,  4, AK_VOID_B)
    c.circle(5,  5,  2, rgb(255, 230, 255))
    c.circle(5,  5,  1, rgb(255, 255, 255))
    # void cracks on shaft
    c.line(6, 14, 4, 30, rgba(180, 0, 255, 140))
    c.line(4, 38, 7, 54, rgba(180, 0, 255, 120))

    # === CLAW HANDS ===
    c.rect(8,  36, 10, 7,  AK_SKULL)
    c.rect(62, 36, 10, 7,  AK_SKULL)
    # finger bones
    for i in range(3):
        c.rect(8  + i * 3, 32, 3, 6, AK_SKULL)
        c.rect(62 + i * 3, 32, 3, 6, AK_SKULL)
    # void sparks at fingertips
    c.circle(10, 32, 2, rgba(180, 0, 255, 200))
    c.circle(16, 32, 2, rgba(180, 0, 255, 180))
    c.circle(64, 32, 2, rgba(180, 0, 255, 200))
    c.circle(70, 32, 2, rgba(180, 0, 255, 180))

    # === NECK — vertebrae ===
    c.rect(34, 16, 12, 8, AK_SKULL)
    c.rect(35, 16, 2,  8, rgb(238, 232, 216))

    # === SKULL HEAD ===
    c.ellipse(40, 10, 14, 13, AK_SKULL)
    c.ellipse(40, 10, 12, 11, rgb(238, 232, 216))
    c.rect(36, 5,  8,  4,  rgb(248, 242, 228))   # forehead highlight

    # === VOID CROWN (floating above skull) ===
    c.rect(22, 0,  36, 6,  AK_CROWN)
    c.rect(22, 0,  5,  6,  rgb(195, 168, 50))    # crown highlight
    c.rect(53, 2,  5,  4,  rgb(148, 122, 22))    # crown shadow
    # crown spikes
    for i in range(5):
        x = 23 + i * 7
        c.rect(x,   0, 5, 4, AK_CROWN)
        c.rect(x+1, 0, 3, 2, rgb(208, 182, 52))
    # void gems on crown
    c.circle(28, 4, 2, AK_VOID)
    c.circle(40, 3, 3, AK_VOID)
    c.circle(40, 3, 1, AK_VOID_B)
    c.circle(52, 4, 2, AK_VOID)
    # crown void glow
    c.rect(22, 6, 36, 2, rgba(180, 0, 255, 100))

    # === DEEP VOID EYE SOCKETS ===
    c.ellipse(33, 11, 6,  6,  rgba(0, 0, 0, 255))
    c.ellipse(47, 11, 6,  6,  rgba(0, 0, 0, 255))
    c.circle(33, 11, 4, rgba(160, 0, 255, 240))   # void glow L
    c.circle(47, 11, 4, rgba(160, 0, 255, 240))   # void glow R
    c.circle(33, 11, 2, AK_VOID_B)
    c.circle(47, 11, 2, AK_VOID_B)
    c.circle(33, 11, 1, rgb(255, 230, 255))        # void core L
    c.circle(47, 11, 1, rgb(255, 230, 255))        # void core R

    # === NASAL CAVITY ===
    c.rect(38, 14, 4, 4, rgba(0, 0, 0, 235))

    # === GRIN — full skull teeth ===
    c.rect(28, 18, 24, 4,  rgba(0, 0, 0, 230))    # jaw gap
    for i in range(10):
        c.rect(28 + i * 2 + 1, 18, 1, 4, AK_SKULL)
    c.rect(28, 19, 24, 1, AK_SKULL2)              # gum line

    # floating void particles around whole figure
    for pos, sz in [((15,14),2), ((65,16),2), ((18,32),1), ((62,40),1), ((12,48),2), ((68,52),1)]:
        c.circle(pos[0], pos[1], sz, rgba(180, 0, 255, 150))

    c.outline()
    return c


# ─── Entry point ─────────────────────────────────────────────────────────────

def main():
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
    os.makedirs(out_dir, exist_ok=True)

    sprites = {
        'hero_brawler':             hero_brawler,
        'hero_rogue':               hero_rogue,
        'hero_arcanist':            hero_arcanist,
        'enemy_imp':                enemy_imp,
        'enemy_goblin':             enemy_goblin,
        'enemy_skeleton':           enemy_skeleton,
        'enemy_demon':              enemy_demon,
        'enemy_golem':              enemy_golem,
        'enemy_boss_dungeon_lord':  enemy_boss_dungeon_lord,
        'enemy_boss_warden':        enemy_boss_warden,
        'enemy_boss_abyss_keeper':  enemy_boss_abyss_keeper,
    }

    for name, fn in sprites.items():
        canvas = fn()
        path = os.path.join(out_dir, name + '.png')
        canvas.save(path)
        print(f"  wrote {name}.png  ({canvas.w}×{canvas.h})")

    print(f"\nDone — {len(sprites)} sprites in {os.path.realpath(out_dir)}")


if __name__ == '__main__':
    main()
