#!/usr/bin/env python3
"""Generate pixel-art PNG sprites for DESCENT characters."""

import os
import struct
import zlib


def rgb(r, g, b):
    return (r, g, b, 255)


def rgba(r, g, b, a):
    return (r, g, b, a)


class Canvas:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.pixels = [rgba(0, 0, 0, 0)] * (w * h)

    def _set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.pixels[y * self.w + x] = color

    def rect(self, x, y, w, h, color):
        for dy in range(h):
            for dx in range(w):
                self._set(x + dx, y + dy, color)

    def circle(self, cx, cy, r, color):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    self._set(cx + dx, cy + dy, color)

    def ellipse(self, cx, cy, rx, ry, color):
        for dy in range(-ry, ry + 1):
            for dx in range(-rx, rx + 1):
                if (dx * dx * ry * ry + dy * dy * rx * rx) <= rx * rx * ry * ry:
                    self._set(cx + dx, cy + dy, color)

    def line(self, x0, y0, x1, y1, color):
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            self._set(x0, y0, color)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def save(self, path):
        def make_png(pixels, w, h):
            def chunk(name, data):
                c = struct.pack('>I', len(data)) + name + data
                c += struct.pack('>I', zlib.crc32(name + data) & 0xFFFFFFFF)
                return c

            raw = b''
            for y in range(h):
                raw += b'\x00'
                for x in range(w):
                    p = pixels[y * w + x]
                    raw += bytes(p)

            sig = b'\x89PNG\r\n\x1a\n'
            ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
            # Use RGBA (color type 6)
            ihdr_data = struct.pack('>II', w, h) + bytes([8, 6, 0, 0, 0])
            ihdr = chunk(b'IHDR', ihdr_data)
            idat = chunk(b'IDAT', zlib.compress(raw))
            iend = chunk(b'IEND', b'')
            return sig + ihdr + idat + iend

        data = make_png(self.pixels, self.w, self.h)
        with open(path, 'wb') as f:
            f.write(data)


SIZE = 64


def hero_brawler():
    c = Canvas(SIZE, SIZE)
    # Shadow
    c.ellipse(32, 60, 14, 4, rgba(0, 0, 0, 100))
    # Legs - armored
    c.rect(21, 46, 9, 14, rgb(60, 50, 40))
    c.rect(34, 46, 9, 14, rgb(60, 50, 40))
    c.rect(21, 56, 9, 4, rgb(80, 65, 45))
    c.rect(34, 56, 9, 4, rgb(80, 65, 45))
    # Body - heavy armor
    c.rect(18, 28, 28, 20, rgb(90, 75, 55))
    # Armor highlights
    c.rect(18, 28, 28, 2, rgb(130, 110, 80))
    c.rect(18, 28, 2, 20, rgb(130, 110, 80))
    # Belt
    c.rect(18, 44, 28, 3, rgb(60, 40, 20))
    c.rect(29, 44, 6, 3, rgb(200, 170, 50))
    # Arms
    c.rect(8, 28, 10, 18, rgb(90, 75, 55))
    c.rect(46, 28, 10, 18, rgb(90, 75, 55))
    # Fists
    c.rect(8, 44, 10, 8, rgb(180, 140, 100))
    c.rect(46, 44, 10, 8, rgb(180, 140, 100))
    # Neck
    c.rect(27, 22, 10, 8, rgb(180, 140, 100))
    # Head
    c.rect(20, 8, 24, 18, rgb(180, 140, 100))
    # Helmet
    c.rect(18, 6, 28, 10, rgb(90, 75, 55))
    c.rect(18, 6, 28, 2, rgb(130, 110, 80))
    # Eyes
    c.rect(22, 14, 6, 4, rgb(255, 200, 100))
    c.rect(36, 14, 6, 4, rgb(255, 200, 100))
    c.rect(24, 15, 2, 2, rgb(255, 100, 0))
    c.rect(38, 15, 2, 2, rgb(255, 100, 0))
    # Mouth / battle grimace
    c.rect(24, 21, 16, 2, rgb(120, 60, 40))
    # Shield emblem on chest
    c.rect(26, 32, 12, 8, rgb(200, 170, 50))
    c.rect(28, 34, 8, 4, rgb(90, 75, 55))
    return c


def hero_rogue():
    c = Canvas(SIZE, SIZE)
    # Shadow
    c.ellipse(32, 60, 11, 3, rgba(0, 0, 0, 100))
    # Legs - slim dark
    c.rect(23, 46, 7, 14, rgb(30, 25, 40))
    c.rect(34, 46, 7, 14, rgb(30, 25, 40))
    c.rect(23, 57, 7, 3, rgb(20, 15, 30))
    c.rect(34, 57, 7, 3, rgb(20, 15, 30))
    # Body - dark leather
    c.rect(21, 27, 22, 20, rgb(40, 30, 50))
    c.rect(21, 27, 22, 2, rgb(70, 50, 80))
    # Cloak sides
    c.rect(16, 30, 6, 18, rgb(25, 20, 35))
    c.rect(42, 30, 6, 18, rgb(25, 20, 35))
    # Belt with daggers
    c.rect(21, 43, 22, 3, rgb(50, 35, 20))
    c.rect(24, 41, 3, 5, rgb(180, 180, 200))
    c.rect(37, 41, 3, 5, rgb(180, 180, 200))
    # Arms
    c.rect(14, 27, 8, 16, rgb(40, 30, 50))
    c.rect(42, 27, 8, 16, rgb(40, 30, 50))
    # Hands holding daggers
    c.rect(12, 42, 7, 5, rgb(180, 140, 100))
    c.rect(45, 42, 7, 5, rgb(180, 140, 100))
    c.rect(14, 38, 2, 6, rgb(200, 200, 220))
    c.rect(48, 38, 2, 6, rgb(200, 200, 220))
    # Neck
    c.rect(28, 21, 8, 7, rgb(180, 140, 100))
    # Head
    c.rect(22, 9, 20, 14, rgb(180, 140, 100))
    # Hood
    c.rect(19, 6, 26, 12, rgb(30, 22, 42))
    c.rect(17, 10, 4, 8, rgb(20, 15, 30))
    c.rect(43, 10, 4, 8, rgb(20, 15, 30))
    # Eyes - glowing
    c.rect(24, 14, 5, 3, rgba(0, 0, 0, 200))
    c.rect(35, 14, 5, 3, rgba(0, 0, 0, 200))
    c.rect(25, 14, 3, 2, rgb(0, 220, 180))
    c.rect(36, 14, 3, 2, rgb(0, 220, 180))
    # Smirk
    c.rect(25, 19, 4, 1, rgb(120, 60, 40))
    c.rect(29, 20, 5, 1, rgb(120, 60, 40))
    return c


def hero_arcanist():
    c = Canvas(SIZE, SIZE)
    # Magic glow underneath
    c.ellipse(32, 58, 16, 5, rgba(100, 50, 200, 60))
    # Robe bottom
    c.rect(19, 40, 26, 20, rgb(50, 30, 100))
    for i in range(6):
        shade = 40 + i * 4
        c.rect(19 + i * 4, 54, 4, 6, rgb(shade, shade // 2, shade * 2))
    # Body robe
    c.rect(20, 24, 24, 18, rgb(55, 35, 110))
    c.rect(20, 24, 24, 2, rgb(130, 80, 200))
    # Magic rune on chest
    c.circle(32, 33, 5, rgba(150, 80, 255, 180))
    c.circle(32, 33, 3, rgba(200, 120, 255, 220))
    c.circle(32, 33, 1, rgb(255, 220, 255))
    # Sleeves
    c.rect(12, 24, 9, 14, rgb(55, 35, 110))
    c.rect(43, 24, 9, 14, rgb(55, 35, 110))
    # Hands with magic
    c.circle(14, 40, 4, rgb(180, 140, 100))
    c.circle(50, 40, 4, rgb(180, 140, 100))
    c.circle(12, 40, 3, rgba(180, 80, 255, 200))
    c.circle(52, 40, 3, rgba(180, 80, 255, 200))
    # Staff
    c.rect(56, 10, 3, 50, rgb(80, 60, 40))
    c.circle(57, 10, 5, rgba(200, 100, 255, 220))
    c.circle(57, 10, 3, rgb(255, 200, 255))
    # Neck
    c.rect(28, 18, 8, 7, rgb(180, 140, 100))
    # Head
    c.rect(22, 6, 20, 14, rgb(180, 140, 100))
    # Hat
    c.rect(18, 4, 28, 6, rgb(40, 25, 90))
    c.rect(24, 0, 16, 6, rgb(50, 30, 110))
    c.rect(26, 0, 12, 2, rgb(130, 80, 200))
    # Hat star
    c.circle(32, 2, 2, rgb(255, 220, 80))
    # Eyes - wise purple
    c.rect(24, 11, 5, 3, rgba(0, 0, 0, 180))
    c.rect(35, 11, 5, 3, rgba(0, 0, 0, 180))
    c.rect(25, 11, 3, 2, rgb(200, 140, 255))
    c.rect(36, 11, 3, 2, rgb(200, 140, 255))
    # Beard
    c.rect(24, 17, 16, 4, rgb(200, 190, 180))
    return c


def enemy_imp():
    c = Canvas(SIZE, SIZE)
    c.ellipse(32, 60, 10, 3, rgba(0, 0, 0, 90))
    # Tail
    c.line(32, 50, 46, 44, rgb(180, 30, 10))
    c.line(46, 44, 50, 38, rgb(180, 30, 10))
    c.rect(49, 35, 4, 5, rgb(200, 50, 20))
    # Legs
    c.rect(24, 46, 7, 12, rgb(160, 40, 20))
    c.rect(33, 46, 7, 12, rgb(160, 40, 20))
    c.rect(22, 55, 8, 5, rgb(120, 25, 10))
    c.rect(34, 55, 8, 5, rgb(120, 25, 10))
    # Body
    c.rect(22, 28, 20, 20, rgb(180, 50, 25))
    # Arms
    c.rect(12, 28, 11, 14, rgb(180, 50, 25))
    c.rect(41, 28, 11, 14, rgb(180, 50, 25))
    # Clawed hands
    c.rect(10, 40, 8, 5, rgb(200, 80, 40))
    c.rect(46, 40, 8, 5, rgb(200, 80, 40))
    c.rect(10, 38, 2, 4, rgb(230, 200, 150))
    c.rect(14, 37, 2, 4, rgb(230, 200, 150))
    c.rect(46, 38, 2, 4, rgb(230, 200, 150))
    c.rect(50, 37, 2, 4, rgb(230, 200, 150))
    # Wings
    c.rect(8, 22, 14, 10, rgba(160, 30, 10, 180))
    c.rect(42, 22, 14, 10, rgba(160, 30, 10, 180))
    c.line(8, 22, 22, 28, rgb(120, 20, 5))
    c.line(56, 22, 42, 28, rgb(120, 20, 5))
    # Neck
    c.rect(28, 22, 8, 7, rgb(200, 70, 35))
    # Head
    c.rect(22, 8, 20, 16, rgb(200, 70, 35))
    # Horns
    c.rect(23, 4, 4, 6, rgb(120, 20, 5))
    c.rect(37, 4, 4, 6, rgb(120, 20, 5))
    c.rect(24, 2, 2, 4, rgb(140, 30, 10))
    c.rect(38, 2, 2, 4, rgb(140, 30, 10))
    # Eyes - yellow
    c.rect(24, 14, 5, 4, rgba(0, 0, 0, 200))
    c.rect(35, 14, 5, 4, rgba(0, 0, 0, 200))
    c.rect(25, 14, 3, 3, rgb(255, 220, 0))
    c.rect(36, 14, 3, 3, rgb(255, 220, 0))
    c.rect(26, 15, 1, 1, rgb(200, 0, 0))
    c.rect(37, 15, 1, 1, rgb(200, 0, 0))
    # Fang grin
    c.rect(25, 20, 14, 2, rgb(100, 20, 5))
    c.rect(27, 19, 2, 2, rgb(240, 230, 200))
    c.rect(31, 19, 2, 2, rgb(240, 230, 200))
    c.rect(35, 19, 2, 2, rgb(240, 230, 200))
    return c


def enemy_goblin():
    c = Canvas(SIZE, SIZE)
    c.ellipse(32, 60, 12, 3, rgba(0, 0, 0, 90))
    # Legs
    c.rect(23, 46, 8, 14, rgb(74, 100, 56))
    c.rect(33, 46, 8, 14, rgb(74, 100, 56))
    c.rect(22, 56, 9, 4, rgb(54, 74, 40))
    c.rect(33, 56, 9, 4, rgb(54, 74, 40))
    # Body - ragged armor
    c.rect(20, 28, 24, 20, rgb(74, 100, 56))
    # Rags
    for i in range(3):
        w = 6 - i
        c.rect(20 + i * 8, 44, w, 4, rgb(74, 56, max(14, 24 - i // 3)))
    # Chest leather
    c.rect(24, 30, 16, 12, rgb(90, 65, 40))
    # Arms
    c.rect(11, 28, 10, 16, rgb(74, 100, 56))
    c.rect(43, 28, 10, 16, rgb(74, 100, 56))
    # Weapon - crude club
    c.rect(10, 38, 4, 18, rgb(80, 60, 40))
    c.circle(12, 38, 5, rgb(100, 80, 60))
    # Off hand
    c.rect(47, 38, 7, 7, rgb(130, 100, 70))
    # Neck
    c.rect(28, 22, 8, 7, rgb(74, 100, 56))
    # Head - big
    c.rect(20, 6, 24, 18, rgb(90, 120, 65))
    # Ears - big pointy
    c.rect(16, 10, 6, 8, rgb(90, 120, 65))
    c.rect(42, 10, 6, 8, rgb(90, 120, 65))
    c.rect(14, 8, 4, 4, rgb(110, 140, 80))
    c.rect(46, 8, 4, 4, rgb(110, 140, 80))
    # Crude helmet
    c.rect(21, 4, 22, 8, rgb(80, 65, 45))
    c.rect(21, 4, 22, 2, rgb(110, 90, 65))
    # Eyes - beady
    c.rect(24, 12, 5, 4, rgba(0, 0, 0, 200))
    c.rect(35, 12, 5, 4, rgba(0, 0, 0, 200))
    c.rect(25, 13, 3, 2, rgb(255, 180, 0))
    c.rect(36, 13, 3, 2, rgb(255, 180, 0))
    # Snout
    c.rect(27, 18, 10, 4, rgb(100, 130, 75))
    c.rect(29, 19, 2, 2, rgb(50, 40, 30))
    c.rect(33, 19, 2, 2, rgb(50, 40, 30))
    # Grin
    c.rect(25, 20, 14, 2, rgb(50, 30, 20))
    c.rect(27, 19, 2, 2, rgb(220, 200, 180))
    c.rect(35, 19, 2, 2, rgb(220, 200, 180))
    return c


def enemy_skeleton():
    c = Canvas(SIZE, SIZE)
    c.ellipse(32, 60, 11, 3, rgba(0, 0, 0, 80))
    # Legs - bones
    c.rect(25, 46, 5, 14, rgb(220, 210, 190))
    c.rect(34, 46, 5, 14, rgb(220, 210, 190))
    # Knee joints
    c.circle(27, 50, 3, rgb(200, 190, 170))
    c.circle(36, 50, 3, rgb(200, 190, 170))
    # Feet
    c.rect(23, 57, 9, 3, rgb(200, 190, 170))
    c.rect(32, 57, 9, 3, rgb(200, 190, 170))
    # Pelvis
    c.rect(22, 44, 20, 4, rgb(210, 200, 180))
    # Ribcage
    c.rect(22, 24, 20, 22, rgb(220, 210, 190))
    for i in range(4):
        y = 26 + i * 5
        c.rect(22, y, 20, 2, rgb(180, 170, 150))
    # Spine line
    c.rect(31, 24, 2, 22, rgb(180, 170, 150))
    # Shoulder bones
    c.rect(14, 22, 10, 4, rgb(220, 210, 190))
    c.rect(40, 22, 10, 4, rgb(220, 210, 190))
    # Arm bones
    c.rect(14, 26, 4, 14, rgb(220, 210, 190))
    c.rect(46, 26, 4, 14, rgb(220, 210, 190))
    # Sword
    c.rect(52, 14, 3, 32, rgb(180, 180, 200))
    c.rect(50, 24, 7, 3, rgb(150, 120, 60))
    c.rect(53, 12, 3, 4, rgb(200, 170, 80))
    # Claw hand
    c.rect(14, 38, 6, 5, rgb(200, 190, 170))
    c.rect(14, 36, 2, 4, rgb(200, 190, 170))
    c.rect(17, 35, 2, 5, rgb(200, 190, 170))
    # Neck
    c.rect(30, 18, 4, 7, rgb(210, 200, 180))
    # Skull
    c.ellipse(32, 12, 10, 10, rgb(230, 225, 210))
    # Eye sockets - hollow
    c.ellipse(27, 11, 4, 4, rgba(0, 0, 0, 240))
    c.ellipse(37, 11, 4, 4, rgba(0, 0, 0, 240))
    c.circle(27, 11, 2, rgba(50, 100, 255, 180))
    c.circle(37, 11, 2, rgba(50, 100, 255, 180))
    # Teeth
    c.rect(26, 18, 12, 3, rgba(0, 0, 0, 200))
    for i in range(6):
        c.rect(26 + i * 2, 18, 1, 3, rgb(230, 225, 210))
    return c


def enemy_demon():
    c = Canvas(SIZE, SIZE)
    # Hellfire glow
    c.ellipse(32, 58, 18, 6, rgba(200, 50, 0, 80))
    # Tail
    c.line(32, 50, 50, 42, rgb(120, 10, 0))
    c.line(50, 42, 54, 34, rgb(120, 10, 0))
    c.rect(53, 30, 5, 7, rgb(160, 30, 10))
    # Legs - powerful
    c.rect(20, 44, 10, 16, rgb(100, 15, 5))
    c.rect(34, 44, 10, 16, rgb(100, 15, 5))
    c.rect(18, 56, 12, 4, rgb(80, 10, 0))
    c.rect(34, 56, 12, 4, rgb(80, 10, 0))
    # Body - massive
    c.rect(16, 24, 32, 22, rgb(120, 20, 8))
    # Muscle highlights
    c.rect(16, 24, 2, 22, rgba(180, 50, 20, 150))
    c.rect(46, 24, 2, 22, rgba(180, 50, 20, 150))
    c.rect(30, 24, 4, 22, rgba(180, 50, 20, 100))
    # Wings - large
    c.rect(2, 16, 16, 20, rgba(80, 10, 0, 200))
    c.rect(46, 16, 16, 20, rgba(80, 10, 0, 200))
    c.line(2, 16, 16, 24, rgb(60, 5, 0))
    c.line(62, 16, 48, 24, rgb(60, 5, 0))
    c.line(2, 24, 16, 32, rgb(60, 5, 0))
    c.line(62, 24, 48, 32, rgb(60, 5, 0))
    c.line(2, 32, 16, 36, rgb(60, 5, 0))
    c.line(62, 32, 48, 36, rgb(60, 5, 0))
    # Arms - thick
    c.rect(8, 24, 10, 20, rgb(120, 20, 8))
    c.rect(46, 24, 10, 20, rgb(120, 20, 8))
    # Fists of fire
    c.rect(6, 42, 12, 8, rgb(160, 40, 15))
    c.rect(46, 42, 12, 8, rgb(160, 40, 15))
    c.circle(10, 42, 4, rgba(255, 120, 0, 200))
    c.circle(54, 42, 4, rgba(255, 120, 0, 200))
    # Neck
    c.rect(26, 18, 12, 8, rgb(140, 25, 10))
    # Head - fearsome
    c.rect(18, 4, 28, 18, rgb(140, 25, 10))
    # Horns - curved
    c.rect(18, 0, 6, 8, rgb(80, 8, 0))
    c.rect(40, 0, 6, 8, rgb(80, 8, 0))
    c.rect(16, 2, 4, 4, rgb(100, 12, 0))
    c.rect(44, 2, 4, 4, rgb(100, 12, 0))
    # Eyes - hellfire
    c.rect(22, 10, 7, 5, rgba(0, 0, 0, 200))
    c.rect(35, 10, 7, 5, rgba(0, 0, 0, 200))
    c.rect(23, 10, 5, 4, rgb(255, 100, 0))
    c.rect(36, 10, 5, 4, rgb(255, 100, 0))
    c.rect(25, 11, 2, 2, rgb(255, 240, 100))
    c.rect(38, 11, 2, 2, rgb(255, 240, 100))
    # Teeth - fangs
    c.rect(22, 17, 20, 3, rgba(0, 0, 0, 200))
    c.rect(24, 15, 3, 4, rgb(230, 220, 200))
    c.rect(29, 15, 3, 4, rgb(230, 220, 200))
    c.rect(34, 15, 3, 4, rgb(230, 220, 200))
    c.rect(39, 15, 3, 4, rgb(230, 220, 200))
    return c


def enemy_golem():
    c = Canvas(SIZE, SIZE)
    c.ellipse(32, 62, 19, 4, rgba(0, 0, 0, 120))
    # Legs - rock slabs
    c.rect(18, 46, 11, 16, rgb(74, 60, 44))
    c.rect(35, 46, 11, 16, rgb(74, 60, 44))
    c.rect(17, 58, 13, 4, rgb(58, 44, 28))
    c.rect(34, 58, 13, 4, rgb(58, 44, 28))
    # Body - massive rock
    c.rect(13, 28, 38, 20, rgb(74, 60, 44))
    # Rock facets
    c.rect(13, 28, 38, 2, rgb(100, 82, 60))
    c.rect(13, 28, 2, 20, rgb(100, 82, 60))
    # Lava cracks on body
    c.line(20, 30, 22, 45, rgb(255, 80, 0))
    c.line(32, 28, 34, 47, rgb(255, 100, 0))
    c.line(44, 30, 42, 46, rgb(255, 80, 0))
    c.line(22, 38, 42, 36, rgb(255, 80, 0))
    # Lava glow spots
    c.circle(26, 40, 2, rgba(255, 80, 0, 200))
    c.circle(38, 44, 2, rgba(255, 120, 0, 180))
    c.circle(32, 50, 2, rgba(255, 100, 0, 190))
    # Arms - rock slabs
    c.rect(2, 28, 13, 24, rgb(74, 60, 44))
    c.rect(49, 28, 13, 24, rgb(74, 60, 44))
    # Fists
    c.rect(1, 50, 15, 10, rgb(58, 44, 28))
    c.rect(48, 50, 15, 10, rgb(58, 44, 28))
    # Arm cracks
    c.line(4, 32, 6, 50, rgb(255, 80, 0))
    c.line(60, 32, 58, 50, rgb(255, 80, 0))
    # Neck
    c.rect(26, 22, 12, 8, rgb(84, 70, 52))
    # Head - rock block
    c.rect(17, 8, 30, 16, rgb(90, 76, 60))
    # Head chips
    c.rect(17, 8, 30, 2, rgb(110, 92, 72))
    # Eye lava pools
    c.ellipse(26, 16, 5, 4, rgb(170, 24, 0))
    c.ellipse(38, 16, 5, 4, rgb(170, 24, 0))
    c.ellipse(26, 16, 3, 3, rgb(255, 64, 0))
    c.ellipse(38, 16, 3, 3, rgb(255, 64, 0))
    c.circle(26, 16, 1, rgb(255, 200, 0))
    c.circle(38, 16, 1, rgb(255, 200, 0))
    # Lava cracks on head
    c.line(22, 9, 24, 22, rgb(255, 80, 0))
    c.line(42, 9, 40, 22, rgb(255, 80, 0))
    # Mouth slit
    c.rect(22, 21, 20, 2, rgb(136, 14, 0))
    c.rect(24, 21, 16, 1, rgb(255, 64, 0))
    return c


def enemy_boss():
    """Floor boss: a massive armored lich-king."""
    c = Canvas(SIZE, SIZE)
    # Unholy aura
    c.ellipse(32, 58, 22, 7, rgba(80, 0, 150, 100))
    c.ellipse(32, 56, 18, 5, rgba(120, 0, 200, 80))
    # Robe bottom - tattered
    c.rect(14, 40, 36, 22, rgb(20, 8, 40))
    for i in range(6):
        h = 4 + (i % 3) * 2
        c.rect(14 + i * 6, 58, 5, h, rgb(30, 10, 60))
    # Swirling shadow base
    for i in range(3):
        c.ellipse(32, 56, 14 - i * 3, 4 - i, rgba(150, 0, 255, 40))
    # Body - armored
    c.rect(18, 22, 28, 20, rgb(25, 10, 50))
    # Bone armor plates
    c.rect(18, 22, 28, 2, rgb(200, 190, 170))
    c.rect(18, 22, 2, 20, rgb(200, 190, 170))
    c.rect(44, 22, 2, 20, rgb(200, 190, 170))
    c.rect(27, 24, 10, 16, rgb(200, 190, 170))
    c.rect(29, 26, 6, 12, rgba(100, 0, 200, 180))
    # Soul crystal on chest
    c.circle(32, 32, 4, rgba(150, 0, 255, 240))
    c.circle(32, 32, 2, rgb(220, 180, 255))
    # Arms - skeletal
    c.rect(8, 22, 11, 18, rgb(25, 10, 50))
    c.rect(45, 22, 11, 18, rgb(25, 10, 50))
    c.rect(8, 22, 2, 18, rgb(200, 190, 170))
    c.rect(17, 22, 2, 18, rgb(200, 190, 170))
    c.rect(45, 22, 2, 18, rgb(200, 190, 170))
    c.rect(54, 22, 2, 18, rgb(200, 190, 170))
    # Staff of doom (left side)
    c.rect(4, 6, 4, 54, rgb(50, 35, 80))
    c.circle(6, 7, 6, rgba(180, 0, 255, 220))
    c.circle(6, 7, 4, rgb(220, 100, 255))
    c.circle(6, 7, 2, rgb(255, 240, 255))
    # Hands / claw
    c.rect(6, 38, 8, 6, rgb(190, 180, 160))
    c.rect(47, 38, 8, 6, rgb(190, 180, 160))
    # Claw fingers
    c.rect(6, 36, 2, 4, rgb(190, 180, 160))
    c.rect(9, 35, 2, 5, rgb(190, 180, 160))
    c.rect(12, 36, 2, 4, rgb(190, 180, 160))
    c.rect(47, 36, 2, 4, rgb(190, 180, 160))
    c.rect(50, 35, 2, 5, rgb(190, 180, 160))
    c.rect(53, 36, 2, 4, rgb(190, 180, 160))
    # Neck - bone
    c.rect(28, 16, 8, 7, rgb(200, 190, 170))
    # Skull head
    c.ellipse(32, 11, 12, 11, rgb(220, 215, 200))
    # Crown - gold and evil
    c.rect(20, 4, 24, 8, rgb(160, 130, 20))
    c.rect(20, 4, 24, 2, rgb(220, 190, 50))
    # Crown spikes
    for i in range(5):
        x = 20 + i * 6
        c.rect(x, 0, 4, 6, rgb(180, 145, 25))
        c.rect(x + 1, 0, 2, 2, rgb(240, 200, 60))
    # Crown gems
    c.circle(25, 6, 2, rgb(220, 0, 0))
    c.circle(32, 5, 2, rgb(0, 180, 255))
    c.circle(39, 6, 2, rgb(220, 0, 0))
    # Eye sockets - deep
    c.ellipse(26, 13, 5, 5, rgba(0, 0, 0, 255))
    c.ellipse(38, 13, 5, 5, rgba(0, 0, 0, 255))
    # Soul fire eyes
    c.circle(26, 13, 3, rgba(180, 0, 255, 240))
    c.circle(38, 13, 3, rgba(180, 0, 255, 240))
    c.circle(26, 13, 1, rgb(255, 200, 255))
    c.circle(38, 13, 1, rgb(255, 200, 255))
    # Nasal cavity
    c.rect(30, 17, 4, 3, rgba(0, 0, 0, 200))
    # Grin - full skull
    c.rect(22, 20, 20, 3, rgba(0, 0, 0, 220))
    for i in range(10):
        c.rect(22 + i * 2, 20, 1, 3, rgb(220, 215, 200))
    return c


def main():
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
    os.makedirs(out_dir, exist_ok=True)

    sprites = {
        'hero_brawler': hero_brawler,
        'hero_rogue': hero_rogue,
        'hero_arcanist': hero_arcanist,
        'enemy_imp': enemy_imp,
        'enemy_goblin': enemy_goblin,
        'enemy_skeleton': enemy_skeleton,
        'enemy_demon': enemy_demon,
        'enemy_golem': enemy_golem,
        'enemy_boss': enemy_boss,
    }

    for name, fn in sprites.items():
        canvas = fn()
        path = os.path.join(out_dir, name + '.png')
        canvas.save(path)
        print(f"  wrote {name}.png")

    print(f"Done — {len(sprites)} sprites in {os.path.realpath(out_dir)}")


if __name__ == '__main__':
    main()
