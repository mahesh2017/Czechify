# Phoneme recogniser

Audio in, IPA out. Scoring lives in the app (`PhonemeScorer`), not here — this
service only recognises sounds, so the recogniser can be swapped without
touching the Czech weights or the wording learners see.

## Run

Put `model_int8.onnx` and `vocab.json` in `./models/`, then:

    docker compose up -d --build
    curl -s localhost:8080/health

Recognise a clip (the app records 16 kHz mono WAV, which is what the model
wants — other rates are resampled):

    curl -s -X POST localhost:8080/recognize -F "file=@clip.wav"
    # {"ipa": "d o b r iː  d ɛ n", "phones": [...], "inference_ms": 117}

There is also `/recognize-base64` taking `{"audio_base64": "..."}`, matching how
`whisper-proxy` is already called from the client.

## Deploying

Set `API_TOKEN` so the endpoint isn't open, and send
`Authorization: Bearer <token>`. Unset locally, auth is skipped.

Docker Desktop on Apple Silicon builds arm64. For an x86 VPS:

    docker build --platform linux/amd64 -t ceskina/phoneme-recognizer .

## Sizing

Measured, not estimated: the 339 MB int8 file needs far more RAM than its file
size suggests, because ONNX Runtime expands quantised weights at load.

| | |
|---|---|
| RSS after load | ~700 MB |
| Peak, 10 s utterance | ~906 MB |
| Latency (short word, Apple Silicon) | ~110 ms |
| Latency (10 s audio) | ~600 ms |

**Minimum 2 GB RAM / 2 vCPU; 4 GB recommended.** A shared VPS vCPU is roughly
3–5x slower than the machine these were measured on, so budget ~300–500 ms per
short word.

One worker on purpose — each holds its own copy of the model, and inference is
short and CPU-bound, so a queue in front of one worker beats several workers
contending for the same cores.

## Model

`arampacha/wav2vec2-large-xlsr-czech`, exported to ONNX and dynamically
quantised to int8 (341 MB). int8 produced transcriptions **identical to fp32 on
100% of test clips**, so the quantisation is free here.

Chosen by measurement over two alternatives:

| | multilingual espeak | MehdiHosseini… | **arampacha** |
|---|---|---|---|
| ř transcribed | 0/24 | 8/8 | **8/8** |
| noise floor (two correct voices) | 38% | 26% | **12%** |
| accent signal | 62% | 84% | 67% |
| separation | 23 pts | 58 pts | **55 pts** |

The noise floor is the number that matters: it is how often the model
contradicts itself on two *correct* pronunciations, and therefore how often a
learner gets told they are wrong when they are not.

## Coverage — do not score every word

`tool/scan_pronunciation_reliability.py` measures, per word, whether the model
hears the reference correctly and whether it agrees with itself across two
native voices. Over 1112 vocabulary items:

* **73% are reliable** on both counts (`assets/curriculum/pronunciation_reliable_words.json`)
* median match error and median voice-disagreement are both **0%**
* **single letters are unusable** — 12 one-character items averaged 117% error,
  worse than chance. `a` was heard as `e`, `č` as `tři`.

So pronunciation scoring should be gated on that list. Notably this rules out
the Unit 1 alphabet card, where items are single letters.

Regenerate after a model or content change:

    python3 tool/scan_pronunciation_reliability.py --models <dir-with-model_int8.onnx>
