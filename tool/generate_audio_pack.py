#!/usr/bin/env python3
"""Extract Czech utterances and synthesize a deterministic Azure audio pack.

Requires AZURE_SPEECH_KEY and AZURE_SPEECH_REGION unless --dry-run is used.
The script is resumable: existing non-empty MP3s are retained.
"""

from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path
import sys
import time
from datetime import datetime, timezone
import urllib.error
import urllib.request

import audio_utterances as au  # noqa: E402 - local tool module

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"


class RateLimited(Exception):
    """Azure returned 429. Carries the server's suggested wait, if any."""

    def __init__(self, retry_after: float) -> None:
        super().__init__(f"rate limited; retry after {retry_after}s")
        self.retry_after = retry_after


def synthesize(
    ssml_body: str, destination: Path, key: str, region: str, voice: str,
) -> None:
    """[ssml_body] is already escaped and may contain <break/> tags."""
    endpoint = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    ssml = (
        "<speak version='1.0' xml:lang='cs-CZ'>"
        f"<voice name='{html.escape(voice)}'><prosody rate='-8%'>"
        f"{ssml_body}</prosody></voice></speak>"
    ).encode("utf-8")
    request = urllib.request.Request(endpoint, data=ssml, method="POST")
    request.add_header("Ocp-Apim-Subscription-Key", key)
    request.add_header("Content-Type", "application/ssml+xml")
    request.add_header("X-Microsoft-OutputFormat", "audio-24khz-48kbitrate-mono-mp3")
    request.add_header("User-Agent", "ceskina-pro-audio-pack")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            audio = response.read()
    except urllib.error.HTTPError as error:
        if error.code == 429:
            # The free (F0) tier allows only ~20 requests/minute, so a bulk run
            # will hit this constantly unless --rate is set. Honour the
            # server's own backoff hint when it sends one.
            raise RateLimited(float(error.headers.get("Retry-After") or 5)) from error
        raise
    # A truncated/zero-byte response would otherwise be cached as a "done" file
    # and silently leave a gap in the pack.
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
    parser.add_argument("--dry-run", action="store_true", help="extract only; do not call Azure")
    parser.add_argument("--scope", choices=("a1", "a2", "all"), default="all")
    parser.add_argument(
        "--unit", action="append", type=int, dest="units",
        help="synthesize only this curriculum unit; repeat for multiple units",
    )
    parser.add_argument("--gender", choices=("female", "male"), default="female")
    parser.add_argument("--voice", help="override the Azure voice name")
    parser.add_argument(
        "--texts", nargs="+",
        help="re-synthesize only these exact utterances while rebuilding the "
             "complete manifest",
    )
    parser.add_argument(
        "--replace-existing", action="store_true",
        help="replace existing files for --texts; use for a small quality "
             "repair without regenerating a whole voice pack",
    )
    parser.add_argument(
        "--record-azure-fallback", action="store_true",
        help="for male --texts, record that the repaired clips now use Azure "
             "rather than ElevenLabs without regenerating them",
    )
    parser.add_argument("--limit", type=int, help="synthesize only the first N missing files")
    parser.add_argument(
        "--manifest-only", action="store_true",
        help="rebuild the manifest from the clips already on disk, "
             "synthesizing nothing. Use after another tool has written clips "
             "— the male pack is largely ElevenLabs, and a plain run would "
             "fill its gaps with Azure's Antonin, which is the voice this "
             "project rejected",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="regenerate this gender's whole pack: delete its existing clips "
             "up front, then synthesize from scratch. Deleting first (rather "
             "than overwriting as we go) keeps the run resumable — if it is "
             "interrupted, re-run WITHOUT --force to finish the remainder.",
    )
    parser.add_argument(
        "--refresh-blanks",
        action="store_true",
        help="re-synthesize fill-in-the-blank prompts so they get the pause "
             "(use once on a pack generated before pauses were added)",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=100.0,
        help="max requests per minute. Azure free tier (F0) allows ~20; "
             "the paid standard tier (S0) allows ~200. Default 100.",
    )
    args = parser.parse_args()

    plan = au.synthesis_plan()
    allowed_keys = set(
        au.scoped_utterances(
            args.scope,
            set(args.units) if args.units else None,
        )
    )
    selected_texts = set(args.texts or [])
    if args.record_azure_fallback and (
        args.gender != "male" or not selected_texts
    ):
        parser.error("--record-azure-fallback requires --gender male and --texts")
    # Every one of these deletes clips before regenerating them, and
    # --manifest-only never regenerates anything. Combining them would empty
    # the pack and then write a manifest faithfully recording that it is empty.
    if args.manifest_only:
        conflicting = [
            name for name, on in (
                ("--force", args.force),
                ("--replace-existing", args.replace_existing),
                ("--refresh-blanks", args.refresh_blanks),
            ) if on
        ]
        if conflicting:
            parser.error(
                f"--manifest-only cannot be combined with {', '.join(conflicting)}"
            )
    if selected_texts:
        known_texts = {text for _, text, _ in plan}
        unknown = selected_texts - known_texts
        if unknown:
            parser.error(f"--texts not found in the synthesis plan: {sorted(unknown)}")
    if args.dry_run:
        paused = [row for row in plan if "<break" in row[2]]
        print(f"Found {len(plan)} unique Czech utterances "
              f"({len(paused)} with a fill-in-the-blank pause).")
        for key, text, body in plan[:20]:
            print(f"{key}  {text}")
        if len(plan) > 20:
            print(f"... and {len(plan) - 20} more")
        if paused:
            print("\nBlank prompts synthesized with a pause:")
            for key, text, body in paused[:10]:
                print(f"  {text!r}\n    -> {body}")
        return 0

    voice = args.voice or {
        "female": "cs-CZ-VlastaNeural",
        "male": "cs-CZ-AntoninNeural",
    }[args.gender]
    speech_key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not args.manifest_only and (not speech_key or not region):
        print("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION.", file=sys.stderr)
        return 2

    min_interval = 60.0 / args.rate if args.rate > 0 else 0.0
    last_call = 0.0

    AUDIO.mkdir(parents=True, exist_ok=True)
    if args.force:
        # Scoped to this gender so regenerating one voice never touches the
        # other. The clips are tracked in git, so a mistake here is recoverable
        # with `git checkout -- assets/audio`.
        stale = sorted(AUDIO.glob(f"{args.gender}_*.mp3"))
        for path in stale:
            path.unlink()
        print(f"--force: removed {len(stale)} existing {args.gender} clips.")
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        manifest = {}
    voices = manifest.get("voices", {})
    entries: dict[str, str] = {}
    generated = 0
    for index, (digest, text, ssml_body) in enumerate(plan, 1):
        filename = f"{args.gender}_{digest}.mp3"
        destination = AUDIO / filename
        # Clips generated before blanks became pauses must be re-synthesized;
        # they sound complete but are missing a word.
        if args.refresh_blanks and "<break" in ssml_body and destination.exists():
            destination.unlink()
        if args.replace_existing and text in selected_texts and destination.exists():
            destination.unlink()
        if (
            not args.manifest_only
            and digest in allowed_keys
            and (not destination.exists() or destination.stat().st_size == 0)
        ):
            if args.limit is not None and generated >= args.limit:
                continue
            for attempt in range(5):
                # Stay under the account's requests-per-minute ceiling.
                wait = min_interval - (time.monotonic() - last_call)
                if wait > 0:
                    time.sleep(wait)
                try:
                    last_call = time.monotonic()
                    synthesize(ssml_body, destination, speech_key, region, voice)
                    generated += 1
                    break
                except RateLimited as error:
                    # Not counted as a real attempt failure: back off and retry.
                    time.sleep(error.retry_after)
                except (urllib.error.URLError, TimeoutError, RuntimeError) as error:
                    # Never leave a partial file behind — it would be treated as
                    # already-generated on the next resume.
                    if destination.exists() and destination.stat().st_size == 0:
                        destination.unlink()
                    if attempt == 4:
                        print(f"Failed: {text}: {error}", file=sys.stderr)
                        break
                    time.sleep(2 ** attempt)
        if destination.exists() and destination.stat().st_size > 0:
            entries[digest] = f"assets/audio/{filename}"
        if not args.manifest_only:
            print(f"[{index}/{len(plan)}] {text}")

    if args.record_azure_fallback:
        ledger_path = AUDIO / "eleven_done.json"
        try:
            oliver = set(json.loads(ledger_path.read_text(encoding="utf-8")))
        except (FileNotFoundError, json.JSONDecodeError):
            oliver = set()
        fallback_keys = {
            digest for digest, text, _ in plan if text in selected_texts
        }
        removed = oliver & fallback_keys
        if removed:
            ledger_path.write_text(json.dumps(sorted(oliver - removed), indent=0),
                                   encoding="utf-8")
            print(f"Recorded {len(removed)} Azure fallback clip(s) in the voice ledger.")

    # Part of the male pack is ElevenLabs Oliver, not Azure — recording only
    # the Azure voice here would tell the next person regenerating this pack
    # that every clip came from one engine, and they would overwrite the other.
    name = voice
    try:
        oliver = set(json.loads(
            (AUDIO / "eleven_done.json").read_text(encoding="utf-8")))
        shared = len(oliver & set(entries))
        if args.gender == "male" and shared:
            name = f"{voice} (+{shared} ElevenLabs Oliver)"
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    # Build v3 entries: {path, sha256, size} per clip so clients can detect
    # re-recorded audio for unchanged text and re-download instead of playing
    # stale bytes forever.
    entry_objects: dict[str, dict] = {}
    for digest, rel_path in sorted(entries.items()):
        clip_path = AUDIO / Path(rel_path).name
        if clip_path.exists() and clip_path.stat().st_size > 0:
            import hashlib
            sha = hashlib.sha256(clip_path.read_bytes()).hexdigest()
            entry_objects[digest] = {
                "path": rel_path,
                "sha256": sha,
                "size": clip_path.stat().st_size,
            }
        else:
            # Missing file — keep the path so coverage reports still work,
            # but without checksum metadata.
            entry_objects[digest] = {"path": rel_path}

    voices[args.gender] = {
        "name": name,
        "entries": dict(sorted(entry_objects.items())),
    }
    MANIFEST.write_text(json.dumps({
        "version": 3, "locale": "cs-CZ", "voices": voices,
        "revision": datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S"),
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"{args.gender.title()} manifest contains {len(entries)} files; "
        f"generated {generated} this run."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
