#!/usr/bin/env python3
"""Synthesize part of the male pack with ElevenLabs instead of Azure.

cs-CZ-AntoninNeural is the only Czech male voice Azure offers and it fails
measurably on short input — 14 of the 42 alphabet letters came back unusable.
ElevenLabs handled all 42 on the first take, so this regenerates the male
clips a learner actually meets, starting with A1.

Billing is per character, so there is nothing to gain from batching several
utterances into one request — and a lot to lose, since splitting connected
speech on silence is far less reliable than splitting isolated letters. One
request per utterance, resumable, with the spend printed before anything is
sent.

Clips keep the same content-addressed names, so this drops straight into the
existing pack and the app needs no change.

  python3 tool/generate_eleven_pack.py --scope a2 --dry-run
  python3 tool/generate_eleven_pack.py --unit 4 --unit 5 --dry-run
  python3 tool/generate_eleven_pack.py --scope a2 --limit 20
  python3 tool/generate_eleven_pack.py --scope a2
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_utterances as au  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"

OLIVER = "daJ4gHLkIVFskWuoLuDX"
MODEL = os.environ.get("ELEVENLABS_MODEL", "eleven_v3")

# Which clips are already Oliver. The filename is a hash of the *text*, so an
# Azure clip and an ElevenLabs clip of the same phrase are indistinguishable on
# disk — without this ledger a run interrupted by an exhausted quota would
# restart from the top and pay for everything a second time.
LEDGER = AUDIO / "eleven_done.json"

# The unit ids the curriculum files mark as phase a1. A2 is the complement
# among the course units, so it stays correct when new A2 units are added.
def load_env_file() -> None:
    path = ROOT / ".env"
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        if key.strip() and key.strip() not in os.environ:
            os.environ[key.strip()] = value.strip().strip('"').strip("'")


def scoped_utterances(
    scope: str, unit_ids: set[int] | None = None,
) -> dict[str, str]:
    """Compatibility wrapper around the shared curriculum scope rule."""
    return au.scoped_utterances(scope, unit_ids)


def spoken_for_eleven(text: str) -> str:
    """ElevenLabs takes plain text, not SSML.

    Fill-in-the-blank prompts still need the gap voiced — dropping it leaves
    "To je ___ pes." sounding like the complete-but-wrong "To je pes." An
    ellipsis is the plain-text equivalent of the <break> used for Azure.
    """
    return au.BLANK_PATTERN.sub("...", text) if hasattr(au, "BLANK_PATTERN") \
        else text.replace("___", "...")


# v3 is expressive, so an unseeded request varies run to run — about 3% in
# duration on a full sentence, more on very short ones. A fixed seed makes the
# pack reproducible: regenerating one clip later matches the rest instead of
# arriving at a different pace from its neighbours.
SEED = int(os.environ.get("ELEVENLABS_SEED", "42"))


def speech_seconds(path: Path) -> float:
    """Duration with silence stripped.

    Raw file length is useless for judging pace: Azure pads every clip with
    roughly a second of silence, which made ElevenLabs look 39% faster when it
    is in fact slower on everything but single words.
    """
    trimmed = path.with_suffix(".trim.wav")
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(path), "-af",
         "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0:"
         "stop_periods=-1:stop_threshold=-45dB:stop_silence=0.05",
         str(trimmed)], capture_output=True, check=True)
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(trimmed)],
        capture_output=True, text=True).stdout.strip()
    trimmed.unlink(missing_ok=True)
    # "N/A" when the trimmed file has no measurable duration; never crash a
    # long run over it.
    try:
        return float(out)
    except ValueError:
        return 0.0


# Roughly how long a syllable takes at teaching pace. v3 clips very short input
# — "Ano" came back at 0.17s against Azure's 0.37s — and a word that fast is
# useless on a card a learner is trying to repeat. Anything under this is
# recorded for review rather than silently shipped.
MIN_SECONDS_PER_CHAR = 0.055
MIN_SECONDS = 0.30
# Calibrated so Azure's "Ano" (0.37s of speech) passes and ElevenLabs' 0.17s
# version does not, while every longer clip in both packs passes comfortably.
TOLERANCE = 0.8


def is_clipped(text: str, path: Path) -> bool:
    expected = max(MIN_SECONDS, MIN_SECONDS_PER_CHAR * len(text.strip()))
    return speech_seconds(path) < TOLERANCE * expected


def synthesize(text: str, destination: Path, key: str) -> None:
    body = {"text": spoken_for_eleven(text), "model_id": MODEL, "seed": SEED}
    url = (f"https://api.elevenlabs.io/v1/text-to-speech/{OLIVER}"
           "?output_format=mp3_44100_128")
    request = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"), method="POST")
    request.add_header("xi-api-key", key)
    request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=120) as response:
        audio = response.read()
    if not audio:
        raise RuntimeError("ElevenLabs returned an empty body")
    destination.write_bytes(audio)


def main() -> int:
    load_env_file()
    parser = argparse.ArgumentParser()
    parser.add_argument("--scope", choices=("a1", "a2", "all"), default="a1")
    parser.add_argument(
        "--unit", action="append", type=int, dest="units",
        help="synthesize only this curriculum unit; repeat for multiple units",
    )
    parser.add_argument(
        "--min-chars", type=int, default=0,
        help="skip utterances shorter than this. v3 clips very short input — "
             "'Ano' came back at 0.17s against Azure's 0.37s — so short items "
             "are better recorded in a batched take and split in separately.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int,
                        help="stop after N clips — use this to sample the "
                             "voice before committing the whole spend")
    parser.add_argument("--force", action="store_true",
                        help="re-synthesize clips that already exist")
    parser.add_argument(
        "--texts", nargs="+",
        help="re-synthesize only these exact utterances (use with --force)",
    )
    parser.add_argument("--rate", type=float, default=60.0,
                        help="max requests per minute")
    args = parser.parse_args()

    items = scoped_utterances(
        args.scope, set(args.units) if args.units else None,
    )
    if args.texts:
        requested = set(args.texts)
        items = {k: t for k, t in items.items() if t in requested}
        missing = requested - set(items.values())
        if missing:
            scope_label = (
                f"units {sorted(set(args.units))}" if args.units else args.scope
            )
            print(f"Requested text not in {scope_label}: {sorted(missing)}",
                  file=sys.stderr)
    if args.min_chars:
        held = {k: t for k, t in items.items() if len(t.strip()) < args.min_chars}
        items = {k: t for k, t in items.items() if len(t.strip()) >= args.min_chars}
        print(f"--min-chars {args.min_chars}: holding back {len(held)} short "
              f"utterances for a batched take")
        (AUDIO / "eleven_short.json").write_text(
            json.dumps(sorted(held.values()), ensure_ascii=False, indent=2),
            encoding="utf-8")
    chars = sum(len(t) for t in items.values())
    try:
        already = set(json.loads(LEDGER.read_text(encoding="utf-8")))
    except (FileNotFoundError, json.JSONDecodeError):
        already = set()
    pending = {k: t for k, t in items.items()
               if args.force or k not in already
               or not (AUDIO / f"male_{k}.mp3").exists()}
    if args.force:
        pending = dict(items)

    scope_label = (
        f"units {sorted(set(args.units))}" if args.units else f"scope {args.scope}"
    )
    print(f"{scope_label}: {len(items)} clips, {chars:,} characters")
    print(f"already Oliver: {len(already & set(items))}")
    print(f"to synthesize: {len(pending)}, "
          f"{sum(len(t) for t in pending.values()):,} characters")
    if args.limit:
        print(f"--limit {args.limit}: only the first {args.limit} will be sent")
    if args.dry_run:
        for key, text in list(pending.items())[:10]:
            print(f"  {key[:10]}…  {text[:60]}")
        return 0

    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("Set ELEVENLABS_API_KEY in .env", file=sys.stderr)
        return 2

    AUDIO.mkdir(parents=True, exist_ok=True)
    interval = 60.0 / args.rate if args.rate > 0 else 0.0
    last = 0.0
    done = failed = 0
    quota_hit = False
    clipped: list[str] = []

    for index, (key, text) in enumerate(pending.items(), 1):
        if args.limit and done >= args.limit:
            break
        destination = AUDIO / f"male_{key}.mp3"
        for attempt in range(4):
            wait = interval - (time.monotonic() - last)
            if wait > 0:
                time.sleep(wait)
            try:
                last = time.monotonic()
                synthesize(text, destination, api_key)
                done += 1
                if is_clipped(text, destination):
                    clipped.append(text)
                already.add(key)
                # Written every time, not at the end: a run killed by Ctrl-C or
                # an exhausted quota must not lose track of what was paid for.
                LEDGER.write_text(json.dumps(sorted(already), indent=0),
                                  encoding="utf-8")
                break
            except urllib.error.HTTPError as error:
                detail = error.read().decode("utf-8", "replace")[:200]
                if error.code == 429:
                    time.sleep(5)
                    continue
                # Running out of credits mid-run is expected on a small plan;
                # stop cleanly rather than burning through retries 1000 times.
                if error.code in (401, 402) or "quota" in detail.lower():
                    print(f"\nStopped: {error.code} {detail}", file=sys.stderr)
                    quota_hit = True
                    break
                if attempt == 3:
                    failed += 1
                    print(f"  failed {text[:32]}: {error.code} {detail}",
                          file=sys.stderr)
                time.sleep(2 ** attempt)
            except (urllib.error.URLError, TimeoutError, RuntimeError) as error:
                if destination.exists() and destination.stat().st_size == 0:
                    destination.unlink()
                if attempt == 3:
                    failed += 1
                    print(f"  failed {text[:32]}: {error}", file=sys.stderr)
                time.sleep(2 ** attempt)
        if quota_hit:
            break
        if index % 25 == 0:
            print(f"  [{done}/{len(pending)}] {text[:40]}")

    print(f"\nSynthesized {done}; {failed} failed; "
          f"{len(pending) - done - failed} left.")
    if clipped:
        report = AUDIO / "eleven_clipped.json"
        report.write_text(json.dumps(sorted(clipped), ensure_ascii=False,
                                     indent=2), encoding="utf-8")
        print(f"{len(clipped)} clip(s) came back too short to teach with — "
              f"listed in {report.name}. Re-record these in a batched take "
              f"and split them in with tool/split_alphabet_clip.py.")
        for text in clipped[:10]:
            print(f"   {text}")
    print("Refresh the manifest, then upload:")
    print("  python3 tool/generate_audio_pack.py --gender male")
    print("  python3 tool/upload_audio_pack.py --skip-existing")
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
