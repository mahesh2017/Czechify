#!/usr/bin/env python3
"""Synthesize the English unit-intro narration with Azure neural voices.

The intros are the one thing a learner hears before anything else in a unit,
and they were still using the device's built-in English voice while every Czech
phrase had studio-quality neural audio. The mismatch is audible.

Clips are named `en{gender}_{sha256}.mp3` so they share the `course-audio`
bucket with the Czech pack without colliding, and still satisfy the app's
`^[a-z]+_[0-9a-f]{64}\\.mp3$` download guard. They are listed in their own
manifest_en.json because the Czech manifest is single-locale by design.

Requires AZURE_SPEECH_KEY and AZURE_SPEECH_REGION unless --dry-run.
"""

from __future__ import annotations

import argparse
import glob
import hashlib
import html
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS = ROOT / "assets" / "curriculum" / "lessons"
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest_en.json"

# Warm, conversational narration voices rather than the flat newsreader
# defaults — these introduce a unit and set its tone.
VOICES = {
    "female": "en-US-AvaNeural",
    "male": "en-US-AndrewNeural",
}


def key_for(text: str) -> str:
    """Must match EnglishTts's lookup: trimmed, lowercased, sha256."""
    return hashlib.sha256(text.strip().lower().encode("utf-8")).hexdigest()


def extract_intros() -> list[str]:
    found: set[str] = set()
    for path in sorted(LESSONS.glob("*.json")):
        lesson = json.loads(path.read_text(encoding="utf-8"))
        for exercise in lesson.get("exercises", []):
            intro = (exercise.get("data", {}) or {}).get("intro")
            if isinstance(intro, str) and intro.strip():
                found.add(intro.strip())
    return sorted(found)


def synthesize(text: str, destination: Path, key: str, region: str, voice: str) -> None:
    endpoint = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    # Slightly slowed: this is teaching narration for non-native listeners.
    ssml = (
        "<speak version='1.0' xml:lang='en-US'>"
        f"<voice name='{html.escape(voice)}'><prosody rate='-6%'>"
        f"{html.escape(text)}</prosody></voice></speak>"
    ).encode("utf-8")
    request = urllib.request.Request(endpoint, data=ssml, method="POST")
    request.add_header("Ocp-Apim-Subscription-Key", key)
    request.add_header("Content-Type", "application/ssml+xml")
    request.add_header("X-Microsoft-OutputFormat", "audio-24khz-48kbitrate-mono-mp3")
    request.add_header("User-Agent", "ceskina-pro-intro-audio")
    with urllib.request.urlopen(request, timeout=60) as response:
        audio = response.read()
    if not audio:
        raise RuntimeError("Azure returned an empty audio body")
    destination.write_bytes(audio)


def load_env_file() -> None:
    """Read AZURE_* from a gitignored .env so keys are supplied once."""
    path = ROOT / ".env"
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def main() -> int:
    load_env_file()
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true",
                        help="re-synthesize clips that already exist")
    parser.add_argument("--rate", type=float, default=100.0,
                        help="max requests/minute (Azure free tier allows ~20)")
    args = parser.parse_args()

    intros = extract_intros()
    chars = sum(len(t) for t in intros)
    print(f"{len(intros)} intro scripts, {chars:,} characters per voice "
          f"({2 * chars:,} for both).")
    if args.dry_run:
        for text in intros[:3]:
            print(f"  {key_for(text)[:12]}…  {text[:70]}…")
        return 0

    speech_key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not speech_key or not region:
        print("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION.", file=sys.stderr)
        return 2

    AUDIO.mkdir(parents=True, exist_ok=True)
    min_interval = 60.0 / args.rate if args.rate > 0 else 0.0
    last_call = 0.0
    voices_out: dict[str, dict] = {}

    for gender, voice in VOICES.items():
        entries: dict[str, str] = {}
        for index, text in enumerate(intros, 1):
            digest = key_for(text)
            filename = f"en{gender}_{digest}.mp3"
            destination = AUDIO / filename
            if args.force and destination.exists():
                destination.unlink()

            if not destination.exists() or destination.stat().st_size == 0:
                for attempt in range(5):
                    wait = min_interval - (time.monotonic() - last_call)
                    if wait > 0:
                        time.sleep(wait)
                    try:
                        last_call = time.monotonic()
                        synthesize(text, destination, speech_key, region, voice)
                        break
                    except urllib.error.HTTPError as error:
                        if error.code == 429:
                            time.sleep(float(error.headers.get("Retry-After") or 5))
                            continue
                        raise
                    except (urllib.error.URLError, TimeoutError, RuntimeError) as error:
                        if destination.exists() and destination.stat().st_size == 0:
                            destination.unlink()
                        if attempt == 4:
                            print(f"Failed: {text[:40]}…: {error}", file=sys.stderr)
                            break
                        time.sleep(2 ** attempt)

            if destination.exists() and destination.stat().st_size > 0:
                entries[digest] = f"assets/audio/{filename}"
            print(f"  [{gender} {index}/{len(intros)}] {text[:52]}…")

        voices_out[gender] = {"name": voice, "entries": dict(sorted(entries.items()))}

    MANIFEST.write_text(
        json.dumps({"version": 1, "locale": "en-US", "voices": voices_out},
                   ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    total = sum(len(v["entries"]) for v in voices_out.values())
    print(f"\nWrote {MANIFEST.name}: {total} clips across {len(VOICES)} voices.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
