#!/usr/bin/env python3
"""DESCENT — Procedural Sound Effect Generator
Generates short 16-bit mono WAV SFX using only the Python standard library
(no external deps). Output: assets/audio/*.wav

These are deliberately small, punchy, retro-flavoured sounds to give combat
and UI tactile feedback. Godot imports .wav automatically.
"""

import wave, struct, math, random, os

ROOT    = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "..", "assets", "audio")
RATE    = 22050

# ── Core synthesis helpers ─────────────────────────────────────────────────────

def _env(i, n, attack=0.01, release=0.3):
    """ADSR-ish envelope (0..1) for sample i of n total."""
    t = i / n
    a = max(1e-4, attack)
    r = max(1e-4, release)
    if t < a:
        return t / a
    if t > 1.0 - r:
        return max(0.0, (1.0 - t) / r)
    return 1.0

def tone(freq, dur, vol=0.6, kind="sine", attack=0.01, release=0.3,
         vibrato=0.0, vib_rate=6.0, freq_end=None):
    """Generate a list of float samples for a single tone."""
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if freq_end is None else freq + (freq_end - freq) * (i / n)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t)
        phase += 2 * math.pi * f / RATE
        if kind == "sine":
            s = math.sin(phase)
        elif kind == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        elif kind == "saw":
            s = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
        elif kind == "tri":
            frac = (phase / (2 * math.pi)) % 1.0
            s = 4.0 * abs(frac - 0.5) - 1.0
        else:
            s = math.sin(phase)
        out.append(s * vol * _env(i, n, attack, release))
    return out

def noise(dur, vol=0.6, attack=0.005, release=0.3, seed=1, lowpass=0.0):
    """White (optionally low-passed) noise burst."""
    n = int(RATE * dur)
    rng = random.Random(seed)
    out = []
    prev = 0.0
    for i in range(n):
        white = rng.uniform(-1.0, 1.0)
        if lowpass > 0.0:
            prev = prev + lowpass * (white - prev)
            white = prev
        out.append(white * vol * _env(i, n, attack, release))
    return out

def mix(*tracks):
    """Sum equal-or-different-length tracks, padding shorter ones."""
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out

def seq(*tracks):
    """Concatenate tracks one after another."""
    out = []
    for t in tracks:
        out.extend(t)
    return out

def save(name, samples):
    # Soft-clip to avoid harsh overflow
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = min(1.0, 0.9 / peak) if peak > 0.9 else 1.0
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s * norm)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print(f"  {name:<22} {os.path.getsize(path):>6} bytes  {len(samples)/RATE:.2f}s")

# ── Sound definitions ──────────────────────────────────────────────────────────

def s_hit():
    # Punchy thud: low body + short noise crack
    return mix(
        tone(180, 0.14, vol=0.5, kind="tri", attack=0.005, release=0.7, freq_end=90),
        noise(0.09, vol=0.35, attack=0.002, release=0.8, seed=3, lowpass=0.5),
    )

def s_crit():
    # Bright metallic ring with a quick upward sparkle
    return mix(
        tone(520, 0.22, vol=0.4, kind="square", attack=0.004, release=0.6, freq_end=900),
        tone(780, 0.22, vol=0.25, kind="sine", attack=0.004, release=0.7),
        noise(0.06, vol=0.3, seed=11, lowpass=0.8),
    )

def s_kill():
    # Descending crunch
    return mix(
        tone(300, 0.26, vol=0.45, kind="saw", attack=0.004, release=0.6, freq_end=70),
        noise(0.18, vol=0.3, seed=7, lowpass=0.4),
    )

def s_hurt():
    # Low ugly buzz — the hero takes damage
    return mix(
        tone(140, 0.20, vol=0.5, kind="square", attack=0.004, release=0.6, freq_end=95),
        noise(0.10, vol=0.25, seed=21, lowpass=0.3),
    )

def s_move():
    # Soft step click
    return tone(420, 0.06, vol=0.3, kind="tri", attack=0.005, release=0.9, freq_end=300)

def s_select():
    # UI blip
    return tone(660, 0.07, vol=0.35, kind="square", attack=0.005, release=0.8, freq_end=880)

def s_ability():
    # Generic cast whoosh — rising filtered noise
    return mix(
        noise(0.28, vol=0.3, attack=0.05, release=0.5, seed=33, lowpass=0.15),
        tone(300, 0.28, vol=0.2, kind="sine", attack=0.06, release=0.5, freq_end=620),
    )

def s_fire():
    # Fireball: rumble + bright noise
    return mix(
        noise(0.34, vol=0.4, attack=0.01, release=0.5, seed=41, lowpass=0.25),
        tone(120, 0.34, vol=0.3, kind="saw", attack=0.01, release=0.6, freq_end=60),
    )

def s_frost():
    # Cold shimmer — high vibrato sine
    return mix(
        tone(1100, 0.30, vol=0.3, kind="sine", attack=0.02, release=0.6, vibrato=0.04, vib_rate=14),
        tone(1480, 0.30, vol=0.18, kind="sine", attack=0.02, release=0.7, vibrato=0.05, vib_rate=18),
    )

def s_heal():
    # Gentle rising major arpeggio
    return seq(
        tone(523, 0.10, vol=0.32, kind="sine", release=0.4),
        tone(659, 0.10, vol=0.32, kind="sine", release=0.4),
        tone(784, 0.16, vol=0.34, kind="sine", release=0.6),
    )

def s_enrage():
    # Ominous low growl
    return mix(
        tone(70, 0.55, vol=0.5, kind="saw", attack=0.04, release=0.4, vibrato=0.08, vib_rate=7),
        noise(0.55, vol=0.25, attack=0.05, release=0.4, seed=51, lowpass=0.12),
        tone(105, 0.55, vol=0.25, kind="square", attack=0.04, release=0.4),
    )

def s_levelup():
    # Ascending sparkle arpeggio
    return seq(
        tone(523, 0.09, vol=0.3, kind="square", release=0.5),
        tone(659, 0.09, vol=0.3, kind="square", release=0.5),
        tone(784, 0.09, vol=0.3, kind="square", release=0.5),
        tone(1046, 0.18, vol=0.34, kind="sine", release=0.6),
    )

def s_victory():
    # Triumphant short fanfare
    return seq(
        tone(523, 0.12, vol=0.34, kind="square", release=0.4),
        tone(659, 0.12, vol=0.34, kind="square", release=0.4),
        tone(784, 0.12, vol=0.34, kind="square", release=0.4),
        mix(tone(1046, 0.30, vol=0.36, kind="sine", release=0.6),
            tone(784, 0.30, vol=0.22, kind="sine", release=0.6)),
    )

def s_defeat():
    # Descending sad tones
    return seq(
        tone(440, 0.18, vol=0.32, kind="tri", release=0.5),
        tone(349, 0.18, vol=0.32, kind="tri", release=0.5),
        tone(262, 0.34, vol=0.34, kind="tri", release=0.6, freq_end=180),
    )

def s_descend():
    # Deep downward whoosh
    return mix(
        tone(380, 0.40, vol=0.35, kind="sine", attack=0.02, release=0.5, freq_end=90),
        noise(0.40, vol=0.2, attack=0.05, release=0.5, seed=61, lowpass=0.12),
    )

def s_lava():
    # Sizzle
    return noise(0.22, vol=0.3, attack=0.01, release=0.6, seed=71, lowpass=0.6)

SOUNDS = {
    "hit":     s_hit,    "crit":   s_crit,   "kill":    s_kill,
    "hurt":    s_hurt,   "move":   s_move,   "select":  s_select,
    "ability": s_ability,"fire":   s_fire,   "frost":   s_frost,
    "heal":    s_heal,   "enrage": s_enrage, "levelup": s_levelup,
    "victory": s_victory,"defeat": s_defeat, "descend": s_descend,
    "lava":    s_lava,
}

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"=== DESCENT Audio Generator — {len(SOUNDS)} sounds → {OUT_DIR} ===")
    for name, fn in SOUNDS.items():
        save(f"{name}.wav", fn())
    print("\n✓ Done.")

if __name__ == "__main__":
    main()
