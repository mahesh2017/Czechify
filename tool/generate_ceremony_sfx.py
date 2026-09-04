#!/usr/bin/env python3
"""Generate the ceremony sound tier with ElevenLabs.

`generate_sfx.py` synthesizes the whole palette from sine partials. That is
right for the five sounds a learner triggers — they fire ~790 times a course,
they must be WAV to dodge MP3's ~26 ms encoder delay, and additive synthesis
gives exact control over a 40 ms mallet. It is less right for the four
ceremony sounds, which play under a screen transition, are heard rarely, and
want more body than sine partials give.

So this covers the arriving tier only. The interaction tier stays synthesized
and is not touched here.

WHAT THE EXISTING PALETTE ALREADY FIXES
---------------------------------------
Measured from assets/sfx, the palette is unambiguously **C major**:

    correct_1/2/3   C5, E5, G5      a rising C major arpeggio
    combo           C6 + G6
    badge           C6 + G5
    lesson_complete C5 + E5 + G5
    perfect_lesson  C5 + E5 + G5    same chord, longer and louder
    unit_complete   C4 + C3 + G4    the same chord dropped for weight
    wrong           F3 + C4 + D3    low and unresolved

and the loudness ladder is monotonic by design — peak 0.45 (wrong) rising
through 0.55, 0.68, 0.76, 0.81 to 0.89 (unit_complete). A learner meets these
in order, and that ordering *is* the reward system.

Both facts are constraints, not preferences, so every prompt below names C
major and the generated files are normalised back onto the ladder. Whether a
diffusion model actually lands on C is not something a prompt can guarantee —
`--report` measures what came back so a miss is visible rather than shipped.

USAGE
-----
    python3 tool/generate_ceremony_sfx.py --dry-run    # prompts + spend, no calls
    python3 tool/generate_ceremony_sfx.py              # generate into the preview dir
    python3 tool/generate_ceremony_sfx.py --report     # measure what came back
    python3 tool/generate_ceremony_sfx.py --install    # copy approved files into assets/sfx

Nothing writes to assets/sfx without --install, so a bad take cannot reach the
app by accident. Generation is resumable: a file already in the preview dir is
skipped unless --force.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "build" / "sfx_preview"
SFX = ROOT / "assets" / "sfx"
API = "https://api.elevenlabs.io/v1/sound-generation"
SUBSCRIPTION = "https://api.elevenlabs.io/v1/user/subscription"

# Shared across every prompt, so the five read as one instrument rather than
# five separate generations. The named timbres are the ones that sit closest
# to the synthesized mallet tone the interaction sounds already use.
BED = (
    "Solo acoustic mallets: warm marimba and soft vibraphone, felt-struck, "
    "close and intimate. No drums, brass, synth or reverb wash. Clean "
    "silent ending, no fade-out."
)

# The API rejects anything longer, and says so only at request time — which
# cost three of five generations the first run. Checked at import so a --dry-run
# catches it before any call is billed.
MAX_TEXT = 450

# Themes get a wider bed than the cues. A launch theme is the one place the
# app can sound like more than one instrument without breaking the palette,
# because nothing else is playing near it.
THEME_BED = (
    "Warm acoustic instruments only: marimba, vibraphone, celesta, light "
    "plucked strings. No drum kit, no brass, no synth pads, no cinematic "
    "swell. Ends resolved and fully silent, no fade-out."
)

# The launch theme is the one thing in the app that plays alone — nothing
# else is sounding within seconds of it. The single-instrument rule that the
# ceremony tier needs (those land right after a correct-answer chime) does not
# apply to it, and holding the theme to solo mallets was over-applying it.
#
# The reference ensemble is a cimbalova muzika: cimbalom, violins, viola,
# double bass, clarinet. It is both the authentic Czech folk band and,
# because the cimbalom is struck-string, still anchored to the mallet family
# the rest of the palette lives in.
RICH_BED = (
    "Played by a small live ensemble, warm and close, real acoustic "
    "instruments. Ends resolved and fully silent, no fade-out."
)

# peak is the ladder position each file has to land on, measured from the
# palette it is replacing.
CUES = {
    "arrival": dict(
        seconds=2.5,
        peak=0.72,
        text=(
            "A short warm welcome, played once. Two rising marimba notes "
            "opening into a gentle vibraphone chord in C major, unhurried, "
            "like a door opening onto a bright morning. Resolves warmly to C. "
            + BED
        ),
    ),
    "lesson_complete": dict(
        seconds=2.0,
        peak=0.76,
        text=(
            "A brief satisfied confirmation. A warm marimba arpeggio rising "
            "through a C major triad and closing on a soft vibraphone chord. "
            "Modest and everyday — pleasant, not triumphant, because it is "
            "heard often. Resolves to C. " + BED
        ),
    ),
    "perfect_lesson": dict(
        seconds=3.0,
        peak=0.81,
        text=(
            "The same warm marimba and vibraphone, brighter and lifted: a "
            "rising C major arpeggio with a light celesta shimmer as it "
            "resolves. Clearly better than an ordinary success, still gentle "
            "and acoustic. Resolves to C. " + BED
        ),
    ),
    "unit_complete": dict(
        seconds=3.5,
        peak=0.89,
        text=(
            "A warm resonant milestone. Low marimba root notes beneath a full "
            "C major chord on vibraphone with celesta shimmer above, blooming "
            "and then settling. Weighty and generous but soft-edged and "
            "acoustic throughout. Resolves to a low C. " + BED
        ),
    ),
    # Three takes on the launch signature, to be auditioned against each other
    # and narrowed to one. This is the most-heard sound in the app — a learner
    # opens it daily — so it is the one place where "catchy" is a hazard: a
    # melody you can hum is a melody you get sick of. All three are a single
    # gesture rather than a tune, and all three are the palette's own C major
    # so the app is recognisable from its first 200 ms rather than novel.
    "launch_a": dict(
        seconds=1.2,
        peak=0.66,
        text=(
            "A two-note signature, played once and never repeated. A warm "
            "marimba note stepping up to a soft vibraphone note a fifth "
            "above, in C major, ringing briefly and stopping. Confident and "
            "plain — a greeting, not a fanfare. " + BED
        ),
    ),
    "launch_b": dict(
        seconds=1.2,
        peak=0.66,
        text=(
            "One soft C major chord on vibraphone, struck once with felt and "
            "allowed to bloom and settle. No melody, no movement — a single "
            "warm breath of sound that opens and closes. " + BED
        ),
    ),
    "launch_c": dict(
        seconds=1.3,
        peak=0.66,
        text=(
            "Three quick marimba notes rising through a C major triad and "
            "landing, like a small door-chime. Brisk and light, over almost "
            "before it starts. Warm, never bright or piercing. " + BED
        ),
    ),
    # Full launch themes, the game-style read of "welcome music". Longer and
    # actually melodic, where the launch_* cues are single gestures. They play
    # over the loading screen and on into Home — the dwell there depends on DB
    # seeding, so nothing here may depend on a screen still being up.
    "theme_a": dict(
        seconds=5.0,
        peak=0.72,
        text=(
            "A short warm welcome theme, played once. A gentle marimba melody "
            "in C major rising over a soft vibraphone bed, unhurried and "
            "friendly, settling onto a final chord. Encouraging rather than "
            "grand — the feeling of sitting down to something you enjoy. "
            + THEME_BED
        ),
    ),
    "theme_b": dict(
        seconds=5.0,
        peak=0.72,
        text=(
            "A short welcome theme with a light Central European folk lilt, "
            "in a gentle three-beat sway. Marimba and plucked strings trade a "
            "simple warm melody in C major and resolve together. Charming and "
            "hand-made, never grand or touristy. " + THEME_BED
        ),
    ),
    "theme_c": dict(
        seconds=6.0,
        peak=0.72,
        text=(
            "A warm welcome theme that opens up. Marimba states a simple C "
            "major phrase, celesta answers above it, and soft sustained "
            "strings lift underneath before everything resolves together. "
            "Generous and inviting, still gentle. " + THEME_BED
        ),
    ),
    # A spread around theme_b, the Central European read. Same prompt gives a
    # different take every call, and this is the app's signature, so it is
    # worth several — but they also probe different amounts of folk, because
    # the failure mode here is souvenir-shop rather than dull.
    #
    # The cimbalom is the reason this direction can work at all: Czech folk's
    # signature instrument is a hammered dulcimer, so it is struck-string, and
    # it sits inside the mallet family the palette is already built from
    # instead of arriving from somewhere else.
    "theme_b1": dict(
        seconds=5.0,
        peak=0.72,
        text=(
            "A short welcome theme with a gentle Central European folk lilt "
            "in three. A cimbalom hammered dulcimer carries a simple warm "
            "melody in C major with marimba beneath it, and they resolve "
            "together. Hand-made and affectionate, never touristy. "
            + THEME_BED
        ),
    ),
    "theme_b2": dict(
        seconds=5.0,
        peak=0.72,
        text=(
            "A sparse welcome theme in a slow three-beat sway. A few cimbalom "
            "notes in C major over a quiet marimba pulse, plenty of air "
            "between them, resolving simply. Restrained and intimate — folk "
            "colour by suggestion, not by costume. " + THEME_BED
        ),
    ),
    "theme_b3": dict(
        seconds=5.5,
        peak=0.72,
        text=(
            "A warm Bohemian folk welcome in three. Cimbalom and a single "
            "soft violin trade a simple singing melody in C major over "
            "plucked strings, lifting once and settling. Village dance at "
            "half speed — affectionate and unhurried. " + THEME_BED
        ),
    ),
    "theme_b4": dict(
        seconds=5.0,
        peak=0.72,
        text=(
            "A short welcome theme in three, Central European in colour but "
            "modern: cimbalom and marimba in C major over soft sustained "
            "strings, a clear singable phrase that rises and resolves. "
            "Polished and warm, a title theme rather than a field recording. "
            + THEME_BED
        ),
    ),
    # Full-ensemble launch themes. Short, C major, and written around a hook
    # rather than a texture — "catchy" is the brief here, and these are the
    # only sounds in the app allowed to try for it.
    "rich_a": dict(
        seconds=5.0,
        peak=0.72,
        text=(
            "A short warm welcome played by a Czech cimbalom band: cimbalom, "
            "two violins, viola and plucked double bass, with a clarinet "
            "singing a clear four-note hook in C major over the top. Gentle "
            "three-beat sway, lifts once and resolves together. Affectionate "
            "and alive. " + RICH_BED
        ),
    ),
    "rich_b": dict(
        seconds=5.0,
        peak=0.72,
        text=(
            "A bright memorable welcome theme in C major. A clarinet and "
            "violin carry a catchy singable phrase together over shimmering "
            "cimbalom, pizzicato double bass and a light tambourine pulse. "
            "Folk-rooted but polished, the opening titles of something you "
            "are glad to see. " + RICH_BED
        ),
    ),
    "rich_c": dict(
        seconds=4.5,
        peak=0.72,
        text=(
            "A quick, joyful welcome in C major with a strong hook. Violin "
            "and clarinet answer each other over fast cimbalom tremolo and "
            "walking pizzicato bass, warm strings filling underneath, ending "
            "on one bright resolved chord. Central European, spirited, over "
            "quickly. " + RICH_BED
        ),
    ),
    "rich_d": dict(
        seconds=6.0,
        peak=0.72,
        text=(
            "A generous welcome theme in C major that opens out. Cimbalom "
            "and celesta state a simple hook, a small string section and a "
            "warm clarinet lift it, and the whole ensemble resolves together. "
            "Cinematic warmth with a Central European accent, never brassy or "
            "loud. " + RICH_BED
        ),
    ),
    "badge": dict(
        seconds=1.5,
        peak=0.68,
        text=(
            "A small bright punctuation. Two quick celesta notes in C major, "
            "light and glassy, like a tiny chime. Very short and understated "
            "— a footnote, not an event, because it queues behind a larger "
            "sound. " + BED
        ),
    ),
}

# 0.3 is the API default and drifts freely; these prompts carry specific
# instrument and key instructions that are the whole point of them.
for _name, _spec in CUES.items():
    if len(_spec["text"]) > MAX_TEXT:
        raise SystemExit(
            f"prompt for {_name} is {len(_spec['text'])} characters; "
            f"the API caps text at {MAX_TEXT}"
        )

PROMPT_INFLUENCE = 0.6
OUTPUT_FORMAT = "mp3_44100_128"


def load_env() -> None:
    env = ROOT / ".env"
    if not env.exists():
        return
    for line in env.read_text().splitlines():
        if line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        if key and key not in os.environ:
            os.environ[key] = value.strip().strip('"').strip("'")


def request_json(url: str, api_key: str):
    req = urllib.request.Request(url, headers={"xi-api-key": api_key})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def synthesize(name: str, spec: dict, api_key: str, destination: Path) -> None:
    body = json.dumps(
        {
            "text": spec["text"],
            "duration_seconds": spec["seconds"],
            "prompt_influence": PROMPT_INFLUENCE,
            "output_format": OUTPUT_FORMAT,
            "loop": False,
        }
    ).encode()
    req = urllib.request.Request(
        API,
        data=body,
        headers={"xi-api-key": api_key, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as response:
        audio = response.read()
    destination.write_bytes(audio)


def decode(path: Path):
    """Mono float samples plus sample rate, via ffmpeg for the mp3s."""
    import numpy as np

    if path.suffix == ".wav":
        with wave.open(str(path)) as w:
            frames = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
            if w.getnchannels() > 1:
                frames = frames.reshape(-1, w.getnchannels()).mean(axis=1)
            return frames.astype(float) / 32768.0, w.getframerate()
    tmp = Path(tempfile.mktemp(suffix=".wav"))
    subprocess.run(
        ["ffmpeg", "-v", "quiet", "-y", "-i", str(path), "-ac", "1", str(tmp)],
        check=True,
    )
    try:
        return decode(tmp)
    finally:
        tmp.unlink(missing_ok=True)


def measure(path: Path):
    import numpy as np

    samples, rate = decode(path)
    window = samples[: int(rate * 0.4)]
    window = window * np.hanning(len(window))
    spectrum = np.abs(np.fft.rfft(window, 1 << 16))
    freqs = np.fft.rfftfreq(1 << 16, 1 / rate)
    spectrum = spectrum * ((freqs > 80) & (freqs < 4000))

    partials = []
    for index in np.argsort(spectrum)[::-1]:
        if len(partials) >= 3:
            break
        if all(abs(freqs[index] - other) > 25 for other in partials):
            partials.append(float(freqs[index]))
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    def naming(freq: float) -> str:
        midi = round(12 * np.log2(freq / 440.0)) + 69
        return f"{names[midi % 12]}{midi // 12 - 1}"

    return {
        "seconds": len(samples) / rate,
        "peak": float(np.abs(samples).max()),
        "rms_db": float(20 * np.log10(max(np.sqrt(np.mean(samples**2)), 1e-9))),
        "partials": [(round(f, 1), naming(f)) for f in partials],
        "in_c_major": [naming(f)[:-1] for f in partials],
    }


def normalise(path: Path, target_peak: float) -> None:
    """Put the file back on the palette's loudness ladder."""
    import numpy as np

    samples, rate = decode(path)
    current = float(np.abs(samples).max())
    if current <= 0:
        return
    scaled = np.clip(samples * (target_peak / current), -1, 1)
    tmp = Path(tempfile.mktemp(suffix=".wav"))
    with wave.open(str(tmp), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((scaled * 32767).astype("<i2").tobytes())
    subprocess.run(
        ["ffmpeg", "-v", "quiet", "-y", "-i", str(tmp), "-b:a", "128k", str(path)],
        check=True,
    )
    tmp.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--only", action="append", choices=sorted(CUES))
    args = parser.parse_args()

    wanted = args.only or list(CUES)
    PREVIEW.mkdir(parents=True, exist_ok=True)

    if args.report:
        print(f"{'file':<18} {'dur':>5} {'peak':>5} {'RMS dB':>7}  partials")
        for name in wanted:
            path = PREVIEW / f"{name}.mp3"
            if not path.exists():
                print(f"{name:<18} (not generated)")
                continue
            m = measure(path)
            chord = "/".join(m["in_c_major"])
            print(
                f"{name:<18} {m['seconds']:5.2f} {m['peak']:5.2f} "
                f"{m['rms_db']:7.1f}  {chord:<12} "
                + " ".join(f"{f}Hz {n}" for f, n in m["partials"])
            )
        return 0

    if args.install:
        missing = [n for n in wanted if not (PREVIEW / f"{n}.mp3").exists()]
        if missing:
            sys.exit(f"not generated yet: {', '.join(missing)}")
        for name in wanted:
            shutil.copy2(PREVIEW / f"{name}.mp3", SFX / f"{name}.mp3")
            print(f"installed {name}.mp3")
        print("\nassets/sfx updated. arrival.mp3 is new — wire it up in Sfx.")
        return 0

    if args.dry_run:
        total = sum(CUES[n]["seconds"] for n in wanted)
        for name in wanted:
            spec = CUES[name]
            print(
                f"\n=== {name}.mp3  ({spec['seconds']}s, target peak "
                f"{spec['peak']}, {len(spec['text'])}/{MAX_TEXT} chars) ==="
            )
            print(spec["text"])
        print(
            f"\n{len(wanted)} generations, {total:.1f}s of audio, "
            f"prompt_influence={PROMPT_INFLUENCE}, format={OUTPUT_FORMAT}"
        )
        print("No API calls made.")
        return 0

    load_env()
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        sys.exit("Set ELEVENLABS_API_KEY in .env")

    try:
        sub = request_json(SUBSCRIPTION, api_key)
        used, limit = sub.get("character_count"), sub.get("character_limit")
        print(f"plan {sub.get('tier')}: {used}/{limit} credits used before this run")
    except Exception as error:  # noqa: BLE001 - informational only
        print(f"(could not read subscription: {error})")

    for name in wanted:
        spec = CUES[name]
        destination = PREVIEW / f"{name}.mp3"
        if destination.exists() and not args.force:
            print(f"skip {name} (already generated; --force to replace)")
            continue
        print(f"generating {name} ({spec['seconds']}s) ...", end=" ", flush=True)
        try:
            synthesize(name, spec, api_key, destination)
        except urllib.error.HTTPError as error:
            print(f"FAILED {error.code}: {error.read()[:300]!r}")
            continue
        normalise(destination, spec["peak"])
        print(f"{destination.stat().st_size / 1024:.0f} KB")

    try:
        sub = request_json(SUBSCRIPTION, api_key)
        print(f"\n{sub.get('character_count')}/{sub.get('character_limit')} credits used after")
    except Exception:  # noqa: BLE001
        pass
    print(f"\nPreview files in {PREVIEW.relative_to(ROOT)}")
    print("Listen, then: python3 tool/generate_ceremony_sfx.py --report --install")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
