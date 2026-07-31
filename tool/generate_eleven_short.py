#!/usr/bin/env python3
"""Generate the short utterances ElevenLabs clips when asked for them alone.

v3 rushes isolated short input: "Ano" came back at 0.17s of speech against
Azure's 0.37s — too fast to repeat after, which is the whole point of a
vocabulary card. Batching ten words into one request fixes the pace but the
split is unreliable (ten words produced eight segments).

So each word gets its own request with a throwaway word after it. That leaves
exactly one gap to find instead of nine, which detected cleanly on every test
case, and the target still inherits sentence pacing.

The extracted clip is then stretched to the pace of the Azure clip it replaces
(atempo preserves pitch), so a learner hears the same rhythm across the pack
regardless of which engine produced a given word.

  python3 tool/generate_eleven_short.py --dry-run
  python3 tool/generate_eleven_short.py --limit 20
  python3 tool/generate_eleven_short.py
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audio_utterances import key_for  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
LEDGER = AUDIO / "eleven_done.json"
SHORT_LIST = AUDIO / "eleven_short.json"

OLIVER = "daJ4gHLkIVFskWuoLuDX"
MODEL = os.environ.get("ELEVENLABS_MODEL", "eleven_v3")
SEED = int(os.environ.get("ELEVENLABS_SEED", "42"))

# Spoken after the target so the model treats the target as part of a phrase
# rather than an isolated fragment. Discarded after the split.
CARRIER = "Konec."

# Fallback pacing when the clip being replaced is not in git history.
SECONDS_PER_CHAR = 0.075
MIN_TARGET = 0.35


def load_env_file() -> None:
    path = ROOT / ".env"
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, _, value = line.partition("=")
        if name.strip() and name.strip() not in os.environ:
            os.environ[name.strip()] = value.strip().strip('"').strip("'")


def duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(path)],
        capture_output=True, text=True).stdout.strip()
    # ffprobe prints "N/A" when a file has no measurable duration — which is
    # what silence-trimming an already-silent clip produces. Treated as zero
    # rather than crashing a run that is hundreds of clips deep.
    try:
        return float(out)
    except ValueError:
        return 0.0


def speech_seconds(path: Path) -> float:
    trimmed = path.with_suffix(".trim.wav")
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(path), "-af",
         "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0:"
         "stop_periods=-1:stop_threshold=-45dB:stop_silence=0.05",
         str(trimmed)], capture_output=True, check=True)
    value = duration(trimmed)
    trimmed.unlink(missing_ok=True)
    return value


def azure_pace(key: str, text: str) -> float:
    """How long the clip we are replacing spends actually speaking.

    Matching this keeps the pack rhythmically consistent. Falls back to a
    per-character estimate when git has no copy (a clip added after the last
    commit, or already replaced in an earlier run).
    """
    result = subprocess.run(
        ["git", "show", f"HEAD:assets/audio/male_{key}.mp3"],
        capture_output=True)
    if result.returncode == 0 and result.stdout:
        reference = AUDIO / f".ref_{key}.mp3"
        reference.write_bytes(result.stdout)
        try:
            return speech_seconds(reference)
        finally:
            reference.unlink(missing_ok=True)
    return max(MIN_TARGET, SECONDS_PER_CHAR * len(text.strip()))


def segments(path: Path, min_silence: float = 0.20) -> list[tuple[float, float]]:
    log = subprocess.run(
        ["ffmpeg", "-i", str(path), "-af",
         f"silencedetect=noise=-40dB:d={min_silence}", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start:\s*(-?[\d.]+)", log)]
    ends = [float(x) for x in re.findall(r"silence_end:\s*(-?[\d.]+)", log)]
    match = re.search(r"Duration:\s*(\d+):(\d+):([\d.]+)", log)
    if not match:
        return []
    h, m, s = match.groups()
    total = int(h) * 3600 + int(m) * 60 + float(s)
    found = []
    for begin in sorted(ends + [0.0]):
        following = [x for x in starts if x > begin]
        finish = min(following) if following else total
        if finish - begin > 0.05:
            found.append((begin, finish))
    return found


def request_audio(text: str, key: str, destination: Path) -> None:
    body = {"text": text, "model_id": MODEL, "seed": SEED}
    request = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{OLIVER}"
        "?output_format=mp3_44100_128",
        data=json.dumps(body).encode("utf-8"), method="POST")
    request.add_header("xi-api-key", key)
    request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=120) as response:
        audio = response.read()
    if not audio:
        raise RuntimeError("empty body")
    destination.write_bytes(audio)


def build_clip(text: str, digest: str, api_key: str) -> str:
    """Returns '' on success, or a reason the clip was rejected."""
    raw = AUDIO / f".raw_{digest}.mp3"
    cut = AUDIO / f".cut_{digest}.mp3"
    final = AUDIO / f"male_{digest}.mp3"
    try:
        request_audio(f"{text.strip().rstrip('.')}. {CARRIER}", api_key, raw)
        found = segments(raw)
        # Exactly one carrier means exactly two segments. Anything else and we
        # cannot tell which audio is the word, so nothing is written.
        if len(found) != 2:
            return f"{len(found)} segments (expected 2)"
        begin, finish = found[0]
        subprocess.run(
            ["ffmpeg", "-y", "-ss", str(max(0.0, begin - 0.05)),
             "-t", str(finish - begin + 0.08), "-i", str(raw), str(cut)],
            capture_output=True, check=True)

        target = azure_pace(digest, text)
        actual = speech_seconds(cut)
        tempo = 1.0
        if actual > 0 and actual < 0.95 * target:
            # atempo below 0.5 is not supported and would sound artificial
            # anyway; take what stretch we can get.
            tempo = max(0.5, actual / target)
        filters = f"atempo={tempo:.3f}," if tempo < 1.0 else ""
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(cut), "-af",
             f"{filters}loudnorm=I=-18:TP=-2:LRA=11",
             "-c:a", "libmp3lame", "-b:a", "48k", "-ar", "24000", str(final)],
            capture_output=True, check=True)
        return ""
    finally:
        raw.unlink(missing_ok=True)
        cut.unlink(missing_ok=True)


def main() -> int:
    load_env_file()
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--rate", type=float, default=60.0)
    args = parser.parse_args()

    if not SHORT_LIST.exists():
        print(f"{SHORT_LIST.name} not found — run generate_eleven_pack.py "
              "with --min-chars first.", file=sys.stderr)
        return 2
    texts = json.loads(SHORT_LIST.read_text(encoding="utf-8"))
    try:
        already = set(json.loads(LEDGER.read_text(encoding="utf-8")))
    except (FileNotFoundError, json.JSONDecodeError):
        already = set()

    pending = [t for t in texts if key_for(t) not in already]
    billed = sum(len(t) + len(CARRIER) + 2 for t in pending)
    print(f"{len(texts)} short utterances, {len(pending)} still to do")
    print(f"~{billed:,} characters including the '{CARRIER}' carrier")
    if args.dry_run:
        for text in pending[:10]:
            print(f"   {text!r} -> target {azure_pace(key_for(text), text):.2f}s")
        return 0

    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("Set ELEVENLABS_API_KEY in .env", file=sys.stderr)
        return 2

    interval = 60.0 / args.rate if args.rate > 0 else 0.0
    last = 0.0
    done = 0
    rejected: list[str] = []

    for index, text in enumerate(pending, 1):
        if args.limit and done >= args.limit:
            break
        digest = key_for(text)
        wait = interval - (time.monotonic() - last)
        if wait > 0:
            time.sleep(wait)
        last = time.monotonic()
        try:
            reason = build_clip(text, digest, api_key)
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:160]
            if error.code in (401, 402):
                print(f"\nStopped: {error.code} {detail}", file=sys.stderr)
                break
            reason = f"HTTP {error.code}"
        except Exception as error:  # noqa: BLE001
            reason = str(error)[:60]

        if reason:
            rejected.append(f"{text} — {reason}")
        else:
            done += 1
            already.add(digest)
            LEDGER.write_text(json.dumps(sorted(already), indent=0),
                              encoding="utf-8")
        if index % 25 == 0:
            print(f"  [{done} ok, {len(rejected)} rejected] {text}")

    print(f"\nBuilt {done}; rejected {len(rejected)}.")
    if rejected:
        report = AUDIO / "eleven_rejected.json"
        report.write_text(json.dumps(rejected, ensure_ascii=False, indent=2),
                          encoding="utf-8")
        print(f"Rejected clips left untouched (still Azure) — see {report.name}")
        for line in rejected[:10]:
            print(f"   {line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
