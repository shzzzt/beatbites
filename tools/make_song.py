"""Compose and synthesize "Stardust Lullaby" (the Midnight Snack song).

Run from the project folder:
    python tools/make_song.py

Writes:
    assets/audio/music_midnight.wav   the song (32 kHz, 16-bit mono)
    assets/audio/music_midnight.json  its chart, in the same format as the
                                      other songs (bpm, beat_times_seconds,
                                      lead_notes [{beat, duration_beats, midi}])

The song is written below as notes (MIDI numbers + lengths in beats), then
every instrument is synthesized from simple waves. The chart comes from the
same notes, so the food is always exactly on the music.

Style: a dreamy, nostalgic chiptune lullaby in D major.
  - Verses use the "Canon" chord progression (D A Bm F#m G D G A).
  - The chorus uses vi-IV-I-V (Bm G D A), the classic emotional progression.
  - Music box arpeggios + soft pulse lead with vibrato + warm pad + echo.
Pure Python (no numpy), so it takes a little while to render.
"""

import json
import math
import os
import random
import struct
import wave
from array import array

RATE = 32000
BPM = 92
BEAT = 60.0 / BPM
HERE = os.path.dirname(__file__)
AUDIO_DIR = os.path.join(HERE, "..", "assets", "audio")
NAME = "music_midnight"
TITLE = "Stardust Lullaby"
random.seed(1985)

# --- The score ---------------------------------------------------------------------

# Chord name -> chord tones (MIDI, low voicing around octave 4).
CHORDS = {
    "D": [62, 66, 69], "A": [57, 61, 64], "Bm": [59, 62, 66], "F#m": [54, 57, 61],
    "G": [55, 59, 62], "Em": [52, 55, 59],
}

# Each section: (name, chords one per bar, melody bars, drums style).
# Melody bars: list of (midi, beats); midi 0 = rest. Each bar adds up to 4 beats.
VERSE_A = [
    [(78, 2), (76, 1), (74, 1)],
    [(73, 2), (69, 1), (71, .5), (73, .5)],
    [(74, 1.5), (73, .5), (71, 1), (74, 1)],
    [(69, 2), (66, 1), (69, 1)],
    [(71, 1), (74, 1), (79, 1.5), (78, .5)],
    [(78, 1), (76, .5), (74, .5), (81, 2)],
    [(79, 1), (78, 1), (76, 1), (74, 1)],
    [(76, 3), (73, 1)],
]
VERSE_B = VERSE_A[:4] + [
    [(71, 1), (74, 1), (79, 1), (81, 1)],
    [(83, 1.5), (81, .5), (78, 2)],
    [(79, 1), (78, .5), (76, .5), (74, 1), (71, 1)],
    [(73, 2), (76, 1), (73, 1)],
]
CHORUS = [
    [(83, 2), (81, 1), (78, 1)],
    [(79, 1.5), (78, .5), (76, 1), (74, 1)],
    [(78, 2), (81, 2)],
    [(76, 3), (73, 1)],
    [(74, 1), (78, 1), (83, 1.5), (81, .5)],
    [(79, 1), (83, 1), (86, 2)],
    [(85, 1), (83, 1), (81, 1), (85, 1)],
    [(85, 2), (81, 1), (76, 1)],
]
VERSE_END = VERSE_A[:6] + [
    [(79, 1), (78, 1), (76, 1), (73, 1)],
    [(74, 4)],
]
OUTRO = [
    [(83, 2), (79, 2)],
    [(78, 4)],
]

SECTIONS = [
    ("intro", ["D", "A"], None, "none"),
    ("verse", ["D", "A", "Bm", "F#m", "G", "D", "G", "A"], VERSE_A, "none"),
    ("verse2", ["D", "A", "Bm", "F#m", "G", "D", "Em", "A"], VERSE_B, "light"),
    ("chorus", ["Bm", "G", "D", "A", "Bm", "G", "A", "A"], CHORUS, "full"),
    ("verse3", ["D", "A", "Bm", "F#m", "G", "D", "G", "D"], VERSE_END, "light"),
    ("outro", ["G", "D"], OUTRO, "none"),
]

# --- Synth helpers -------------------------------------------------------------------

def midi_to_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def add(buffer, start, samples, gain=1.0):
    """Mix samples into buffer starting at sample index `start`."""
    end = min(len(buffer), start + len(samples))
    for i in range(start, end):
        buffer[i] += samples[i - start] * gain


def music_box(freq, length):
    """Bell-like pluck: sine + quieter 2nd/3rd harmonics, fast fade."""
    count = int(length * RATE)
    out = [0.0] * count
    step = freq / RATE
    for i in range(count):
        t = i / RATE
        p = i * step * 2 * math.pi
        env = math.exp(-t * 5.5) * min(1.0, i / 60.0)
        out[i] = env * (math.sin(p) + 0.35 * math.sin(2 * p) * math.exp(-t * 6)
                        + 0.12 * math.sin(3 * p + 0.5) * math.exp(-t * 9))
    return out


def lead_note(freq, length):
    """Soft pulse lead: 25% pulse, gentle low-pass, delayed vibrato."""
    count = int((length + 0.12) * RATE)
    out = [0.0] * count
    phase = 0.0
    smooth = 0.0
    hold = length * RATE
    for i in range(count):
        t = i / RATE
        vib = 1.0 + 0.0045 * math.sin(2 * math.pi * 5.5 * t) * min(1.0, max(0.0, (t - 0.18) * 4))
        phase += freq * vib / RATE
        raw = 1.0 if (phase % 1.0) < 0.25 else -0.33
        smooth += (raw - smooth) * 0.22  # One-pole low-pass: rounder tone.
        if i < hold:
            env = min(1.0, i / (0.012 * RATE)) * (0.85 + 0.15 * math.exp(-t * 3))
        else:
            env = 0.85 * math.exp(-(i - hold) / (0.04 * RATE))
        out[i] = smooth * env
    return out


def pad_chord(freqs, length):
    """Warm pad: two slightly detuned triangles per note, slow swell."""
    count = int((length + 0.3) * RATE)
    out = [0.0] * count
    for freq in freqs:
        for detune in (0.997, 1.003):
            step = freq * detune / RATE
            phase = random.random()
            for i in range(count):
                phase += step
                p = phase % 1.0
                tri = 4 * p - 1 if p < 0.5 else 3 - 4 * p
                out[i] += tri
    total = length * RATE
    for i in range(count):
        attack = min(1.0, i / (0.45 * RATE))
        release = 1.0 if i < total else math.exp(-(i - total) / (0.12 * RATE))
        out[i] *= attack * release
    return out


def bass_note(freq, length):
    count = int(length * RATE)
    out = [0.0] * count
    step = freq / RATE
    phase = 0.0
    for i in range(count):
        phase += step
        p = phase % 1.0
        tri = 4 * p - 1 if p < 0.5 else 3 - 4 * p
        env = min(1.0, i / 200.0) * (1.0 - i / count) ** 0.6
        out[i] = tri * env
    return out


def kick():
    count = int(0.22 * RATE)
    out = [0.0] * count
    phase = 0.0
    for i in range(count):
        t = i / count
        phase += (110 - 70 * t) / RATE
        out[i] = math.sin(2 * math.pi * phase) * (1 - t) ** 2
    return out


def noise_hit(length, smooth, decay):
    count = int(length * RATE)
    out = [0.0] * count
    last = 0.0
    for i in range(count):
        last = last * smooth + random.uniform(-1, 1) * (1 - smooth)
        out[i] = last * math.exp(-i / (decay * RATE))
    return out


def echo(buffer, delay_s, feedback, mix):
    """Simple feedback echo (dotted-eighth echo makes it dreamy)."""
    delay = int(delay_s * RATE)
    wet = array("f", buffer)
    for i in range(delay, len(wet)):
        wet[i] += wet[i - delay] * feedback
    return array("f", (buffer[i] * (1 - mix) + wet[i] * mix for i in range(len(buffer))))


# --- Render ------------------------------------------------------------------------

def render():
    total_bars = sum(len(section[1]) for section in SECTIONS)
    total_beats = total_bars * 4
    length = total_beats * BEAT + 2.0  # Room for the last notes to ring out.
    count = int(length * RATE)
    lead_bus = array("f", [0.0] * count)
    box_bus = array("f", [0.0] * count)
    dry_bus = array("f", [0.0] * count)

    chart = []  # Notes that become food: {beat, duration_beats, midi}.
    hat = noise_hit(0.05, 0.1, 0.012)
    snare = noise_hit(0.18, 0.55, 0.05)
    kick_hit = kick()

    bar = 0
    for name, chords, melody, drums in SECTIONS:
        for i, chord_name in enumerate(chords):
            bar_beat = bar * 4
            start = int(bar_beat * BEAT * RATE)
            tones = CHORDS[chord_name]

            # Music box arpeggio in eighths: up through the chord and back.
            arp = [tones[0], tones[1], tones[2], tones[0] + 12,
                   tones[1] + 12, tones[0] + 12, tones[2], tones[1]]
            for step, midi in enumerate(arp):
                at = int((bar_beat + step * 0.5) * BEAT * RATE)
                add(box_bus, at, music_box(midi_to_hz(midi + 12), 0.9), 0.16)
                # Intro has no melody, so its food follows the music box on each beat.
                if melody is None and step % 2 == 0:
                    chart.append({"beat": bar_beat + step * 0.5, "duration_beats": 0.5,
                                  "midi": midi + 12})

            # Pad (louder in the chorus) and bass.
            pad_gain = 0.042 if name == "chorus" else 0.025
            add(dry_bus, start, pad_chord([midi_to_hz(t) for t in tones], 4 * BEAT), pad_gain)
            root = tones[0] - 24 if tones[0] - 24 >= 30 else tones[0] - 12
            for half in (0, 2):
                add(dry_bus, int((bar_beat + half) * BEAT * RATE),
                    bass_note(midi_to_hz(root), 2 * BEAT * 0.95), 0.26)

            # Drums.
            for beat in range(4):
                at = int((bar_beat + beat) * BEAT * RATE)
                if drums in ("light", "full") and beat in (0, 2 if drums == "full" else 0):
                    add(dry_bus, at, kick_hit, 0.33)
                if drums == "full" and beat in (1, 3):
                    add(dry_bus, at, snare, 0.10)
                if drums in ("light", "full"):
                    add(dry_bus, at, hat, 0.05)
                    add(dry_bus, int((bar_beat + beat + 0.5) * BEAT * RATE), hat, 0.035)

            # Melody.
            if melody is not None:
                beat_in_bar = 0.0
                for midi, beats in melody[i]:
                    if midi > 0:
                        note_start = bar_beat + beat_in_bar
                        lead_gain = 0.36 if name == "chorus" else 0.28  # Chorus swells.
                        add(lead_bus, int(note_start * BEAT * RATE),
                            lead_note(midi_to_hz(midi), beats * BEAT * 0.92), lead_gain)
                        chart.append({"beat": note_start, "duration_beats": beats, "midi": midi})
                    beat_in_bar += beats
                assert abs(beat_in_bar - 4) < 1e-6, (name, i, beat_in_bar)
            bar += 1
        print("rendered", name)

    # Effects: dotted-eighth echo on the lead and music box, then mix.
    lead_bus = echo(lead_bus, 0.75 * BEAT, 0.35, 0.32)
    box_bus = echo(box_bus, 0.75 * BEAT, 0.30, 0.25)
    mix = array("f", (lead_bus[i] + box_bus[i] + dry_bus[i] for i in range(count)))
    # Tiny "room": three quiet early reflections.
    room = array("f", mix)
    for delay_ms, gain in ((43, 0.16), (71, 0.12), (113, 0.09)):
        d = int(delay_ms / 1000 * RATE)
        for i in range(d, count):
            room[i] += mix[i - d] * gain
    peak = max(abs(x) for x in room)
    gain = 0.89 / peak
    return [x * gain for x in room], chart, total_beats, count / RATE


def main():
    samples, chart, total_beats, seconds = render()
    os.makedirs(AUDIO_DIR, exist_ok=True)
    wav_path = os.path.join(AUDIO_DIR, NAME + ".wav")
    with wave.open(wav_path, "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(array("h", (int(max(-1.0, min(1.0, s)) * 32767) for s in samples)).tobytes())
    chart.sort(key=lambda note: note["beat"])
    data = {
        "file": NAME + ".wav",
        "title": TITLE,
        "bpm": BPM,
        "time_signature": "4/4",
        "bars": total_beats // 4,
        "beats": total_beats,
        "duration_seconds": round(seconds, 3),
        "sample_rate": RATE,
        "first_beat_seconds": 0,
        "key": "D major",
        "beat_times_seconds": [round(b * BEAT, 9) for b in range(total_beats)],
        "lead_notes": chart,
    }
    with open(os.path.join(AUDIO_DIR, NAME + ".json"), "w") as file:
        json.dump(data, file, indent=1)
    print("wrote", os.path.normpath(wav_path), f"{seconds:.1f}s,", len(chart), "chart notes")


if __name__ == "__main__":
    main()
