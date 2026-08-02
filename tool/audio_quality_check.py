#!/usr/bin/env python3
"""Automated audio quality checks for the Czech audio pack.

Checks every MP3 for:
  - Leading/trailing silence (flags clips with > 1.2s of silence at either end)
  - Loudness (flags clips below -30 dBFS or above -6 dBFS RMS)
  - Clipping (flags clips with samples at or near 0 dBFS)
  - Duration (flags clips shorter than 200ms or longer than 30s)
  - Decodability (flags corrupt/truncated MP3s)

Requires pydub (pip install pydub) and ffmpeg installed on the system.

Usage:
  python3 tool/audio_quality_check.py                 # check all clips
  python3 tool/audio_quality_check.py --gender female   # check one voice
  python3 tool/audio_quality_check.py --fix-verbose     # print every clip, not just issues
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import audio_utterances as au

try:
    from pydub import AudioSegment
    from pydub.silence import detect_leading_silence
except ImportError:
    print(
        "pydub is required: pip install pydub\n"
        "ffmpeg must also be installed on the system.",
        file=sys.stderr,
    )
    raise

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"

# Thresholds
# Azure Neural clips consistently include about one second of encoded tail.
# Treat that service baseline as normal and flag a materially longer edge.
SILENCE_THRESHOLD_MS = 1_200
SILENCE_DBFS = -40.0              # silence detection level
LOUDNESS_LOW_DBFS = -30.0         # flag too-quiet clips
LOUDNESS_HIGH_DBFS = -6.0         # flag too-loud clips
CLIPPING_THRESHOLD = -0.1         # samples at or above this are near-clip
DURATION_MIN_MS = 200
DURATION_MAX_MS = 30_000


def _edge_silence(audio: AudioSegment, *, trailing: bool = False) -> int:
    """Measure silence at one edge using pydub's supported public helper."""
    edge = audio.reverse() if trailing else audio
    return detect_leading_silence(
        edge,
        silence_threshold=SILENCE_DBFS,
    )


def check_clip(path: Path) -> dict:
    """Check a single MP3 file. Returns a dict with results and issues list."""
    issues = []
    try:
        audio = AudioSegment.from_mp3(str(path))
    except Exception as e:
        return {"file": path.name, "decodable": False, "issues": [f"undecodable: {e}"]}

    duration_ms = len(audio)
    leading_silence = _edge_silence(audio)
    trailing_silence = _edge_silence(audio, trailing=True)

    # RMS loudness
    rms_dbfs = audio.rms  # raw RMS amplitude
    # Convert to dBFS
    import math
    if rms_dbfs > 0:
        rms_dbfs = 20 * math.log10(rms_dbfs / 32768.0)
    else:
        rms_dbfs = -float("inf")

    # Clipping detection: count samples at or near max amplitude
    max_amplitude = audio.max
    clipping_amplitude = 32767 * (10 ** (CLIPPING_THRESHOLD / 20))
    has_clipping = max_amplitude >= clipping_amplitude

    if duration_ms < DURATION_MIN_MS:
        issues.append(f"too short: {duration_ms}ms")
    if duration_ms > DURATION_MAX_MS:
        issues.append(f"too long: {duration_ms}ms")
    if leading_silence > SILENCE_THRESHOLD_MS:
        issues.append(f"leading silence: {leading_silence}ms")
    if trailing_silence > SILENCE_THRESHOLD_MS:
        issues.append(f"trailing silence: {trailing_silence}ms")
    if rms_dbfs < LOUDNESS_LOW_DBFS:
        issues.append(f"too quiet: {rms_dbfs:.1f} dBFS RMS")
    if rms_dbfs > LOUDNESS_HIGH_DBFS:
        issues.append(f"too loud: {rms_dbfs:.1f} dBFS RMS")
    if has_clipping:
        issues.append("clipping detected")

    return {
        "file": path.name,
        "decodable": True,
        "duration_ms": duration_ms,
        "leading_silence_ms": leading_silence,
        "trailing_silence_ms": trailing_silence,
        "rms_dbfs": round(rms_dbfs, 1),
        "max_amplitude": max_amplitude,
        "clipping": has_clipping,
        "issues": issues,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gender", choices=("female", "male"), help="check one voice only")
    parser.add_argument(
        "--scope",
        choices=("a1", "a2", "all"),
        default="all",
        help="check only utterances used by this course scope",
    )
    parser.add_argument("--fix-verbose", action="store_true",
                        help="print every clip, not just ones with issues")
    parser.add_argument("--json", help="write full results as JSON to this path")
    args = parser.parse_args()

    if not MANIFEST.exists():
        print(f"Manifest not found: {MANIFEST}", file=sys.stderr)
        return 2

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    voices = manifest.get("voices", {})
    allowed_keys = set(au.scoped_utterances(args.scope))

    all_results = []
    issue_count = 0
    total_checked = 0

    for gender, voice_data in voices.items():
        if args.gender and gender != args.gender:
            continue
        entries = voice_data.get("entries", {})
        print(f"\n{'='*60}")
        print(f"  {gender.upper()} ({len(entries)} clips)")
        print(f"{'='*60}")

        for digest, entry_data in sorted(entries.items()):
            if digest not in allowed_keys:
                continue
            if isinstance(entry_data, str):
                path_str = entry_data
            else:
                path_str = entry_data.get("path", "")
            filename = Path(path_str).name
            clip_path = AUDIO / filename

            if not clip_path.exists():
                if args.fix_verbose:
                    print(f"  MISSING  {filename}")
                all_results.append({"file": filename, "decodable": False, "issues": ["file missing"]})
                issue_count += 1
                total_checked += 1
                continue

            result = check_clip(clip_path)
            all_results.append(result)
            total_checked += 1

            if result["issues"]:
                issue_count += 1
                status = "  ISSUES  "
                for issue in result["issues"]:
                    print(f"  {status} {filename}: {issue}")
            elif args.fix_verbose:
                print(f"  OK       {filename} ({result['duration_ms']}ms, "
                      f"{result['rms_dbfs']} dBFS)")

    print(f"\n{'='*60}")
    print(f"Checked {total_checked} clips, {issue_count} with issues.")
    print(f"{'='*60}")

    if args.json:
        out = Path(args.json)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(all_results, indent=2, ensure_ascii=False),
                       encoding="utf-8")
        print(f"Full results written to {out}")

    return 1 if issue_count > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
