#!/usr/bin/env python3
"""Report neural-audio coverage: how many curriculum utterances have MP3s.

Compares the utterances the app will request at runtime (same extraction rule
as generate_audio_pack.py) against the local manifest and, optionally, the
deployed bucket manifest. Writes the missing list so a generation run's scope
and cost are clear up front.

Usage:
  python3 tool/audio_coverage.py                 # local coverage
  python3 tool/audio_coverage.py --bucket-url URL  # also check the deployed manifest
  python3 tool/audio_coverage.py --write-missing build/audio_missing.txt
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS = ROOT / "assets" / "curriculum" / "lessons"
VOCABULARY = ROOT / "assets" / "vocabulary"
MANIFEST = ROOT / "assets" / "audio" / "manifest.json"
PREVIEW_TEXT = "Ahoj, jak se máš?"


# Identical to TextNormalizer.forSpeech / generate_audio_pack.speech_text.
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


def key_for(text: str) -> str:
    return hashlib.sha256(
        speech_text(text).strip().lower().encode("utf-8"),
    ).hexdigest()


def extract_utterances() -> dict[str, str]:
    """Return {sha256: text}, matching generate_audio_pack.extract_utterances."""
    utterances: set[str] = {PREVIEW_TEXT}
    for path in sorted(VOCABULARY.glob("*.json")):
        for row in json.loads(path.read_text(encoding="utf-8")):
            for field in ("word_cz", "example_cz"):
                value = row.get(field)
                if isinstance(value, str) and value.strip():
                    utterances.add(value.strip())
    for path in sorted(LESSONS.glob("*.json")):
        lesson = json.loads(path.read_text(encoding="utf-8"))
        for exercise in lesson.get("exercises", []):
            data = exercise.get("data", {})
            for field in ("expected_text", "target_text", "question_cz"):
                value = data.get(field)
                if isinstance(value, str) and value.strip():
                    utterances.add(value.strip())
    result: dict[str, str] = {}
    for text in sorted(utterances):
        spoken = speech_text(text)
        if spoken:
            result[key_for(text)] = spoken
    return result


def both_voice_keys(manifest: dict) -> set[str]:
    voices = manifest.get("voices", {})
    female = set(voices.get("female", {}).get("entries", {}))
    male = set(voices.get("male", {}).get("entries", {}))
    return female & male


def load_manifest(path_or_url: str, is_url: bool) -> dict:
    if is_url:
        with urllib.request.urlopen(path_or_url, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    return json.loads(Path(path_or_url).read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bucket-url", help="public manifest.json URL to also check")
    parser.add_argument("--write-missing", help="write missing utterances to this file")
    args = parser.parse_args()

    needed = extract_utterances()
    print(f"Curriculum needs {len(needed)} unique utterances (x2 voices).")

    local = both_voice_keys(load_manifest(str(MANIFEST), False)) if MANIFEST.exists() else set()
    covered = needed.keys() & local
    missing = {k: v for k, v in needed.items() if k not in local}
    pct = 100 * len(covered) / len(needed) if needed else 0
    print(f"Local manifest covers {len(covered)}/{len(needed)} ({pct:.0f}%).")
    print(f"Missing (no both-voice audio): {len(missing)} utterances "
          f"= {len(missing) * 2} MP3 files to generate.")
    stale = local - needed.keys()
    if stale:
        print(f"Manifest has {len(stale)} entries no longer in the curriculum.")

    if args.bucket_url:
        try:
            deployed = both_voice_keys(load_manifest(args.bucket_url, True))
            dcov = needed.keys() & deployed
            print(f"Deployed bucket manifest covers {len(dcov)}/{len(needed)} "
                  f"({100 * len(dcov) / len(needed):.0f}%).")
        except Exception as error:  # noqa: BLE001 - report and continue
            print(f"Could not read bucket manifest: {error}")

    if args.write_missing:
        out = Path(args.write_missing)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            "".join(f"{k}\t{v}\n" for k, v in sorted(missing.items(), key=lambda kv: kv[1])),
            encoding="utf-8",
        )
        # A rough Azure/OpenAI cost proxy: total characters to synthesize.
        chars = sum(len(v) for v in missing.values()) * 2
        print(f"Wrote {len(missing)} missing utterances to {out} "
              f"(~{chars} characters across both voices).")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
