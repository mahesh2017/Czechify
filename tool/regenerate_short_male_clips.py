#!/usr/bin/env python3
"""Re-record the short male clips inside a carrier paragraph so they stop rushing.

The defect, measured on the shipped pack: asked for "To je káva." on its own,
eleven_v3 spends 0.176s on "To je" and 0.613s on "káva". Lenka (Azure) gives
"To je" 0.257s. Pavel is not uniformly fast — on speech-only duration he is a
consistent 0.8x of Lenka at every length — he specifically swallows the
unstressed opening of a short utterance, which is the half a beginner most
needs to hear.

Put the same sentence in the middle of a paragraph and the balance improves —
"To je" takes 29% of the sentence instead of 22% — because the model now has
somewhere to be going. So each clip is generated as one sentence among
neighbours and cut back out afterwards.

That alone is not enough. Batching redistributes time inside the sentence
rather than adding any: across 18 clips the median length change was 1.03x, and
"To je" only reached 0.207s. So `--match-female` then stretches each clip
against the female recording of the same text, which is the pace nobody has
complained about. At 1.25 the measured result is "To je" 0.261s — Lenka's
figure exactly — with "káva" within 2% of the length it already had, so no part
of the pack ends up faster than it is today.

Beware of trusting the alignment for any of this. Its character times are the
model's own nominal attribution and can disagree with the audio by more than a
tenth of a second; every number above was measured off the finished mp3.

Cutting is exact rather than guessed. An earlier attempt split batches with
silencedetect and got eight segments from ten words; this asks for
/with-timestamps, which returns a start and end time per character, and finds
each sentence by index. v3 supports it despite the docs being quiet about it.
A batch whose returned text does not match what we sent is rejected whole, so a
mis-split can never be written over good audio.

The run is in two halves, and only the first costs anything:

  1. `fetch`  — one request per batch, response cached under .audio_batches/
  2. `cut`    — read the cache, slice, pace, encode into assets/audio/

so re-cutting the whole pack at a different pace is free.

  python3 tool/regenerate_short_male_clips.py --dry-run
  python3 tool/regenerate_short_male_clips.py fetch --limit 3
  python3 tool/regenerate_short_male_clips.py fetch
  python3 tool/regenerate_short_male_clips.py cut --match-female 1.25 --force

Afterwards, rebuild the manifest so clients see the new checksums and
re-download (the filename is a hash of the text, so it does not change):

  python3 tool/generate_audio_pack.py --gender male --manifest-only
  python3 tool/upload_audio_pack.py --skip-existing

`--manifest-only` matters. Without it that command synthesizes every male clip
the pack is missing, and it does so with Azure's Antonin — the voice this
project rejected — quietly mixing a second male voice into Pavel's pack.

and bump ReleaseConfig.bundledContentRevision, or the cached manifest that
carries the old checksums never gets replaced.

Once the app is published, that bump is not optional and the upload cannot go
out on its own. An install caches the manifest under its own revision, so it
keeps the old checksums until it updates. Replace a clip in the bucket before
that install updates and it downloads the new bytes, finds they do not match
the checksum it still believes in, rejects them (`verifyDownloadedFile`), and
falls back to the device voice — for every clip it had not already cached.
Re-recorded audio ships with an app release, never ahead of one.
"""

from __future__ import annotations

import argparse
import base64
import difflib
import hashlib
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
from audio_utterances import extract_utterances  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
CACHE = ROOT / ".audio_batches"
LEDGER = AUDIO / "eleven_paced.json"

OLIVER = "daJ4gHLkIVFskWuoLuDX"
MODEL = os.environ.get("ELEVENLABS_MODEL", "eleven_v3")
SEED = int(os.environ.get("ELEVENLABS_SEED", "42"))

# Spoken first and last in every batch and then thrown away. A paragraph's own
# opening is rushed exactly like an isolated utterance is — "To je dům." led a
# test batch and came back at 0.72s against 1.27s for the same sentence in the
# middle — so the first real clip must never be first in the paragraph.
LEAD_IN = "Teď si to poslechneme ještě jednou."
TAIL = "A to je pro dnešek všechno."

# Below this the cut is not plausibly a whole short sentence, so something in
# the alignment went wrong and the clip is left alone.
MIN_CUT_SECONDS = 0.25


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


def spoken(text: str) -> str:
    """What we actually send: a blank voiced as a pause, and a full stop.

    Every target has to be a sentence of its own or the model runs it into its
    neighbour and there is no boundary left to cut on.
    """
    out = re.sub(r"_{2,}", "...", text.strip())
    out = " ".join(out.split())
    if not out.endswith((".", "!", "?")):
        out += "."
    return out


def selection(min_words: int, max_words: int) -> dict[str, str]:
    items = extract_utterances()
    return {
        k: t for k, t in sorted(items.items(), key=lambda kv: kv[1])
        if min_words <= len(t.split()) <= max_words
    }


def batches(picked: dict[str, str], size: int) -> list[list[tuple[str, str]]]:
    ordered = list(picked.items())
    return [ordered[i:i + size] for i in range(0, len(ordered), size)]


def batch_id(group: list[tuple[str, str]]) -> str:
    """Names the cache file after what was asked for, not the batch's position.

    Re-running with a different --batch-size regroups everything; keying on
    content means the cache stays valid for whatever groups repeat.
    """
    payload = " ".join(f"{k}:{spoken(t)}" for k, t in group)
    stamp = f"{MODEL}|{SEED}|{LEAD_IN}|{TAIL}|{payload}"
    return hashlib.sha256(stamp.encode("utf-8")).hexdigest()[:16]


def request_batch(text: str, api_key: str) -> dict:
    body = {"text": text, "model_id": MODEL, "seed": SEED}
    request = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{OLIVER}"
        "/with-timestamps?output_format=mp3_44100_128",
        data=json.dumps(body).encode("utf-8"), method="POST")
    request.add_header("xi-api-key", api_key)
    request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=300) as response:
        return json.load(response)


def fetch(args) -> int:
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("Set ELEVENLABS_API_KEY in .env", file=sys.stderr)
        return 2
    CACHE.mkdir(exist_ok=True)
    picked = selection(args.min_words, args.max_words)
    groups = batches(picked, args.batch_size)
    pending = [g for g in groups if not (CACHE / f"{batch_id(g)}.json").exists()]
    print(f"{len(picked)} utterances in {len(groups)} batches; "
          f"{len(pending)} still to fetch")
    if args.limit:
        pending = pending[:args.limit]

    interval = 60.0 / args.rate if args.rate > 0 else 0.0
    last = 0.0
    billed = 0
    for index, group in enumerate(pending, 1):
        sentences = [spoken(t) for _, t in group]
        text = " ".join([LEAD_IN, *sentences, TAIL])
        wait = interval - (time.monotonic() - last)
        if wait > 0:
            time.sleep(wait)
        last = time.monotonic()
        try:
            payload = request_batch(text, api_key)
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:200]
            print(f"\nStopped at batch {index}: HTTP {error.code} {detail}",
                  file=sys.stderr)
            return 1
        name = batch_id(group)
        (CACHE / f"{name}.mp3").write_bytes(
            base64.b64decode(payload["audio_base64"]))
        (CACHE / f"{name}.json").write_text(json.dumps({
            "sent": text,
            "targets": [{"key": k, "spoken": spoken(t), "text": t}
                        for k, t in group],
            "alignment": payload["alignment"],
        }, ensure_ascii=False), encoding="utf-8")
        billed += len(text)
        if index % 10 == 0 or index == len(pending):
            print(f"  {index}/{len(pending)} batches, ~{billed:,} characters")
    print(f"\nFetched {len(pending)} batches (~{billed:,} characters). "
          f"Cache: {CACHE}")
    return 0


def locate(alignment: dict, targets: list[dict]) -> list[tuple[int, int]] | None:
    """Character index spans for each target, or None if the batch is unusable.

    Verbatim search in emission order is the normal case. When v3 has rewritten
    something — a numeral spoken as a word, say — the cursor would be lost for
    every later target too, so the whole batch is rejected rather than cut on a
    guess.
    """
    text = "".join(alignment["characters"])
    spans: list[tuple[int, int]] = []
    cursor = 0
    for target in targets:
        needle = target["spoken"]
        at = text.find(needle, cursor)
        if at < 0:
            return None
        spans.append((at, at + len(needle)))
        cursor = at + len(needle)
    return spans


# Padding every finished clip gets, so the pack is uniform however much silence
# the model happened to leave around a given sentence.
LEAD_PAD_MS = 60
TAIL_PAD_SECONDS = 0.18


def window(alignment: dict, start: int, stop: int) -> tuple[float, float]:
    """A generous span of seconds that certainly contains characters
    [start, stop) and certainly no neighbour's speech.

    Deliberately loose. v3's alignment is reliable about which characters it is
    speaking and unreliable about where it puts the pause between two
    sentences: "A koncerty?" came back with 0.57s of speech inside a 1.41s span,
    three quarters of a second of which was silence charged to the leading "A".
    Trying to make this boundary tight produced clips that began with dead air
    and then had that dead air stretched along with the speech.

    So this only has to isolate the sentence — half of each neighbouring gap,
    which cannot contain a neighbour's voice — and [cut_clip] trims the silence
    off acoustically afterwards.
    """
    begins = alignment["character_start_times_seconds"]
    ends = alignment["character_end_times_seconds"]
    lead = (begins[start - 1] + ends[start - 1]) / 2 if start > 0 else 0.0
    if stop < len(begins):
        tail = (begins[stop] + ends[stop]) / 2
    else:
        tail = ends[stop - 1]
    return max(0.0, lead), tail


def speech_seconds(path: Path) -> float:
    """How long a clip spends actually speaking, ignoring its padding.

    Raw duration is useless for comparing the two voices: the Azure clips carry
    roughly a second of trailing silence, which is what made Lenka look twice
    as slow as Pavel when their speaking rates are in fact within 20% of each
    other.
    """
    trimmed = path.with_suffix(".trim.wav")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(path), "-af",
         "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0:"
         "stop_periods=-1:stop_threshold=-45dB:stop_silence=0.05",
         str(trimmed)], capture_output=True)
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(trimmed)],
        capture_output=True, text=True).stdout.strip()
    trimmed.unlink(missing_ok=True)
    try:
        return float(probe)
    except ValueError:
        return 0.0


def matched_tempo(key: str, cut_length: float, factor: float,
                  floor: float) -> float:
    """Stretch factor that brings this clip to [factor] x Lenka's speaking time.

    Batching alone is not a uniform slowdown — it redistributes time inside the
    sentence rather than adding it. It rescues "To je káva." (whose opening was
    being swallowed) and leaves "A koncerty?" slightly shorter than before. So
    the pace is set afterwards against the female clip for the same text, which
    is the pace nobody has complained about.

    Only ever slows down: a clip that already speaks for long enough is left
    exactly as the model paced it.
    """
    reference = AUDIO / f"female_{key}.mp3"
    if not reference.exists() or cut_length <= 0:
        return 1.0
    target = speech_seconds(reference) * factor
    if target <= 0:
        return 1.0
    return min(1.0, max(floor, cut_length / target))


# Strips silence from the front, reverses, strips what was the tail, reverses
# back. `start_periods=1` is the point: it takes the one silence at the edge and
# leaves every pause inside the sentence alone, which a `stop_periods=-1` sweep
# would flatten — and those internal pauses are the rhythm being fixed here.
# Peak rather than RMS detection so a soft plosive onset survives: one sample
# above the threshold is enough to stop the trim.
#
# -45dB, not the -50dB this started at. Between those two levels sits a noise
# floor v3 sometimes leaves in a pause — "Já jsem Adam." arrived with 1.2s of it
# in front, peaking at -48.9dB. Inaudible, but a clip that waits over a second
# before speaking reads as a broken app.
_TRIM_EDGE = ("silenceremove=start_periods=1:start_duration=0:"
              "start_threshold=-45dB:detection=peak")
TRIM_BOTH_ENDS = f"{_TRIM_EDGE},areverse,{_TRIM_EDGE},areverse"


def cut_clip(source: Path, begin: float, end: float, destination: Path,
             tempo: float) -> None:
    chain = [f"atrim=start={begin:.3f}:end={end:.3f}", "asetpts=PTS-STARTPTS",
             TRIM_BOTH_ENDS]
    if tempo < 1.0:
        # atempo will not go below 0.5 and anything near it sounds synthetic.
        chain.append(f"atempo={max(0.5, tempo):.3f}")
    # Padding after the stretch, so every clip ends up with the same margins
    # rather than margins scaled by however much it happened to be slowed.
    chain.append(f"adelay=delays={LEAD_PAD_MS}:all=1")
    chain.append(f"apad=pad_dur={TAIL_PAD_SECONDS}")
    chain.append("loudnorm=I=-18:TP=-2:LRA=11")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(source),
         "-af", ",".join(chain),
         # Matches what the API returns for the rest of the ElevenLabs pack;
         # re-encoding to the Azure pack's 24kHz would make Pavel duller than
         # the clips around him.
         "-c:a", "libmp3lame", "-b:a", "128k", "-ar", "44100",
         str(destination)],
        check=True)


def cut(args) -> int:
    if not CACHE.exists():
        print(f"No batch cache at {CACHE} — run `fetch` first.",
              file=sys.stderr)
        return 2
    try:
        done = set(json.loads(LEDGER.read_text(encoding="utf-8")))
    except (FileNotFoundError, json.JSONDecodeError):
        done = set()

    written = 0
    rejected: list[str] = []
    stretched: list[float] = []
    for meta_path in sorted(CACHE.glob("*.json")):
        try:
            payload = json.loads(meta_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            # A fetch running in another shell is part-way through this file.
            rejected.append(f"{meta_path.stem}: cache entry still being written")
            continue
        alignment = payload["alignment"]
        targets = payload["targets"]
        audio = meta_path.with_suffix(".mp3")
        if not audio.exists():
            rejected.append(f"{meta_path.stem}: audio missing from cache")
            continue
        spans = locate(alignment, targets)
        if spans is None:
            returned = "".join(alignment["characters"])
            ratio = difflib.SequenceMatcher(
                None, payload["sent"], returned).ratio()
            rejected.append(
                f"{meta_path.stem}: returned text does not match what was "
                f"sent (similarity {ratio:.2f}) — {len(targets)} clips left "
                f"alone")
            continue
        for target, (start, stop) in zip(targets, spans):
            if target["key"] in done and not args.force:
                continue
            begin, end = window(alignment, start, stop)
            if end - begin < MIN_CUT_SECONDS:
                rejected.append(
                    f"{target['text']!r}: cut only {end - begin:.2f}s")
                continue
            destination = AUDIO / f"male_{target['key']}.mp3"
            tempo = args.tempo
            if args.match_female:
                # Needs the cut before it can measure it, so the clip is made
                # once at the paragraph's own pace and then remade at the pace
                # that measurement asks for.
                cut_clip(audio, begin, end, destination, 1.0)
                tempo = matched_tempo(
                    target["key"], speech_seconds(destination),
                    args.match_female, args.tempo_floor)
            if tempo < 1.0 or not args.match_female:
                cut_clip(audio, begin, end, destination, tempo)
            stretched.append(tempo)
            done.add(target["key"])
            written += 1
    LEDGER.write_text(json.dumps(sorted(done), indent=0), encoding="utf-8")
    if args.match_female:
        slowed = [t for t in stretched if t < 1.0]
        pace = (f"matched to {args.match_female:.2f}x Lenka "
                f"({len(slowed)} of {written} needed stretching, "
                f"mean {sum(slowed) / len(slowed):.2f})" if slowed
                else f"matched to {args.match_female:.2f}x Lenka "
                     f"(none needed stretching)")
    else:
        pace = f"tempo {args.tempo:.2f}"
    print(f"Wrote {written} clips, {pace}; {len(rejected)} rejected.")
    for line in rejected[:15]:
        print(f"  - {line}")
    if len(rejected) > 15:
        print(f"  ... and {len(rejected) - 15} more")
    return 0


def edge_silence(path: Path) -> tuple[float, float, float]:
    """(total, leading silence, trailing silence) in seconds.

    Deliberately not the same measurement as [speech_seconds], which strips
    internal pauses too and so cannot tell dead air at the edges from the
    rhythm inside a sentence.
    """
    log = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(path), "-af",
         "silencedetect=noise=-45dB:d=0.03", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start:\s*(-?[\d.]+)", log)]
    ends = [float(x) for x in re.findall(r"silence_end:\s*([\d.]+)", log)]
    stamp = re.search(r"Duration:\s*(\d+):(\d+):([\d.]+)", log)
    if not stamp:
        return 0.0, 0.0, 0.0
    total = (int(stamp[1]) * 3600 + int(stamp[2]) * 60 + float(stamp[3]))
    lead = ends[0] if ends and starts and starts[0] <= 0.001 else 0.0
    trail = (total - starts[-1]
             if starts and (not ends or starts[-1] > ends[-1]) else 0.0)
    return total, lead, trail


def verify(args) -> int:
    """Re-measure everything written, and name anything that looks wrong.

    Worth its own pass because the failure modes here are silent: a clip cut on
    a bad boundary still plays, it just plays the wrong half a second.
    """
    try:
        done = sorted(json.loads(LEDGER.read_text(encoding="utf-8")))
    except (FileNotFoundError, json.JSONDecodeError):
        print("Nothing in the ledger yet.", file=sys.stderr)
        return 2
    items = extract_utterances()
    problems: list[str] = []
    ratios: list[float] = []
    for key in done:
        clip = AUDIO / f"male_{key}.mp3"
        text = items.get(key, "(no longer in the curriculum)")
        if not clip.exists() or clip.stat().st_size == 0:
            problems.append(f"{text!r}: file missing or empty")
            continue
        total, lead, trail = edge_silence(clip)
        speech = speech_seconds(clip)
        if total < MIN_CUT_SECONDS:
            problems.append(f"{text!r}: only {total:.2f}s long")
        elif speech < 0.12:
            problems.append(f"{text!r}: {speech:.2f}s of speech in {total:.2f}s")
        elif lead > 0.35:
            problems.append(f"{text!r}: {lead:.2f}s of silence before it starts")
        elif trail > 0.60:
            problems.append(f"{text!r}: {trail:.2f}s of silence at the end")
        reference = AUDIO / f"female_{key}.mp3"
        if reference.exists():
            female = speech_seconds(reference)
            if female > 0:
                ratios.append(speech / female)
    ratios.sort()
    print(f"Checked {len(done)} clips; {len(problems)} look wrong.")
    if ratios:
        middle = ratios[len(ratios) // 2]
        tenth = ratios[len(ratios) // 10]
        print(f"Pace against Lenka: median {middle:.2f}x, "
              f"slowest tenth below {tenth:.2f}x, "
              f"{sum(1 for r in ratios if r < 0.8)} still under 0.80x")
    for line in problems[:20]:
        print(f"  - {line}")
    if len(problems) > 20:
        print(f"  ... and {len(problems) - 20} more")
    return 1 if problems else 0


def dry_run(args) -> int:
    picked = selection(args.min_words, args.max_words)
    groups = batches(picked, args.batch_size)
    chars = sum(len(spoken(t)) for t in picked.values())
    carrier = len(groups) * (len(LEAD_IN) + len(TAIL) + 2)
    cached = sum(1 for g in groups if (CACHE / f"{batch_id(g)}.json").exists())
    print(f"{len(picked)} utterances of {args.min_words}-{args.max_words} "
          f"words")
    print(f"{len(groups)} batches of {args.batch_size} "
          f"({cached} already cached)")
    print(f"~{chars + carrier:,} characters "
          f"({chars:,} target + {carrier:,} carrier)")
    print("\nfirst batch as it would be sent:")
    print("  " + " ".join([LEAD_IN, *(spoken(t) for _, t in groups[0]), TAIL]))
    return 0


def main() -> int:
    load_env_file()
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", nargs="?", choices=("fetch", "cut", "verify"),
                        help="omit with --dry-run to only report the plan")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--min-words", type=int, default=2)
    parser.add_argument(
        "--max-words", type=int, default=4,
        help="single words are excluded by default: measured against Lenka "
             "they sit at 0.86x, so they are not what a learner loses")
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--limit", type=int, help="fetch only N more batches")
    parser.add_argument("--rate", type=float, default=30.0,
                        help="max requests per minute")
    parser.add_argument(
        "--tempo", type=float, default=1.0,
        help="stretch every cut clip by this fixed factor. Only consulted "
             "with --match-female 0; 1.0 keeps the paragraph's own pace")
    parser.add_argument(
        "--match-female", type=float, metavar="FACTOR", nargs="?",
        const=1.25, default=1.25,
        help="stretch each clip to FACTOR times the speaking time of the "
             "female clip for the same text, instead of a fixed --tempo. "
             "Never speeds a clip up. 1.25 is calibrated, not arbitrary: it is "
             "what puts the swallowed 'To je' back on Lenka's 0.261s")
    parser.add_argument(
        "--tempo-floor", type=float, default=0.70,
        help="the most --match-female may stretch one clip. Below about 0.7 "
             "atempo starts to sound synthetic, so a clip that would need more "
             "is left short rather than made to warble")
    parser.add_argument("--force", action="store_true",
                        help="re-cut clips already in the ledger")
    args = parser.parse_args()

    if args.dry_run or args.stage is None:
        return dry_run(args)
    return {"fetch": fetch, "cut": cut, "verify": verify}[args.stage](args)


if __name__ == "__main__":
    raise SystemExit(main())
