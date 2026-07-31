#!/usr/bin/env python3
"""Single source of truth for *which* Czech strings the app speaks.

Both generate_audio_pack.py and audio_coverage.py import from here. They used to
carry their own copies of this rule, which is how the rule silently fell behind
the app: teaching cards, listening transcripts and exam prompts were all being
spoken at runtime but never synthesized, so they fell back to device TTS.

Every field below was confirmed by tracing an actual `czechTts.speak(...)` /
`TtsButton(text: ...)` call site. Fields are deliberately NOT added just because
they contain Czech — audio nobody plays still costs money to generate:

  spoken, included
    vocabulary  word_cz, example_cz        -> SRS review, lesson player
    lesson      expected_text              -> dictation
    lesson      target_text                -> pronunciation
    lesson      question_cz                -> multiple choice
    lesson      transcript_cz              -> listening comprehension
    lesson      data.items[] name_say/say/cz/example -> teaching cards
    exam bank   audio_text                 -> mock exam listening

  NOT spoken, excluded
    lesson      data.lines[]               -> dialogue_view has no TTS at all
    srs_starter_deck.json                  -> not referenced anywhere in lib/
"""

from __future__ import annotations

import hashlib
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS = ROOT / "assets" / "curriculum" / "lessons"
VOCABULARY = ROOT / "assets" / "vocabulary"
CURRICULUM = ROOT / "assets" / "curriculum"

# Settings -> "Test voice". Must always be in the pack, otherwise the voice
# comparison silently demonstrates device TTS instead of the neural voice.
PREVIEW_TEXT = "Ahoj, jak se máš?"

# Kept byte-for-byte equivalent to TextNormalizer.forSpeech in the app so a
# pre-generated clip and a runtime speak() request resolve to the same hash.
_PARENS = re.compile(r"\([^)]*\)")
_BLANKS = re.compile(r"_+")
_SPACES = re.compile(r"\s+")
_PUNCT = re.compile(r"\s+([.,!?;:])")

VOCAB_FIELDS = ("word_cz", "example_cz")
LESSON_DATA_FIELDS = (
    "expected_text",
    "target_text",
    "question_cz",
    "transcript_cz",
)
TEACHING_ITEM_FIELDS = ("name_say", "say", "cz", "example")


def speech_text(text: str) -> str:
    """Strip editorial marks exactly as the app does before speaking."""
    text = _PARENS.sub(" ", text)
    text = _BLANKS.sub(" ", text)
    text = _SPACES.sub(" ", text)
    text = _PUNCT.sub(r"\1", text)
    return text.strip()


def key_for(text: str) -> str:
    return hashlib.sha256(
        speech_text(text).strip().lower().encode("utf-8"),
    ).hexdigest()


def _add(bucket: set[str], value) -> None:
    if isinstance(value, str) and value.strip():
        bucket.add(value.strip())


def _collect_audio_text(node, bucket: set[str]) -> None:
    """Exam banks nest questions several levels deep; walk the whole tree."""
    if isinstance(node, dict):
        _add(bucket, node.get("audio_text"))
        for value in node.values():
            _collect_audio_text(value, bucket)
    elif isinstance(node, list):
        for value in node:
            _collect_audio_text(value, bucket)


def raw_utterances() -> set[str]:
    """Every distinct Czech string the app can ask the TTS to speak."""
    found: set[str] = {PREVIEW_TEXT}

    for path in sorted(VOCABULARY.glob("*.json")):
        rows = json.loads(path.read_text(encoding="utf-8"))
        for row in rows:
            for field in VOCAB_FIELDS:
                _add(found, row.get(field))

    for path in sorted(LESSONS.glob("*.json")):
        lesson = json.loads(path.read_text(encoding="utf-8"))
        for exercise in lesson.get("exercises", []):
            data = exercise.get("data", {}) or {}
            for field in LESSON_DATA_FIELDS:
                _add(found, data.get(field))
            for item in data.get("items") or []:
                if isinstance(item, dict):
                    for field in TEACHING_ITEM_FIELDS:
                        _add(found, item.get(field))

    for path in sorted(CURRICULUM.glob("exam_bank_*.json")):
        _collect_audio_text(json.loads(path.read_text(encoding="utf-8")), found)

    return found


def extract_utterances() -> dict[str, str]:
    """{sha256 key: sanitized spoken text}, collapsing case-only duplicates."""
    by_key: dict[str, str] = {}
    for text in sorted(raw_utterances()):
        spoken = speech_text(text)
        if spoken:
            by_key[key_for(text)] = spoken
    return by_key


# ── Fill-in-the-blank prompts ────────────────────────────────────────────────
# Deleting a "___" outright leaves a stump: "Vidím ___ (káva)." becomes
# "Vidím." and, worse, "To je ___ pes." becomes the complete-but-wrong "To je
# pes." — the learner gets no cue that a word is missing. So the *hash* is still
# taken from the blank-free text (the app computes the same thing at runtime and
# must match), but the audio is synthesized with a silence where the blank was.
BREAK_MS = 500
_SENTINEL = "\x00"  # survives html.escape untouched


def ssml_inner(text: str) -> str:
    """Escaped SSML body for [text], with a pause standing in for each blank."""
    body = _PARENS.sub(" ", text)
    body = _BLANKS.sub(_SENTINEL, body)
    body = _SPACES.sub(" ", body)
    body = _PUNCT.sub(r"\1", body)
    body = html.escape(body.strip())
    return body.replace(_SENTINEL, f'<break time="{BREAK_MS}ms"/>')


def synthesis_plan() -> list[tuple[str, str, str]]:
    """(key, spoken_text, ssml_body) per clip, settings-preview phrase first.

    A blank only becomes a pause when *every* source string behind that hash has
    one; otherwise a legitimate sentence that happens to collapse to the same
    text would get a spurious silence. (Currently no such collision exists, but
    the guard keeps a future content edit from introducing one silently.)
    """
    originals: dict[str, list[str]] = {}
    for text in sorted(raw_utterances()):
        if speech_text(text):
            originals.setdefault(key_for(text), []).append(text)

    plan: list[tuple[str, str, str]] = []
    for key in sorted(originals):
        variants = originals[key]
        spoken = speech_text(variants[0])
        if all("_" in variant for variant in variants):
            body = ssml_inner(variants[0])
        else:
            body = html.escape(spoken)
        plan.append((key, spoken, body))

    preview_key = key_for(PREVIEW_TEXT)
    plan.sort(key=lambda row: (row[0] != preview_key, row[0]))
    return plan


def ordered_utterances() -> list[str]:
    """Spoken texts with the settings preview phrase guaranteed first."""
    by_key = extract_utterances()
    texts = [by_key[key] for key in sorted(by_key)]
    if PREVIEW_TEXT in texts:
        texts.remove(PREVIEW_TEXT)
    return [PREVIEW_TEXT, *texts]


if __name__ == "__main__":
    items = extract_utterances()
    chars = sum(len(v) for v in items.values())
    print(f"{len(items)} unique utterances, {chars} characters per voice.")
