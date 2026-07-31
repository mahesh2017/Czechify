# Neural Audio Pack — Runbook

Every Czech phrase the app speaks is pre-synthesized once with Azure Neural TTS,
stored in Supabase Storage, and downloaded on demand. The device's built-in TTS
is only a fallback for when a clip is missing (or the app was built without
backend credentials).

**Voices** — deliberately matched to the two teacher characters:

| Setting | Azure voice |
|---|---|
| female | `cs-CZ-VlastaNeural` |
| male | `cs-CZ-AntoninNeural` |

## How lookup works (do not break this)

1. The app sanitizes the text with `TextNormalizer.forSpeech` — strips `(hints)`
   and `___` blanks, collapses whitespace, closes up space before punctuation.
2. It hashes `sha256(sanitized.trim().toLowerCase())`.
3. It downloads `{gender}_{sha256}.mp3` from the `course-audio` bucket.

`tool/audio_utterances.py` reimplements steps 1–2 in Python and is the **single
source of truth** shared by the generator and the coverage tool.
`test/audio_pack_key_test.dart` pins the Dart and Python sides together — if it
fails, every clip is unreachable, so fix it before generating anything.

## Which text gets audio

Only fields confirmed to reach a real `speak()` call site are included — audio
nobody plays still costs money:

| Source | Field | Used by |
|---|---|---|
| vocabulary | `word_cz`, `example_cz` | SRS review, lesson player |
| lesson | `expected_text` | dictation |
| lesson | `target_text` | pronunciation |
| lesson | `question_cz` | multiple choice |
| lesson | `transcript_cz` | listening comprehension |
| lesson | `data.items[].name_say/say/cz/example` | teaching cards |
| exam bank | `audio_text` | mock exam listening |

**Deliberately excluded:** `data.lines[]` (dialogue_view has no TTS at all) and
`srs_starter_deck.json` (not referenced anywhere in `lib/`).

Adding a spoken field to the app means adding it to `audio_utterances.py` too,
or the new text silently degrades to device TTS.

## Fill-in-the-blank prompts become a pause

`TextNormalizer.forSpeech` deletes `___` so the TTS never reads it aloud as
"podtržítko". Deleting it outright, though, leaves a stump — and sometimes a
*complete but wrong* sentence, which is worse because nothing signals the gap:

| Source | Deleted | Synthesized |
|---|---|---|
| `To je ___ pes.` | "To je pes." (*That is a dog* — sounds correct!) | `To je <break 500ms/> pes.` |
| `Ona ____ knihu.` | "Ona knihu." (no verb) | `Ona <break 500ms/> knihu.` |

So the **hash still comes from the blank-free text** — the app computes the same
thing at runtime and the two must match — while the **audio is synthesized with
a 500 ms silence** where the blank was. 22 clips are affected.

The pause is only applied when *every* source string behind a hash contains a
blank, so a legitimate sentence that happens to collapse to the same text can
never pick up a spurious silence.

If a pack was generated before this existed, refresh just those clips:

```bash
python3 tool/generate_audio_pack.py --gender female --refresh-blanks
```

## Running it

### 1. Create an Azure Speech resource

Portal → *Speech service* → create. Region matters — it becomes part of the
endpoint URL.

- **F0 (free):** 500,000 characters/month, but only ~20 requests/minute.
- **S0 (pay-as-you-go):** ~$15 per million characters, far higher rate limit.

### 2. Set credentials

```bash
export AZURE_SPEECH_KEY='...'
export AZURE_SPEECH_REGION='westeurope'   # must match the resource
```

### 3. Check scope and cost first

```bash
python3 tool/audio_coverage.py --write-missing build/audio_missing.txt
```

Prints how many utterances still need clips and the character count (the thing
Azure bills for). Always run this before a generation run.

### 4. Generate — one voice at a time

```bash
# Paid S0 tier
python3 tool/generate_audio_pack.py --gender female
python3 tool/generate_audio_pack.py --gender male

# Free F0 tier — must throttle, or every request 429s
python3 tool/generate_audio_pack.py --gender female --rate 18
```

The run is **resumable**: existing non-empty MP3s are kept, so an interrupted
run can simply be re-run. Empty/partial files are deleted rather than cached as
"done". `--limit N` synthesizes only the first N missing files — use it to
sanity-check the voice before committing to a full run.

### 5. Verify, then upload

```bash
python3 tool/audio_coverage.py            # expect 100%
python3 tool/upload_audio_pack.py --dry-run
python3 tool/upload_audio_pack.py
```

Requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (service role — never
commit it). The manifest uploads **last**, so the app never sees a manifest
pointing at files that aren't there yet.

### 6. Confirm on device

Neural audio is inert unless the build has Supabase credentials:

```bash
tool/run_prod.sh -d <device-id>          # uses env/prod.json
```

A plain `flutter run` has no `SUPABASE_URL`, so `CzechTts` logs
`[czech_tts] Neural audio disabled: ...` and quietly uses device TTS. If the
voice sounds like the system voice, check this first.

Then: Settings → **Test voice** plays `Ahoj, jak se máš?`, which is always the
first clip in the pack — a quick way to tell neural from device TTS.

## Current state

| | |
|---|---|
| Unique utterances | 2,946 |
| Clips at full coverage | 5,892 (×2 voices) |
| Characters per voice | ~56,000 |
| Full pack size | ~79 MB (avg 13.7 KB/clip) |

`assets/audio/` is **not** bundled in `pubspec.yaml` — clips are downloaded and
cached at runtime, so they don't inflate the app binary.

## Not yet covered: the English unit intros

The 31 teaching-card intros are English and currently use on-device TTS via
`EnglishTts`. Giving them the same treatment would need:

1. An English Azure voice (e.g. `en-US-JennyNeural` / `en-US-GuyNeural`).
2. A second manifest or locale key — the current one is `cs-CZ` only.
3. A neural playback path in `EnglishTts`, which today only calls `flutter_tts`.

Roughly 62 clips (31 × 2 voices). Worth doing — recorded narration is the single
biggest quality jump available for the teaching cards — but it is an app change,
not just a generation run.
