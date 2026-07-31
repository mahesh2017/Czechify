#!/usr/bin/env python3
"""Synthesize the app's sound effects from scratch.

These are generated rather than downloaded because "royalty-free" sound packs
are a licensing trap — most are CC-BY at best, and this app ships commercially.
Everything here is additive synthesis over sine partials, so the output is
original work with no attribution to carry.

It also means the palette can be tuned to the app: soft mallet tones in the
same register, so a correct answer and a unit completion sound like they come
from the same instrument rather than from two different asset packs.

    python3 tool/generate_sfx.py            # write assets/sfx/
    python3 tool/generate_sfx.py --preview  # also play each one

Format is split by whether latency is audible. Every MP3 decoder prepends
~26 ms of encoder delay, which reads as lag on a sound meant to land in the
same instant as a tap — so the five that fire mid-interaction stay
uncompressed. The four ceremony sounds play under a screen transition where
26 ms is invisible, and compressing them saves ~75% of the pack.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sfx"
RATE = 44100

# Equal temperament, A4 = 440.
def note(name: str) -> float:
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
             "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    semitones = names[pitch] + 12 * (octave - 4) - 9
    return 440.0 * (2 ** (semitones / 12))


def envelope(n: int, attack: float, decay: float) -> np.ndarray:
    """Percussive envelope: near-instant attack, exponential tail."""
    t = np.arange(n) / RATE
    rise = np.clip(t / max(attack, 1e-6), 0, 1)
    fall = np.exp(-t / decay)
    return rise * fall


def mallet(freq: float, seconds: float, decay: float = 0.45,
           brightness: float = 0.5) -> np.ndarray:
    """A soft mallet tone — marimba-like, warm rather than bell-like.

    A struck bar's partials are inharmonic and die faster the higher they are;
    reproducing that (rather than stacking pure octaves) is what stops the
    result sounding like a video-game blip.
    """
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    partials = [
        (1.0, 1.00, decay),
        (4.0, brightness * 0.30, decay * 0.35),   # marimba's strong 4th
        (9.8, brightness * 0.12, decay * 0.18),
        (2.0, brightness * 0.08, decay * 0.50),
    ]
    out = np.zeros(n)
    for ratio, amp, dec in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / dec)
    return out * envelope(n, 0.002, decay)


def bell(freq: float, seconds: float, decay: float = 1.1) -> np.ndarray:
    """Brighter, longer — reserved for the moments that should feel rarer."""
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for ratio, amp, dec in [(1.0, 1.0, decay), (2.0, 0.5, decay * 0.7),
                            (3.0, 0.25, decay * 0.5), (4.2, 0.18, decay * 0.35),
                            (5.4, 0.10, decay * 0.25)]:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / dec)
    return out * envelope(n, 0.003, decay)


def shimmer(seconds: float, decay: float = 0.9) -> np.ndarray:
    """High filtered noise — the 'sparkle' tail under a big chord."""
    n = int(RATE * seconds)
    rng = np.random.default_rng(7)          # fixed: regeneration stays identical
    noise = rng.standard_normal(n)
    # One-pole high-pass, then a slow tremolo so it glitters instead of hissing.
    out = np.zeros(n)
    prev_in = prev_out = 0.0
    a = 0.97
    for i in range(n):
        prev_out = a * (prev_out + noise[i] - prev_in)
        prev_in = noise[i]
        out[i] = prev_out
    t = np.arange(n) / RATE
    out *= (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t))
    return out * envelope(n, 0.05, decay) * 0.12


def place(canvas: np.ndarray, sound: np.ndarray, at: float) -> None:
    """Mix `sound` into `canvas` starting at `at` seconds."""
    start = int(at * RATE)
    end = min(start + len(sound), len(canvas))
    canvas[start:end] += sound[: end - start]


def normalize(x: np.ndarray, peak: float) -> np.ndarray:
    """Scale to a target peak, and fade the last 5 ms so nothing clicks off."""
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    tail = min(int(RATE * 0.005), len(x))
    if tail:
        x[-tail:] *= np.linspace(1, 0, tail)
    return x


def trim(x: np.ndarray, floor_db: float = -60.0) -> np.ndarray:
    """Cut the tail once it is inaudible, so an exponential decay does not
    pay for several hundred ms of silence."""
    peak = np.max(np.abs(x))
    if peak <= 0:
        return x
    above = np.flatnonzero(np.abs(x) > peak * 10 ** (floor_db / 20))
    return x if above.size == 0 else x[: above[-1] + 1]


def write(name: str, samples: np.ndarray, peak: float, compressed: bool) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    data = normalize(trim(samples), peak)
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")

    wav = OUT / f"{name}.wav"
    with wave.open(str(wav), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    if not compressed:
        return wav

    mp3 = OUT / f"{name}.mp3"
    result = subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
         "-ac", "1", "-b:a", "96k", str(mp3)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"ffmpeg failed for {name}:\n{result.stderr}")
    wav.unlink()
    return mp3


# ── The palette ────────────────────────────────────────────────────────────
# Peaks differ on purpose. A correct answer plays ~790 times over the course
# and must sit under the UI; a unit completion plays 31 times and should be
# the loudest thing the app ever does.

def correct(step: int) -> np.ndarray:
    """Three rising steps, so consecutive right answers escalate."""
    pitch = ["C5", "E5", "G5"][step]
    return mallet(note(pitch), 0.42, decay = 0.20, brightness = 0.45)


def combo() -> np.ndarray:
    """A streak milestone — same instrument, an octave up and ringing."""
    n = int(RATE * 0.9)
    out = np.zeros(n)
    place(out, bell(note("C6"), 0.9, decay = 0.55), 0.0)
    place(out, bell(note("G6"), 0.8, decay = 0.45) * 0.5, 0.055)
    return out


def wrong() -> np.ndarray:
    """Deliberately gentle. Mistakes are where the learning is — this is a
    nudge, not a buzzer, and nothing about it should feel punitive."""
    n = int(RATE * 0.34)
    t = np.arange(n) / RATE
    body = np.sin(2 * np.pi * 174 * t) * np.exp(-t / 0.075)
    body += 0.4 * np.sin(2 * np.pi * 262 * t) * np.exp(-t / 0.045)
    return body * envelope(n, 0.004, 0.09)


def lesson_complete() -> np.ndarray:
    """A rising three-note figure — resolved, but leaves room above it."""
    n = int(RATE * 1.5)
    out = np.zeros(n)
    for i, p in enumerate(["C5", "E5", "G5"]):
        place(out, mallet(note(p), 1.1, decay = 0.55), i * 0.11)
    place(out, mallet(note("C6"), 1.2, decay = 0.7) * 0.45, 0.33)
    return out


def perfect_lesson() -> np.ndarray:
    """The same figure, carried an octave higher and left to ring."""
    n = int(RATE * 1.9)
    out = np.zeros(n)
    for i, p in enumerate(["C5", "E5", "G5", "C6"]):
        place(out, mallet(note(p), 1.4, decay = 0.62, brightness = 0.7), i * 0.10)
    place(out, bell(note("E6"), 1.3, decay = 0.75) * 0.35, 0.42)
    place(out, shimmer(1.5, decay = 0.7) * 0.6, 0.30)
    return out


def unit_complete() -> np.ndarray:
    """The biggest sound in the app: a low root arriving first so it lands
    like a stamp, then the chord opening above it."""
    n = int(RATE * 2.4)
    out = np.zeros(n)
    place(out, mallet(note("C3"), 1.6, decay = 0.85, brightness = 0.3) * 0.9, 0.0)
    for i, p in enumerate(["C4", "G4", "C5", "E5", "G5"]):
        place(out, mallet(note(p), 1.8, decay = 0.80, brightness = 0.6),
              0.06 + i * 0.055)
    place(out, bell(note("C6"), 1.8, decay = 1.0) * 0.42, 0.36)
    place(out, shimmer(2.0, decay = 1.0), 0.28)
    return out


def badge() -> np.ndarray:
    """Two quick high notes — a sparkle, short enough to ride over a toast."""
    n = int(RATE * 0.8)
    out = np.zeros(n)
    place(out, bell(note("G5"), 0.5, decay = 0.28) * 0.8, 0.0)
    place(out, bell(note("C6"), 0.7, decay = 0.40), 0.075)
    return out


# name -> (generator, peak, compressed)
#
# `compressed` is false for anything the learner triggers directly: those must
# start in the same instant as the tap. True for the ceremony sounds, which
# start under a screen transition.
SOUNDS = {
    "correct_1":       (lambda: correct(0), 0.55, False),
    "correct_2":       (lambda: correct(1), 0.55, False),
    "correct_3":       (lambda: correct(2), 0.55, False),
    "combo":           (combo,              0.70, False),
    "wrong":           (wrong,              0.45, False),
    "lesson_complete": (lesson_complete,    0.80, True),
    "perfect_lesson":  (perfect_lesson,     0.85, True),
    "unit_complete":   (unit_complete,      0.92, True),
    "badge":           (badge,              0.72, True),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true",
                        help="play each sound after writing it (macOS afplay)")
    parser.add_argument("--only", help="generate just this one")
    args = parser.parse_args()

    # Stale files from a previous run would ship silently alongside the new
    # ones, and the app would happily load whichever the manifest names.
    if not args.only and OUT.exists():
        for old in list(OUT.glob("*.wav")) + list(OUT.glob("*.mp3")):
            old.unlink()

    total = 0
    for name, (make, peak, compressed) in SOUNDS.items():
        if args.only and args.only != name:
            continue
        samples = make()
        path = write(name, samples, peak, compressed)
        size = path.stat().st_size
        total += size
        seconds = len(trim(samples)) / RATE
        print(f"  {path.name:<20} {seconds:4.2f}s  {size / 1024:6.1f} KB")
        if args.preview:
            subprocess.run(["afplay", str(path)], check=False)

    print(f"\n{total / 1024:.0f} KB total → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
