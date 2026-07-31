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
import json
import urllib.request
from pathlib import Path

from audio_utterances import extract_utterances  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "audio" / "manifest.json"


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
