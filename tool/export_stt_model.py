#!/usr/bin/env python3
"""Export a Czech wav2vec2 CTC model to int8 ONNX for on-device recognition.

The first Czech recogniser was exported by hand and the script was not kept, so
reproducing it meant rebuilding the environment from memory. This one is
checked in: the export is a build step, not a one-off.

Why int8: the fp32 checkpoint is ~360 MB, which is a hostile download and a
large resident footprint on a phone. Dynamic int8 quantisation of the MatMul
weights cuts that to roughly a third. It is verified rather than assumed — the
script decodes the same audio through both graphs and reports whether the
transcripts agree, because a quantisation that silently degrades Czech
diacritics would be worse than a larger file.

    python3 tool/export_stt_model.py --dry-run
    python3 tool/export_stt_model.py
    python3 tool/export_stt_model.py --model fav-kky/wav2vec2-base-cs-80k-ClTRUS

Needs torch + transformers, which the app repo does not otherwise depend on.
Use a throwaway virtualenv; nothing here ships in the app.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = "fav-kky/wav2vec2-base-cs-80k-ClTRUS"
DEFAULT_OUT = ROOT / "services" / "czech-stt" / "models"

# 16 kHz mono is what wav2vec2 expects; anything else must be resampled before
# it reaches the model or the transcript is nonsense.
SAMPLE_RATE = 16_000


def megabytes(path: Path) -> float:
    return path.stat().st_size / 1e6


def export(model_id: str, out_dir: Path, opset: int) -> Path:
    import torch
    from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

    print(f"Loading {model_id} …")
    processor = Wav2Vec2Processor.from_pretrained(model_id)
    model = Wav2Vec2ForCTC.from_pretrained(model_id)
    model.eval()

    out_dir.mkdir(parents=True, exist_ok=True)
    fp32 = out_dir / "model_fp32.onnx"

    # One second of silence is enough to trace the graph; the time axis is
    # marked dynamic so any utterance length works at runtime.
    dummy = torch.zeros(1, SAMPLE_RATE, dtype=torch.float32)
    print(f"Exporting to ONNX (opset {opset}) …")
    torch.onnx.export(
        model,
        dummy,
        str(fp32),
        input_names=["input_values"],
        output_names=["logits"],
        dynamic_axes={
            "input_values": {0: "batch", 1: "samples"},
            "logits": {0: "batch", 1: "frames"},
        },
        opset_version=opset,
        do_constant_folding=True,
    )

    # The vocabulary has to travel with the model: CTC output is indices into
    # this table, and a mismatched vocab decodes to plausible-looking gibberish.
    vocab = processor.tokenizer.get_vocab()
    (out_dir / "vocab.json").write_text(
        json.dumps(vocab, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"  vocab: {len(vocab)} tokens")
    return fp32


def quantize(fp32: Path) -> Path:
    from onnxruntime.quantization import QuantType, quantize_dynamic

    int8 = fp32.with_name("model_int8.onnx")
    print("Quantising to int8 …")
    quantize_dynamic(
        model_input=str(fp32),
        model_output=str(int8),
        weight_type=QuantType.QInt8,
    )
    return int8


def decode(session, vocab_inverse: dict[int, str], audio) -> str:
    """CTC greedy decode: argmax per frame, drop blanks and repeats."""
    import numpy as np

    logits = session.run(None, {"input_values": audio})[0][0]
    ids = logits.argmax(axis=-1)
    out: list[str] = []
    previous = -1
    for token_id in ids:
        if token_id != previous and token_id != 0:
            out.append(vocab_inverse.get(int(token_id), ""))
        previous = int(token_id)
    return "".join(out).replace("|", " ").strip()


def verify(fp32: Path, int8: Path, out_dir: Path, clips: list[Path]) -> bool:
    """Both graphs must produce the same transcript on real Czech audio."""
    import numpy as np
    import onnxruntime as ort
    import soundfile as sf

    vocab = json.loads((out_dir / "vocab.json").read_text(encoding="utf-8"))
    inverse = {index: token for token, index in vocab.items()}

    sessions = {
        "fp32": ort.InferenceSession(str(fp32), providers=["CPUExecutionProvider"]),
        "int8": ort.InferenceSession(str(int8), providers=["CPUExecutionProvider"]),
    }

    agreed = True
    for clip in clips:
        samples, rate = sf.read(str(clip), dtype="float32")
        if samples.ndim > 1:
            samples = samples.mean(axis=1)
        if rate != SAMPLE_RATE:
            print(f"  {clip.name}: {rate} Hz, skipping (needs {SAMPLE_RATE})")
            continue
        audio = samples.reshape(1, -1).astype("float32")

        results = {}
        for label, session in sessions.items():
            started = time.perf_counter()
            results[label] = decode(session, inverse, audio)
            elapsed = time.perf_counter() - started
            print(f"  {clip.name:<28} {label}  {elapsed:5.2f}s  {results[label]!r}")
        if results["fp32"] != results["int8"]:
            agreed = False
            print("     ^ int8 DIFFERS from fp32")
    return agreed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--opset", type=int, default=14)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-fp32", action="store_true",
                        help="keep the fp32 graph (it is only needed to verify)")
    parser.add_argument("--clips", nargs="*", type=Path,
                        help="16 kHz wav files to verify with")
    args = parser.parse_args()

    print(f"model:  {args.model}")
    print(f"output: {args.out}")
    if args.dry_run:
        print("\nDry run — nothing downloaded or written.")
        return 0

    try:
        import torch  # noqa: F401
        import transformers  # noqa: F401
    except ImportError:
        print("torch and transformers are required:\n"
              "  python3 -m venv /tmp/sttenv\n"
              "  /tmp/sttenv/bin/pip install torch transformers onnx "
              "onnxruntime soundfile\n"
              "  /tmp/sttenv/bin/python tool/export_stt_model.py",
              file=sys.stderr)
        return 2

    fp32 = export(args.model, args.out, args.opset)
    int8 = quantize(fp32)

    print(f"\n  fp32: {megabytes(fp32):7.1f} MB")
    print(f"  int8: {megabytes(int8):7.1f} MB  "
          f"({100 * megabytes(int8) / megabytes(fp32):.0f}% of fp32)")

    clips = args.clips or []
    if clips:
        print("\nVerifying int8 against fp32:")
        if verify(fp32, int8, args.out, clips):
            print("  int8 matches fp32 on every clip.")
        else:
            print("  int8 diverged — do not ship without listening to these.",
                  file=sys.stderr)

    if not args.keep_fp32:
        fp32.unlink(missing_ok=True)
        print(f"\nRemoved fp32 graph (--keep-fp32 to retain).")
    print(f"Ready: {int8}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
