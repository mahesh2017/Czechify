#!/usr/bin/env python3
"""List which audio clips belong to which unit, so the app can pre-download.

Audio is fetched clip-by-clip on demand, which means a learner on a train gets
silence and a learner on mobile data pays for every replay. To work offline the
app has to know what a unit needs *before* the learner opens it — and the app
cannot work that out for itself, because the mapping lives in the curriculum
JSON and the vocabulary list, not in the audio manifest.

The output is deliberately small (hashes only, no paths) and bundled with the
app: at ~65 bytes per entry a few hundred utterances cost a few KB, against the
several MB of audio they describe.

    python3 tool/generate_offline_manifest.py --dry-run
    python3 tool/generate_offline_manifest.py
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_utterances as au  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
OUT = AUDIO / "offline_units.json"


def unit_ids() -> list[int]:
    ids: list[int] = []
    for name in ("a1_units.json", "a2_units.json"):
        loaded = json.loads(
            (ROOT / "assets" / "curriculum" / name).read_text(encoding="utf-8")
        )
        # The unit files are objects wrapping a "units" list, not bare lists.
        rows = loaded if isinstance(loaded, list) else loaded.get("units", [])
        ids += [row["id"] for row in rows]
    return sorted(ids)


def keys_for_unit(unit_id: int) -> list[str]:
    """Every audio key a learner can trigger inside one unit.

    Mirrors audio_utterances.raw_utterances, restricted to a unit: vocabulary
    rows tagged with it, and every spoken field of its lessons — including
    teaching-card items, which are the first thing a learner meets.
    """
    found: set[str] = set()

    for path in sorted(au.VOCABULARY.glob("*.json")):
        for row in json.loads(path.read_text(encoding="utf-8")):
            if row.get("unit_id") == unit_id:
                for field in au.VOCAB_FIELDS:
                    au._add(found, row.get(field))

    for path in sorted(au.LESSONS.glob("*.json")):
        lesson = json.loads(path.read_text(encoding="utf-8"))
        if lesson.get("unit_id") != unit_id:
            continue
        for exercise in lesson.get("exercises", []):
            data = exercise.get("data", {}) or {}
            for field in au.LESSON_DATA_FIELDS:
                au._add(found, data.get(field))
            for item in data.get("items") or []:
                if isinstance(item, dict):
                    for field in au.TEACHING_ITEM_FIELDS:
                        au._add(found, item.get(field))

    keys = {au.key_for(text) for text in found if au.speech_text(text)}
    return sorted(keys)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    by_unit = {str(uid): keys_for_unit(uid) for uid in unit_ids()}
    total = sum(len(v) for v in by_unit.values())

    print(f"{len(by_unit)} units, {total} utterance keys "
          f"({len(set().union(*by_unit.values()))} distinct)")
    for uid in list(by_unit)[:5]:
        clips = by_unit[uid]
        have = sum(
            (AUDIO / f"female_{k}.mp3").stat().st_size
            for k in clips
            if (AUDIO / f"female_{k}.mp3").exists()
        )
        print(f"  unit {uid:<3} {len(clips):>4} clips  {have / 1e6:5.1f} MB/voice")

    if args.dry_run:
        print("\nDry run — nothing written.")
        return 0

    OUT.write_text(
        json.dumps({"version": 1, "units": by_unit}, indent=0) + "\n",
        encoding="utf-8",
    )
    print(f"\nWrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size / 1024:.0f} KB)")
    print("Remember to upload it: python3 tool/upload_audio_pack.py --skip-existing")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
