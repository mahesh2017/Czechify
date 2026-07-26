#!/usr/bin/env python3
"""Find and re-synthesize clips the neural voice rendered near-silent.

cs-CZ-AntoninNeural returns almost no signal for isolated vowels: "a" came
back at -55 dB peak where a healthy clip peaks near -8 dB, so the Unit 1
alphabet had letters that simply could not be heard. The response is
deterministic — a fresh request returns byte-identical silence — so it is a
property of the voice on single characters rather than a transmission fault.

Two changes fix it:

  * `<say-as interpret-as="characters">` for single letters, which makes the
    voice name the letter instead of degenerating. This lifts "a" from -55 dB
    to -21 dB peak.
  * loudnorm afterwards, bringing it to about -2 dB peak, in line with the
    rest of the pack.

Multi-character text is re-synthesized plainly — spelling a word out letter by
letter would be worse than quiet.

Usage:
  python3 tool/repair_quiet_clips.py --dry-run
  python3 tool/repair_quiet_clips.py
"""

from __future__ import annotations

import argparse
import glob
import html
import json
import os
import re
import subprocess
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audio_utterances import synthesis_plan  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"

VOICES = {"female": "cs-CZ-VlastaNeural", "male": "cs-CZ-AntoninNeural"}

# Healthy clips peak near -7..-10 dB; anything this quiet is inaudible in a
# noisy room even at full volume.
QUIET_PEAK_DB = -25.0


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


def peak_db(path: str) -> float:
    out = subprocess.run(
        ["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    match = re.search(r"max_volume:\s*(-?[\d.]+) dB", out)
    return float(match.group(1)) if match else 0.0


def synthesize(text: str, voice: str, destination: Path, key: str, region: str) -> None:
    # A single character makes the neural voice degenerate; naming it as a
    # character is what restores real signal.
    if len(text.strip()) == 1:
        body = f"<say-as interpret-as='characters'>{html.escape(text)}</say-as>"
    else:
        body = html.escape(text)
    ssml = (
        f"<speak version='1.0' xml:lang='cs-CZ'><voice name='{voice}'>"
        f"<prosody rate='-8%'>{body}</prosody></voice></speak>"
    ).encode("utf-8")
    request = urllib.request.Request(
        f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml, method="POST",
    )
    request.add_header("Ocp-Apim-Subscription-Key", key)
    request.add_header("Content-Type", "application/ssml+xml")
    request.add_header("X-Microsoft-OutputFormat", "audio-24khz-48kbitrate-mono-mp3")
    raw = destination.with_suffix(".raw.mp3")
    with urllib.request.urlopen(request, timeout=30) as response:
        raw.write_bytes(response.read())

    # Even with say-as these sit well below the pack; normalise so one letter
    # is not noticeably quieter than the word on the next row.
    result = subprocess.run(
        ["ffmpeg", "-y", "-i", str(raw), "-af", "loudnorm=I=-18:TP=-2:LRA=11",
         "-c:a", "libmp3lame", "-b:a", "48k", "-ar", "24000", str(destination)],
        capture_output=True,
    )
    raw.unlink(missing_ok=True)
    if result.returncode != 0 or not destination.exists():
        raise RuntimeError("loudnorm failed")


def main() -> int:
    load_env_file()
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--threshold", type=float, default=QUIET_PEAK_DB)
    args = parser.parse_args()

    texts = {key: text for key, text, _ in synthesis_plan()}
    files = sorted(glob.glob(str(AUDIO / "*.mp3")))
    print(f"Scanning {len(files)} clips…")

    with ThreadPoolExecutor(max_workers=10) as pool:
        peaks = list(pool.map(lambda p: (p, peak_db(p)), files))

    quiet = []
    for path, peak in peaks:
        if peak >= args.threshold:
            continue
        name = os.path.basename(path)
        gender, _, rest = name.partition("_")
        digest = rest.replace(".mp3", "")
        text = texts.get(digest)
        if gender in VOICES and text:
            quiet.append((path, gender, text, peak))

    print(f"{len(quiet)} clips below {args.threshold} dB peak.")
    for _, gender, text, peak in sorted(quiet, key=lambda q: q[3])[:20]:
        print(f"   {gender:<7} {text[:32]:<34} {peak:7.1f} dB")
    if args.dry_run or not quiet:
        return 0

    key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not key or not region:
        print("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION.", file=sys.stderr)
        return 2

    fixed = failed = 0
    for path, gender, text, before in quiet:
        try:
            synthesize(text, VOICES[gender], Path(path), key, region)
            after = peak_db(path)
            ok = after >= args.threshold
            fixed += ok
            failed += not ok
            print(f"   {text[:24]:<26} {before:7.1f} -> {after:7.1f} dB "
                  f"{'ok' if ok else 'STILL QUIET'}")
        except Exception as error:  # noqa: BLE001
            failed += 1
            print(f"   {text[:24]:<26} failed: {error}", file=sys.stderr)

    print(f"\nRepaired {fixed}; {failed} still need attention.")
    print("Upload with: python3 tool/upload_audio_pack.py --skip-existing")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
