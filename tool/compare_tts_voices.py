#!/usr/bin/env python3
"""Score candidate TTS voices on Czech, objectively.

Picking a voice by ear is slow and hard to justify, and the failure that
started this was invisible to listening anyway: cs-CZ-AntoninNeural returns
near-silence for short input, which only shows up as a number.

Two measurements per voice:

  peak dB   on isolated letter names, where the Azech male voice collapses to
            -38 dB while healthy clips sit near -8 dB
  CER       the Czech acoustic recogniser (services/phoneme-recognizer) is
            asked to transcribe the voice's own output, and the result is
            compared with the text it was given. A voice whose Czech is
            mispronounced gets transcribed wrongly, so the error rate stands in
            for "how Czech does this actually sound" without needing a listener.

Requires the recogniser running on :8080, plus AZURE_SPEECH_KEY /
AZURE_SPEECH_REGION and/or OPENAI_API_KEY in .env for whichever side is tested.

  python3 tool/compare_tts_voices.py --provider openai
  python3 tool/compare_tts_voices.py --provider azure
  python3 tool/compare_tts_voices.py --provider both --samples out/
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECOGNIZER = os.environ.get("RECOGNIZER_URL", "http://localhost:8080")

# The actual 42 letter names from unit01_lesson00 — the input class that broke
# the Czech male voice. Testing the real content rather than a sample means a
# voice that passes here is known to work on the card that ships.
LETTERS = ["a", "á", "bé", "cé", "čé", "dé", "ďé", "e", "é", "ije", "ef",
           "gé", "há", "chá", "í", "dlouhé í", "jé", "ká", "el", "em", "en",
           "eň", "o", "dlouhé ó", "pé", "kvé", "er", "eř", "es", "eš", "té",
           "ťé", "u", "ú", "ů", "vé", "dvojité vé", "iks", "ypsilon",
           "dlouhé ypsilon", "zet", "žet"]

# Connected speech, loaded with the sounds learners struggle with.
PHRASES = ["Dobrý den, jak se máte?", "Vltava je řeka.",
           "Řekni mi, kde je nádraží.", "Děkuji mnohokrát.",
           "Přeji hezký den."]

AZURE_VOICES = [
    "cs-CZ-AntoninNeural",
    "cs-CZ-VlastaNeural",
    "en-GB-OllieMultilingualNeural",
    "en-US-AdamMultilingualNeural",
]

# OpenAI voices are multilingual and follow the language of the input.
OPENAI_VOICES = ["onyx", "echo", "ash", "ballad", "alloy", "verse"]
OPENAI_MODEL = os.environ.get("OPENAI_TTS_MODEL", "gpt-4o-mini-tts")
OPENAI_INSTRUCTIONS = (
    "Speak as a warm, clear Czech language teacher. Pronounce Czech exactly as "
    "a native speaker from Prague would, including ř, č, š, ž and long vowels. "
    "When given a single letter name, say it clearly and unhurriedly."
)

# ElevenLabs voices are account-scoped IDs rather than published names, so the
# account's own library is listed unless ELEVENLABS_VOICE_IDS names a subset.
ELEVEN_MODEL = os.environ.get("ELEVENLABS_MODEL", "eleven_v3")
ELEVEN_FALLBACK_MODEL = "eleven_multilingual_v2"


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


def azure_speak(text: str, voice: str, out: Path, fmt: str) -> None:
    key = os.environ["AZURE_SPEECH_KEY"]
    region = os.environ["AZURE_SPEECH_REGION"]
    inner = html.escape(text)
    if not voice.startswith("cs-"):
        # Multilingual voices need the target language marked explicitly.
        inner = f"<lang xml:lang='cs-CZ'>{inner}</lang>"
    ssml = (
        "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' "
        f"xml:lang='cs-CZ'><voice name='{voice}'>"
        f"<prosody rate='-8%'>{inner}</prosody></voice></speak>"
    ).encode("utf-8")
    request = urllib.request.Request(
        f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml, method="POST",
    )
    request.add_header("Ocp-Apim-Subscription-Key", key)
    request.add_header("Content-Type", "application/ssml+xml")
    request.add_header("X-Microsoft-OutputFormat", fmt)
    with urllib.request.urlopen(request, timeout=60) as response:
        out.write_bytes(response.read())


def openai_speak(text: str, voice: str, out: Path, fmt: str) -> None:
    key = os.environ["OPENAI_API_KEY"]
    body = {
        "model": OPENAI_MODEL,
        "voice": voice,
        "input": text,
        "response_format": "wav" if "pcm" in fmt or "wav" in fmt else "mp3",
    }
    # Only the steerable model accepts delivery instructions.
    if OPENAI_MODEL.startswith("gpt-4o"):
        body["instructions"] = OPENAI_INSTRUCTIONS
    request = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=json.dumps(body).encode("utf-8"), method="POST",
    )
    request.add_header("Authorization", f"Bearer {key}")
    request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=90) as response:
        out.write_bytes(response.read())


def eleven_voices() -> list[str]:
    """Voice ids to test: the explicit list, else the account's own library."""
    named = os.environ.get("ELEVENLABS_VOICE_IDS", "").strip()
    if named:
        return [v.strip() for v in named.split(",") if v.strip()]
    request = urllib.request.Request("https://api.elevenlabs.io/v1/voices")
    request.add_header("xi-api-key", os.environ["ELEVENLABS_API_KEY"])
    with urllib.request.urlopen(request, timeout=30) as response:
        voices = json.loads(response.read())["voices"]
    # Keep the name alongside the id so the report is readable.
    return [f"{v['name']}:{v['voice_id']}" for v in voices]


def eleven_speak(text: str, voice: str, out: Path, fmt: str) -> None:
    voice_id = voice.split(":")[-1]
    body = {"text": text, "model_id": ELEVEN_MODEL}
    url = (f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
           "?output_format=mp3_44100_128")

    def fetch(payload: dict) -> bytes:
        request = urllib.request.Request(
            url, data=json.dumps(payload).encode("utf-8"), method="POST")
        request.add_header("xi-api-key", os.environ["ELEVENLABS_API_KEY"])
        request.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(request, timeout=90) as response:
            return response.read()

    try:
        audio = fetch(body)
    except urllib.error.HTTPError as error:
        # v3 is not enabled on every account/plan; the older multilingual model
        # is a fair comparison point rather than a blank row.
        if error.code not in (400, 403, 404):
            raise
        body["model_id"] = ELEVEN_FALLBACK_MODEL
        audio = fetch(body)

    if "pcm" in fmt or "wav" in fmt:
        mp3 = out.with_suffix(".src.mp3")
        mp3.write_bytes(audio)
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(mp3), "-ar", "16000", "-ac", "1",
             str(out)], capture_output=True, check=True)
        mp3.unlink(missing_ok=True)
    else:
        out.write_bytes(audio)


def peak_db(path: Path) -> float:
    out = subprocess.run(
        ["ffmpeg", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    match = re.search(r"max_volume:\s*(-?[\d.]+) dB", out)
    return float(match.group(1)) if match else 0.0


def recognize(wav: Path) -> str:
    data = wav.read_bytes()
    boundary = "----ttscmp"
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
        f'filename="a.wav"\r\nContent-Type: audio/wav\r\n\r\n'
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    request = urllib.request.Request(
        f"{RECOGNIZER}/recognize", data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.loads(response.read())["heard"]


def cer(reference: str, hypothesis: str) -> float:
    a = [c for c in reference.lower() if c.isalpha() or c == " "]
    b = [c for c in hypothesis.lower() if c.isalpha() or c == " "]
    if not a:
        return 1.0
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[len(b)] / len(a)


def evaluate(voice: str, speak, tmp: Path) -> dict:
    quiet = 0
    peaks = []
    for letter in LETTERS:
        path = tmp / f"{voice}_{abs(hash(letter))}.mp3"
        speak(letter, voice, path, "audio-24khz-48kbitrate-mono-mp3")
        peak = peak_db(path)
        peaks.append(peak)
        quiet += peak < -15

    errors = []
    for phrase in PHRASES:
        path = tmp / f"{voice}_p{abs(hash(phrase))}.wav"
        speak(phrase, voice, path, "riff-16khz-16bit-mono-pcm")
        errors.append(cer(phrase, recognize(path)))

    return {
        "voice": voice,
        "quiet": quiet,
        "worst_peak": min(peaks),
        "cer": sum(errors) / len(errors),
    }


def main() -> int:
    load_env_file()
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--provider", choices=("azure", "openai", "eleven", "all"),
        default="all")
    parser.add_argument("--samples", help="also write a listenable sample per voice")
    args = parser.parse_args()

    try:
        urllib.request.urlopen(f"{RECOGNIZER}/health", timeout=5)
    except Exception:
        print(f"Recogniser not reachable at {RECOGNIZER} — start it with "
              "`docker compose up -d` in services/phoneme-recognizer.",
              file=sys.stderr)
        return 2

    # Every clip is kept, not just measured: the numbers narrow the field but
    # the final call has been made by ear each time.
    tmp = Path(args.samples or "/tmp/tts_compare")
    tmp.mkdir(parents=True, exist_ok=True)
    jobs = []
    if args.provider in ("azure", "all") and os.environ.get("AZURE_SPEECH_KEY"):
        jobs += [(v, azure_speak) for v in AZURE_VOICES]
    if args.provider in ("openai", "all") and os.environ.get("OPENAI_API_KEY"):
        jobs += [(v, openai_speak) for v in OPENAI_VOICES]
    if args.provider in ("eleven", "all") and os.environ.get("ELEVENLABS_API_KEY"):
        jobs += [(v, eleven_speak) for v in eleven_voices()]
    if not jobs:
        print("No API keys found in .env for the requested provider.",
              file=sys.stderr)
        return 2

    print(f"{'voice':<32} {'quiet letters':>14} {'worst peak':>11} {'Czech CER':>10}")
    print("-" * 71)
    rows = []
    for voice, speak in jobs:
        try:
            row = evaluate(voice, speak, tmp)
            rows.append(row)
            print(f"{row['voice']:<32} {row['quiet']:>9}/{len(LETTERS):<4} "
                  f"{row['worst_peak']:10.1f} {100 * row['cer']:9.1f}%")
        except Exception as error:  # noqa: BLE001
            print(f"{voice:<32}  failed: {error}", file=sys.stderr)

    if rows:
        usable = [r for r in rows if r["quiet"] == 0]
        best = min(usable or rows, key=lambda r: r["cer"])
        print(f"\nbest: {best['voice']} — {100 * best['cer']:.1f}% CER, "
              f"{best['quiet']} quiet letters")
        print(f"clips to listen to: {tmp}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
