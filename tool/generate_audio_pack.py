#!/usr/bin/env python3
"""Extract Czech utterances and synthesize a deterministic Azure audio pack.

Requires AZURE_SPEECH_KEY and AZURE_SPEECH_REGION unless --dry-run is used.
The script is resumable: existing non-empty MP3s are retained.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
LESSONS = ROOT / "assets" / "curriculum" / "lessons"
VOCABULARY = ROOT / "assets" / "vocabulary"
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"
PREVIEW_TEXT = "Ahoj, jak se máš?"


# Kept identical to TextNormalizer.forSpeech in the app so a pre-generated clip
# and a runtime speak() request resolve to the same hash. Removes fill-in-the-
# blank markers ("___", read aloud as "podtržítko") and parenthetical hints.
_PARENS = re.compile(r"\([^)]*\)")
_BLANKS = re.compile(r"_+")
_SPACES = re.compile(r"\s+")
_PUNCT = re.compile(r"\s+([.,!?;:])")


def speech_text(text: str) -> str:
    text = _PARENS.sub(" ", text)
    text = _BLANKS.sub(" ", text)
    text = _SPACES.sub(" ", text)
    text = _PUNCT.sub(r"\1", text)
    return text.strip()


def normalized(text: str) -> str:
    return speech_text(text).strip().lower()


def key_for(text: str) -> str:
    return hashlib.sha256(normalized(text).encode("utf-8")).hexdigest()


def extract_utterances() -> list[str]:
    utterances: set[str] = {PREVIEW_TEXT}  # Settings voice preview.

    for path in sorted(VOCABULARY.glob("*.json")):
        for row in json.loads(path.read_text(encoding="utf-8")):
            for field in ("word_cz", "example_cz"):
                value = row.get(field)
                if isinstance(value, str) and value.strip():
                    utterances.add(value.strip())

    # These are the curriculum values passed to CzechTts at runtime.
    for path in sorted(LESSONS.glob("*.json")):
        lesson = json.loads(path.read_text(encoding="utf-8"))
        for exercise in lesson.get("exercises", []):
            data = exercise.get("data", {})
            for field in ("expected_text", "target_text", "question_cz"):
                value = data.get(field)
                if isinstance(value, str) and value.strip():
                    utterances.add(value.strip())

    # Collapse case-only duplicates using exactly the app's lookup rule, and
    # store the *sanitized* text so what we synthesize matches the runtime
    # request (and never contains "___" or "(hint)").
    by_key: dict[str, str] = {}
    for text in sorted(utterances):
        spoken = speech_text(text)
        if spoken:
            by_key[key_for(text)] = spoken
    ordered = [by_key[key] for key in sorted(by_key)]
    # A limited trial must always contain the phrase used by Settings → Test
    # voice; otherwise the apparent voice comparison silently uses device TTS.
    ordered.remove(PREVIEW_TEXT)
    return [PREVIEW_TEXT, *ordered]


def synthesize(text: str, destination: Path, key: str, region: str, voice: str) -> None:
    endpoint = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    ssml = (
        "<speak version='1.0' xml:lang='cs-CZ'>"
        f"<voice name='{html.escape(voice)}'><prosody rate='-8%'>"
        f"{html.escape(text)}</prosody></voice></speak>"
    ).encode("utf-8")
    request = urllib.request.Request(endpoint, data=ssml, method="POST")
    request.add_header("Ocp-Apim-Subscription-Key", key)
    request.add_header("Content-Type", "application/ssml+xml")
    request.add_header("X-Microsoft-OutputFormat", "audio-24khz-48kbitrate-mono-mp3")
    request.add_header("User-Agent", "ceskina-pro-audio-pack")
    with urllib.request.urlopen(request, timeout=30) as response:
        destination.write_bytes(response.read())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="extract only; do not call Azure")
    parser.add_argument("--gender", choices=("female", "male"), default="female")
    parser.add_argument("--voice", help="override the Azure voice name")
    parser.add_argument("--limit", type=int, help="synthesize only the first N missing files")
    args = parser.parse_args()

    texts = extract_utterances()
    if args.dry_run:
        print(f"Found {len(texts)} unique Czech utterances.")
        for text in texts[:20]:
            print(f"{key_for(text)}  {text}")
        if len(texts) > 20:
            print(f"... and {len(texts) - 20} more")
        return 0

    voice = args.voice or {
        "female": "cs-CZ-VlastaNeural",
        "male": "cs-CZ-AntoninNeural",
    }[args.gender]
    speech_key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not speech_key or not region:
        print("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION.", file=sys.stderr)
        return 2

    AUDIO.mkdir(parents=True, exist_ok=True)
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        manifest = {}
    voices = manifest.get("voices", {})
    entries: dict[str, str] = {}
    generated = 0
    for index, text in enumerate(texts, 1):
        digest = key_for(text)
        filename = f"{args.gender}_{digest}.mp3"
        destination = AUDIO / filename
        if not destination.exists() or destination.stat().st_size == 0:
            if args.limit is not None and generated >= args.limit:
                continue
            for attempt in range(3):
                try:
                    synthesize(text, destination, speech_key, region, voice)
                    generated += 1
                    break
                except (urllib.error.URLError, TimeoutError) as error:
                    if attempt == 2:
                        print(f"Failed: {text}: {error}", file=sys.stderr)
                        break
                    time.sleep(2 ** attempt)
        if destination.exists() and destination.stat().st_size > 0:
            entries[digest] = f"assets/audio/{filename}"
        print(f"[{index}/{len(texts)}] {text}")

    voices[args.gender] = {
        "name": voice,
        "entries": dict(sorted(entries.items())),
    }
    MANIFEST.write_text(json.dumps({
        "version": 2, "locale": "cs-CZ", "voices": voices,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"{args.gender.title()} manifest contains {len(entries)} files; "
        f"generated {generated} this run."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
