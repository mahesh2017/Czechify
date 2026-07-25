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

## Status

The bundled `model_int8.onnx` is a quantisation of
`facebook/wav2vec2-xlsr-53-espeak-cv-ft`, which **cannot recognise Czech ř**:
it transcribes English flawlessly but produced `r̝` on 0 of 24 ř-heavy clips.
Verified against the original PyTorch checkpoint, so it is not a conversion
artefact. This service is the plumbing, ready for a Czech-capable checkpoint.
