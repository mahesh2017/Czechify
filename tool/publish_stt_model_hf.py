#!/usr/bin/env python3
"""Publish the int8 ONNX Czech recogniser to a Hugging Face repo.

The app downloads a ~340 MB model on first run. Supabase will not host it on
the free plan — objects are capped at 50 MB, and its 5 GB monthly egress is
shared with the course audio, so roughly thirteen downloads would take the
whole app down. Hugging Face is built to serve model weights, costs nothing,
and has no such cliff.

Hugging Face does not already have what we need: the upstream repo ships a
PyTorch checkpoint, and the ONNX int8 file is our own conversion. So this
publishes that derivative — which the upstream Apache-2.0 licence explicitly
permits, provided the original is credited. The model card below does that.

    HF_TOKEN=hf_... python3 tool/publish_stt_model_hf.py --repo you/czechify-stt
    HF_TOKEN=hf_... python3 tool/publish_stt_model_hf.py --repo you/czechify-stt --dry-run

Needs `huggingface_hub`, which is not an app dependency — use the same
throwaway virtualenv as the export script.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "services" / "phoneme-recognizer" / "models" / "model_int8.onnx"
VOCAB = ROOT / "assets" / "stt" / "vocab.json"
UPSTREAM = "arampacha/wav2vec2-large-xlsr-czech"

CARD = """---
license: apache-2.0
language: cs
library_name: onnx
tags:
  - automatic-speech-recognition
  - czech
  - onnx
  - wav2vec2
base_model: {upstream}
---

# Czech speech recognition, ONNX int8

`model_int8.onnx` is an ONNX export of [{upstream}](https://huggingface.co/{upstream}),
dynamically quantised to int8 for on-device use.

It exists so that a language-learning app can check pronunciation **without
sending the learner's voice anywhere**. Recognition runs entirely on the
phone, which removes the recording from the scope of any international data
transfer.

## Why int8

| | size |
|---|---|
| fp32 | ~1.3 GB |
| int8 | ~340 MB |

The int8 graph produced transcripts identical to fp32 on the Czech clips it
was verified against, so the reduction costs nothing measurable in accuracy.

## Measured performance

On a MediaTek Dimensity 700 (a mid-range 2020 phone), transcribing 3 seconds
of audio:

| | |
|---|---|
| model load, once | 2.46 s |
| first inference | 1.53 s |
| steady-state median | **1.24 s** |
| real-time factor | **0.41** |

## Usage

Input `input_values`: float32 `[1, samples]`, 16 kHz mono, range -1..1.
Output `logits`: float32 `[1, frames, 41]`. Decode greedily with CTC, treating
`[PAD]` (index 0) as the blank and collapsing repeated tokens. `vocab.json`
maps token to index; `|` is the word separator.

## Credit and licence

All of the modelling work belongs to the authors of
[{upstream}](https://huggingface.co/{upstream}). This repository contains only
a format conversion. Apache-2.0, as upstream.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True,
                        help="target repo id, e.g. yourname/czechify-stt")
    parser.add_argument("--model", type=Path, default=MODEL)
    parser.add_argument("--private", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.model.exists():
        print(f"No model at {args.model} — run tool/export_stt_model.py first.",
              file=sys.stderr)
        return 2

    size = args.model.stat().st_size
    digest = hashlib.sha256(args.model.read_bytes()).hexdigest()
    url = (f"https://huggingface.co/{args.repo}/resolve/main/model_int8.onnx")

    print(f"repo:   {args.repo}{' (private)' if args.private else ''}")
    print(f"model:  {size / 1e6:.1f} MB")
    print(f"sha256: {digest}")
    print(f"url:    {url}")

    if args.dry_run:
        print("\nDry run — nothing uploaded.")
        print("\nAfter publishing, build with:")
        print(f"  --dart-define=STT_MODEL_URL={url} \\")
        print(f"  --dart-define=STT_MODEL_BYTES={size}")
        return 0

    token = os.environ.get("HF_TOKEN")
    if not token:
        print("Set HF_TOKEN to a write token from "
              "https://huggingface.co/settings/tokens", file=sys.stderr)
        return 2

    try:
        from huggingface_hub import HfApi
    except ImportError:
        print("huggingface_hub is required:\n"
              "  /tmp/sttenv/bin/pip install huggingface_hub\n"
              "  /tmp/sttenv/bin/python tool/publish_stt_model_hf.py …",
              file=sys.stderr)
        return 2

    api = HfApi(token=token)
    api.create_repo(args.repo, repo_type="model", exist_ok=True,
                    private=args.private)

    card = ROOT / "build" / "hf_model_card.md"
    card.parent.mkdir(parents=True, exist_ok=True)
    card.write_text(CARD.format(upstream=UPSTREAM), encoding="utf-8")

    for path, name in (
        (args.model, "model_int8.onnx"),
        (VOCAB, "vocab.json"),
        (card, "README.md"),
    ):
        if not path.exists():
            print(f"  skipping {name}: {path} not found")
            continue
        print(f"  uploading {name} ({path.stat().st_size / 1e6:.1f} MB)…",
              flush=True)
        api.upload_file(path_or_fileobj=str(path), path_in_repo=name,
                        repo_id=args.repo, repo_type="model")

    print(f"\nPublished: https://huggingface.co/{args.repo}")
    print("\nBuild with:")
    print(f"  --dart-define=STT_MODEL_URL={url} \\")
    print(f"  --dart-define=STT_MODEL_BYTES={size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
