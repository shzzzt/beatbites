"""Generate Beat Bites' 8-bit sound effects as WAV files.

Run from the project folder:
    python tools/make_sfx.py

Writes assets/audio/sfx/*.wav (22050 Hz, 16-bit mono). Every sound is made
from simple waves (square, triangle, sine) and noise, so they are original
and need no license. Change the recipes below and run again to tweak them.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
random.seed(85)  # Same noise every run, so the files don't change for nothing.


# --- Wave building blocks ------------------------------------------------------

def square(phase):
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def sine(phase):
    return math.sin(phase * 2.0 * math.pi)


def tone(duration, freq_start, freq_end=None, wave_fn=square, volume=0.5,
         attack=0.005, decay_power=1.5, vibrato=0.0, vibrato_rate=0.0):
    """One note whose pitch slides from freq_start to freq_end and fades out."""
    freq_end = freq_start if freq_end is None else freq_end
    count = int(duration * RATE)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / count
        freq = freq_start + (freq_end - freq_start) * t
        if vibrato:
            freq *= 1.0 + vibrato * math.sin(2 * math.pi * vibrato_rate * i / RATE)
        phase += freq / RATE
        envelope = min(1.0, i / (attack * RATE + 1)) * (1.0 - t) ** decay_power
        samples.append(wave_fn(phase) * envelope * volume)
    return samples


def noise(duration, volume=0.5, smooth=0.0, decay_power=2.0):
    """White noise; smooth (0..0.95) makes it duller, like a splat or thud."""
    count = int(duration * RATE)
    samples = []
    last = 0.0
    for i in range(count):
        t = i / count
        value = random.uniform(-1.0, 1.0)
        last = last * smooth + value * (1.0 - smooth)
        samples.append(last * volume * (1.0 - t) ** decay_power * (1.0 / (1.0 - smooth * 0.7)))
    return samples


def mix(*tracks):
    length = max(len(track) for track in tracks)
    return [sum(track[i] for track in tracks if i < len(track)) for i in range(length)]


def join(*parts):
    out = []
    for part in parts:
        out.extend(part)
    return out


def silence(duration):
    return [0.0] * int(duration * RATE)


def save(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.8 / peak if peak > 0.8 else 1.0  # Never clip.
    with wave.open(path, "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples
        ))
    print("wrote", os.path.normpath(path), f"{len(samples) / RATE:.2f}s")


# --- The sounds ------------------------------------------------------------------

# THROW / INK leaving your hand: quick rising "fwip".
save("throw", mix(
    tone(0.22, 260, 1100, square, 0.30, decay_power=1.2),
    noise(0.18, 0.18, smooth=0.6),
))

# Rotten food hits the rival's panel: wet noise burst + low thump.
save("splat", mix(
    noise(0.30, 0.55, smooth=0.75, decay_power=2.5),
    tone(0.18, 180, 55, sine, 0.6, decay_power=2.0),
))

# INCOMING! warning: two quick alarm beeps, twice.
beep_hi = tone(0.07, 988, None, square, 0.28, decay_power=0.4)
beep_lo = tone(0.07, 740, None, square, 0.28, decay_power=0.4)
save("incoming", join(beep_hi, silence(0.02), beep_lo, silence(0.05),
                      beep_hi, silence(0.02), beep_lo))

# A tossed rotten food lands on your field: short dull thud.
save("land", mix(
    tone(0.14, 150, 55, sine, 0.7, decay_power=2.0),
    noise(0.08, 0.3, smooth=0.85),
))

# INK splat: bubbly "gloop" sliding down.
save("ink", mix(
    tone(0.38, 520, 140, sine, 0.55, decay_power=1.2, vibrato=0.18, vibrato_rate=28),
    noise(0.25, 0.25, smooth=0.9),
))

# SHIELD caught: sparkly rising chime.
save("shield", join(
    tone(0.07, 784, None, triangle, 0.45, decay_power=0.8),
    tone(0.07, 1175, None, triangle, 0.45, decay_power=0.8),
    tone(0.28, 1568, None, triangle, 0.45, decay_power=1.6, vibrato=0.01, vibrato_rate=9),
))

# Attack BLOCKED by a shield: bright metallic "clang".
save("blocked", mix(
    tone(0.32, 1250, 1180, square, 0.18, decay_power=2.2),
    tone(0.32, 1790, 1700, triangle, 0.30, decay_power=2.0),
    noise(0.05, 0.25, smooth=0.2),
))

# x2 caught: classic two-note coin.
save("double", join(
    tone(0.07, 988, None, square, 0.30, decay_power=0.3),
    tone(0.32, 1319, None, square, 0.30, decay_power=1.4),
))

# HEART caught: happy rising arpeggio (C, E, G, high C).
save("heart", join(
    tone(0.07, 523, None, triangle, 0.5, decay_power=0.5),
    tone(0.07, 659, None, triangle, 0.5, decay_power=0.5),
    tone(0.07, 784, None, triangle, 0.5, decay_power=0.5),
    tone(0.30, 1047, None, triangle, 0.5, decay_power=1.5, vibrato=0.012, vibrato_rate=7),
))

# You caught rotten food: sad falling "bonk".
save("bonk", mix(
    tone(0.28, 330, 95, square, 0.28, decay_power=1.3),
    tone(0.12, 120, 60, sine, 0.5, decay_power=2.0),
))
