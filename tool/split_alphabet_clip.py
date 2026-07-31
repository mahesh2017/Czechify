#!/usr/bin/env python3
"""Split one batched alphabet recording into the 42 per-letter clips.

Generating 42 separate letters burns a request each, which matters on a
metered TTS trial. Recording all 42 in a single take costs one request, and
the letters are separated by real pauses that ffmpeg can find.

The split is checked, not assumed: if the number of detected segments does not
equal the number of letters the run stops and reports what it found, because a
silently mis-aligned alphabet (every letter shifted by one) is far worse than a
failed split.

  python3 tool/split_alphabet_clip.py take.mp3 --gender male --dry-run
  python3 tool/split_alphabet_clip.py take.mp3 --gender male
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audio_utterances import key_for  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
LESSON = ROOT / "assets" / "curriculum" / "lessons" / "unit01_lesson00.json"


def _alphabet_items() -> list[dict]:
    lesson = json.loads(LESSON.read_text(encoding="utf-8"))
    for exercise in lesson.get("exercises", []):
        items = (exercise.get("data", {}) or {}).get("items") or []
        if items and "name_say" in (items[0] or {}):
            return items
    raise SystemExit("No alphabet items found in unit01_lesson00.json")


def letter_names() -> list[str]:
    """The name_say values, in card order — the text the clips must match."""
    return [item["name_say"] for item in _alphabet_items()]


def example_words() -> list[str]:
    """The `say` values — the word spoken under each letter, in card order."""
    return [item["say"] for item in _alphabet_items() if item.get("say")]


def detect_segments(source: Path, noise_db: float, min_silence: float
                    ) -> list[tuple[float, float]]:
    """Speech spans, derived from the gaps ffmpeg reports between them."""
    result = subprocess.run(
        ["ffmpeg", "-i", str(source), "-af",
         f"silencedetect=noise={noise_db}dB:d={min_silence}", "-f", "null", "-"],
        capture_output=True, text=True,
    )
    log = result.stderr
    starts = [float(m) for m in re.findall(r"silence_start:\s*(-?[\d.]+)", log)]
    ends = [float(m) for m in re.findall(r"silence_end:\s*(-?[\d.]+)", log)]
    duration_match = re.search(r"Duration:\s*(\d+):(\d+):([\d.]+)", log)
    if not duration_match:
        raise SystemExit("ffmpeg could not read the file duration")
    h, m, s = duration_match.groups()
    total = int(h) * 3600 + int(m) * 60 + float(s)

    # Speech runs from the end of each silence to the start of the next one.
    boundaries = sorted(ends + [0.0])
    segments = []
    for index, begin in enumerate(boundaries):
        following = [x for x in starts if x > begin]
        finish = min(following) if following else total
        if finish - begin > 0.05:
            segments.append((begin, finish))
    return segments


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="the single batched recording")
    parser.add_argument("--gender", choices=("female", "male"), required=True)
    parser.add_argument(
        "--words", action="store_true",
        help="split against the 42 example words (matka, káva, …) rather than "
             "the letter names")
    parser.add_argument(
        "--texts", nargs="+",
        help="split against these exact strings instead of the whole card, in "
             "the order they were recorded — for re-doing individual letters",
    )
    parser.add_argument("--noise", type=float, default=-40.0,
                        help="dB below which audio counts as silence")
    parser.add_argument("--min-silence", type=float, default=0.25,
                        help="seconds of quiet that separate two letters")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    names = args.texts or (example_words() if args.words else letter_names())
    if args.texts or args.words:
        # A typo here would file good audio under a key nothing looks up, so
        # the strings are checked against the card before anything is written.
        valid = set(letter_names()) | set(example_words())
        unknown = [n for n in names if n not in valid]
        if unknown:
            print(f"Not on the alphabet card: {unknown}", file=sys.stderr)
            return 1
    segments = detect_segments(args.source, args.noise, args.min_silence)
    print(f"{len(names)} letters expected, {len(segments)} segments detected.")

    if len(segments) != len(names):
        # Aligning the wrong audio to the wrong letter is undetectable later,
        # so this is a hard stop with the knobs that fix it.
        print("\nCounts differ — not writing anything. Adjust and re-run:\n"
              "  too few  -> raise --noise (e.g. -35) or lower --min-silence\n"
              "  too many -> lower --noise (e.g. -45) or raise --min-silence",
              file=sys.stderr)
        for index, (begin, finish) in enumerate(segments[:50], 1):
            print(f"  {index:02d}  {begin:7.2f} -> {finish:7.2f}"
                  f"  ({finish - begin:.2f}s)", file=sys.stderr)
        return 1

    for name, (begin, finish) in zip(names, segments):
        target = AUDIO / f"{args.gender}_{key_for(name)}.mp3"
        span = finish - begin
        print(f"  {name:<18} {span:5.2f}s  ->  {target.name}")
        if args.dry_run:
            continue
        # A little padding either side so the consonant onset is not clipped.
        subprocess.run(
            ["ffmpeg", "-y", "-ss", str(max(0.0, begin - 0.05)),
             "-t", str(span + 0.1), "-i", str(args.source),
             "-af", "loudnorm=I=-18:TP=-2:LRA=11",
             "-c:a", "libmp3lame", "-b:a", "48k", "-ar", "24000", str(target)],
            capture_output=True, check=True,
        )

    if args.dry_run:
        print("\nDry run — nothing written.")
    else:
        print(f"\nWrote {len(names)} clips to assets/audio/.")
        print("Upload with: python3 tool/upload_audio_pack.py --skip-existing")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
