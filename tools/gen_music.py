#!/usr/bin/env python3
"""DESCENT — Procedural Ambient Music Generator
Generates looping 16-bit mono WAV ambient tracks using only the Python
standard library (no external deps).

Output: assets/audio/music_*.wav

Four tracks:
  music_title    — dark cinematic title theme (~28s loop)
  music_stone    — Floors 1-6  warm low drone with sparse drum + harp ping (~32s loop)
  music_obsidian — Floors 7-12 colder minor mode, glassy chimes, slow pulse (~32s loop)
  music_void     — Floors 13-18 deep void hum, dissonant overtones, sparse bell (~32s loop)

Goal: minimal, atmospheric, non-distracting — the SYSTEM's commentary and SFX
remain the foreground. Tracks are designed to loop seamlessly (the final sample
crossfades back into the first).
"""

import wave, struct, math, random, os

ROOT    = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "..", "assets", "audio")
RATE    = 22050

# ── Synthesis helpers ──────────────────────────────────────────────────────────

def sine_wave(freq, dur, vol=0.3, phase0=0.0, vibrato=0.0, vib_rate=4.0):
    n = int(RATE * dur)
    out = [0.0] * n
    phase = phase0
    for i in range(n):
        t = i / RATE
        f = freq * (1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t)) if vibrato else freq
        phase += 2 * math.pi * f / RATE
        out[i] = vol * math.sin(phase)
    return out

def saw_wave(freq, dur, vol=0.2):
    n = int(RATE * dur)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        phase += 2 * math.pi * freq / RATE
        out[i] = vol * (2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0)
    return out

def noise_bed(dur, vol=0.05, seed=1, lowpass=0.04):
    """Heavily filtered noise bed for atmospheric hiss."""
    n = int(RATE * dur)
    rng = random.Random(seed)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        w = rng.uniform(-1.0, 1.0)
        prev = prev + lowpass * (w - prev)
        out[i] = vol * prev
    return out

def envelope_attack_release(samples, attack=0.05, release=0.3):
    """Apply a soft fade-in/fade-out envelope to a buffer."""
    n = len(samples)
    a = max(1, int(RATE * attack))
    r = max(1, int(RATE * release))
    for i in range(min(a, n)):
        samples[i] *= i / a
    for i in range(min(r, n)):
        samples[n - 1 - i] *= i / r
    return samples

def bell(freq, dur, vol=0.25):
    """Bell-like tone: fundamental + 2 inharmonic partials, exponential decay."""
    n = int(RATE * dur)
    out = [0.0] * n
    partials = [(1.0, vol), (2.76, vol * 0.45), (5.40, vol * 0.22)]
    for i in range(n):
        t = i / RATE
        env = math.exp(-2.6 * t)
        s = 0.0
        for mult, v in partials:
            s += v * env * math.sin(2 * math.pi * freq * mult * t)
        out[i] = s
    return out

def harp_pluck(freq, dur, vol=0.22):
    """Soft plucked tone — exponential decay sine + tiny brightness."""
    n = int(RATE * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        env = math.exp(-3.5 * t)
        s = vol * env * (math.sin(2 * math.pi * freq * t)
                         + 0.20 * math.sin(2 * math.pi * freq * 2 * t)
                         + 0.08 * math.sin(2 * math.pi * freq * 3 * t))
        out[i] = s
    return out

def soft_drum(dur=0.30, vol=0.20, seed=3):
    """Low thump: short noise burst + low sine body."""
    n = int(RATE * dur)
    rng = random.Random(seed)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        env = math.exp(-12.0 * t)
        body = math.sin(2 * math.pi * 60.0 * t * math.exp(-6 * t))
        click = rng.uniform(-1, 1) * math.exp(-30 * t)
        out[i] = vol * env * (body * 0.85 + click * 0.18)
    return out

def add_at(buf, src, start_sample, gain=1.0):
    """Mix src into buf starting at sample index `start_sample`. Wraps for loop."""
    n = len(buf)
    for i, s in enumerate(src):
        idx = (start_sample + i) % n
        buf[idx] += gain * s

def loop_crossfade(buf, fade_s=1.5):
    """Make the tail seamlessly fade into the head so the WAV loops cleanly.
    Mixes the last `fade_s` seconds with the first `fade_s` and keeps result
    in the head."""
    n = len(buf)
    f = min(int(RATE * fade_s), n // 4)
    if f <= 0:
        return buf
    for i in range(f):
        w = i / f
        head = buf[i]
        tail = buf[n - f + i]
        # Linear crossfade so the boundary is continuous
        buf[i] = head * w + tail * (1.0 - w)
    # Trim off the tail we folded in
    return buf[:n - f]

def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = min(1.0, 0.85 / peak) if peak > 0.85 else 1.0
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
    size_kb = os.path.getsize(path) / 1024
    print(f"  {name:<22} {size_kb:>7.1f} KB  {len(samples)/RATE:.2f}s")

# ── Track recipes ──────────────────────────────────────────────────────────────

def title_theme():
    """Dark, cinematic, slow-rising — minor chord pad + slow bell hits.
    Loop length ~28s."""
    dur = 30.0
    n = int(RATE * dur)
    buf = [0.0] * n

    # Sustained minor-chord pad: A2, C3, E3 — slow vibrato gives subtle motion
    for f in (110.00, 130.81, 164.81):
        pad = sine_wave(f, dur, vol=0.18, vibrato=0.004, vib_rate=0.3)
        for i, s in enumerate(pad):
            buf[i] += s
    # Octave-down sub for body
    for i, s in enumerate(sine_wave(55.0, dur, vol=0.14, vibrato=0.003, vib_rate=0.22)):
        buf[i] += s
    # Quiet noise bed
    for i, s in enumerate(noise_bed(dur, vol=0.03, seed=11, lowpass=0.03)):
        buf[i] += s
    # Sparse bell hits at 0s, 8s, 16s — bell on A3 / C4 / A3
    for tsec, freq in [(0.4, 220.0), (8.0, 261.63), (16.5, 196.0), (23.5, 220.0)]:
        add_at(buf, bell(freq, 3.5, vol=0.22), int(tsec * RATE), 1.0)

    envelope_attack_release(buf, attack=0.6, release=0.0)
    return loop_crossfade(buf, fade_s=1.5)

def stone_theme():
    """Floors 1-6 — warm low drone, slow tribal pulse, occasional harp pluck."""
    dur = 32.0
    n = int(RATE * dur)
    buf = [0.0] * n

    # Warm pad: D2 + F2 + A2 (D minor) — sustained
    for f in (73.42, 87.31, 110.00):
        for i, s in enumerate(sine_wave(f, dur, vol=0.16, vibrato=0.003, vib_rate=0.25)):
            buf[i] += s
    # Sub drone
    for i, s in enumerate(sine_wave(36.71, dur, vol=0.14)):
        buf[i] += s
    # Atmospheric bed
    for i, s in enumerate(noise_bed(dur, vol=0.025, seed=21, lowpass=0.025)):
        buf[i] += s
    # Slow tribal pulse every 2.0s
    for tsec in [0.5, 2.5, 4.5, 6.5, 8.5, 10.5, 12.5, 14.5,
                 16.5, 18.5, 20.5, 22.5, 24.5, 26.5, 28.5, 30.5]:
        add_at(buf, soft_drum(0.45, vol=0.20, seed=31 + int(tsec)), int(tsec * RATE))
    # Sparse plucks: D4, F4, A4 on irregular beats
    plucks = [(3.0, 293.66), (7.2, 349.23), (11.5, 440.0),
              (15.3, 293.66), (19.4, 349.23), (24.0, 440.0), (28.8, 293.66)]
    for tsec, freq in plucks:
        add_at(buf, harp_pluck(freq, 2.5, vol=0.18), int(tsec * RATE))

    envelope_attack_release(buf, attack=0.4, release=0.0)
    return loop_crossfade(buf, fade_s=1.5)

def obsidian_theme():
    """Floors 7-12 — cold minor mode, glassy chimes, slow pulse."""
    dur = 32.0
    n = int(RATE * dur)
    buf = [0.0] * n

    # Cold pad: F#2, A2, C3 (F# diminished) — eerie
    for f in (92.50, 110.00, 130.81):
        for i, s in enumerate(sine_wave(f, dur, vol=0.14, vibrato=0.005, vib_rate=0.35)):
            buf[i] += s
    # Deep sub
    for i, s in enumerate(sine_wave(46.25, dur, vol=0.12)):
        buf[i] += s
    # Light noise bed (more icy)
    for i, s in enumerate(noise_bed(dur, vol=0.022, seed=41, lowpass=0.04)):
        buf[i] += s
    # Glassy bells — irregular spacing, high pitches
    bells = [(1.8, 740.0), (5.5, 880.0), (9.8, 659.25), (13.2, 1108.73),
             (17.5, 740.0), (21.0, 880.0), (25.4, 987.77), (29.6, 659.25)]
    for tsec, freq in bells:
        add_at(buf, bell(freq, 3.2, vol=0.18), int(tsec * RATE))
    # Very slow pulse — half-tempo of stone
    for tsec in [0.8, 4.8, 8.8, 12.8, 16.8, 20.8, 24.8, 28.8]:
        add_at(buf, soft_drum(0.55, vol=0.18, seed=51 + int(tsec)), int(tsec * RATE))

    envelope_attack_release(buf, attack=0.4, release=0.0)
    return loop_crossfade(buf, fade_s=1.5)

def void_theme():
    """Floors 13-18 — deep void hum, dissonant overtones, sparse bell."""
    dur = 32.0
    n = int(RATE * dur)
    buf = [0.0] * n

    # Dissonant pad: C2, F#2, A2 — tritone + minor 6th
    for f in (65.41, 92.50, 110.00):
        for i, s in enumerate(sine_wave(f, dur, vol=0.14, vibrato=0.008, vib_rate=0.45)):
            buf[i] += s
    # Very deep sub
    for i, s in enumerate(sine_wave(32.70, dur, vol=0.18)):
        buf[i] += s
    # Dark noise bed
    for i, s in enumerate(noise_bed(dur, vol=0.035, seed=61, lowpass=0.022)):
        buf[i] += s
    # Slow doom bells (low pitch)
    doom = [(2.0, 110.0), (10.5, 138.59), (18.0, 110.0), (26.5, 87.31)]
    for tsec, freq in doom:
        add_at(buf, bell(freq, 4.5, vol=0.32), int(tsec * RATE))
    # Sparse irregular drum
    for tsec in [3.0, 7.6, 13.4, 19.8, 24.2, 30.0]:
        add_at(buf, soft_drum(0.7, vol=0.22, seed=71 + int(tsec)), int(tsec * RATE))

    envelope_attack_release(buf, attack=0.5, release=0.0)
    return loop_crossfade(buf, fade_s=1.5)

TRACKS = {
    "music_title":    title_theme,
    "music_stone":    stone_theme,
    "music_obsidian": obsidian_theme,
    "music_void":     void_theme,
}

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"=== DESCENT Music Generator — {len(TRACKS)} tracks → {OUT_DIR} ===")
    for name, fn in TRACKS.items():
        save(f"{name}.wav", fn())
    print("\nDone.")

if __name__ == "__main__":
    main()
