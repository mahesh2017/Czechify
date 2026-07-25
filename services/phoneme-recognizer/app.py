"""Phoneme recognition service: audio in, IPA out.

Deliberately dumb. It recognises sounds and returns IPA — it does not score,
weight, or generate feedback. That lives in the app's PhonemeScorer, alongside
the Czech-specific weights and the wording learners see. Keeping the split here
means the recogniser can be swapped (fine-tuned model, different architecture,
on-device) without touching any pedagogy.

The model and its vocab are mounted, not baked into the image, so a new
checkpoint is a volume swap rather than a rebuild.
"""

from __future__ import annotations

import base64
import io
import json
import os
import time
from contextlib import asynccontextmanager

import numpy as np
import onnxruntime as ort
import soundfile as sf
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from pydantic import BaseModel

MODEL_DIR = os.environ.get("MODEL_DIR", "/models")
MODEL_FILE = os.environ.get("MODEL_FILE", "model_int8.onnx")
API_TOKEN = os.environ.get("API_TOKEN", "")
TARGET_SR = 16000
MAX_SECONDS = float(os.environ.get("MAX_SECONDS", "20"))

_state: dict = {}


def _load_model() -> None:
    opts = ort.SessionOptions()
    opts.log_severity_level = 3
    # Inference is short and CPU-bound, and the container is sized for one
    # worker, so let ORT use every core it can see for a single request rather
    # than running requests in parallel.
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

    path = os.path.join(MODEL_DIR, MODEL_FILE)
    if not os.path.exists(path):
        raise RuntimeError(
            f"No model at {path}. Mount a directory containing {MODEL_FILE} "
            "and vocab.json at /models."
        )

    started = time.time()
    session = ort.InferenceSession(path, opts, providers=["CPUExecutionProvider"])
    with open(os.path.join(MODEL_DIR, "vocab.json"), encoding="utf-8") as fh:
        vocab = json.load(fh)

    _state["session"] = session
    _state["input"] = session.get_inputs()[0].name
    _state["fp16"] = session.get_inputs()[0].type == "tensor(float16)"
    _state["inv_vocab"] = {index: symbol for symbol, index in vocab.items()}
    _state["model"] = MODEL_FILE
    _state["load_seconds"] = round(time.time() - started, 2)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Loaded once at startup. Loading per request would cost ~0.4s and several
    # hundred MB of churn every time.
    _load_model()
    yield
    _state.clear()


app = FastAPI(title="Czech phoneme recogniser", version="1.0", lifespan=lifespan)


def require_token(authorization: str | None = Header(default=None)) -> None:
    """No-op when API_TOKEN is unset, so local runs need no ceremony."""
    if not API_TOKEN:
        return
    expected = f"Bearer {API_TOKEN}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Invalid or missing token")


# ── audio ────────────────────────────────────────────────────────────────────

def decode_audio(raw: bytes) -> np.ndarray:
    try:
        audio, sample_rate = sf.read(io.BytesIO(raw), dtype="float32", always_2d=True)
    except Exception as error:  # noqa: BLE001 - surfaced to the caller as 400
        raise HTTPException(status_code=400, detail=f"Unreadable audio: {error}")

    audio = audio.mean(axis=1)  # mono

    if sample_rate != TARGET_SR:
        # The app records at 16 kHz already; this is a safety net for anything
        # else, and linear interpolation is adequate for speech.
        duration = audio.shape[0] / sample_rate
        target_len = int(round(duration * TARGET_SR))
        audio = np.interp(
            np.linspace(0, audio.shape[0] - 1, target_len),
            np.arange(audio.shape[0]),
            audio,
        ).astype(np.float32)

    if audio.size == 0:
        raise HTTPException(status_code=400, detail="Empty audio")
    if audio.size / TARGET_SR > MAX_SECONDS:
        raise HTTPException(
            status_code=413,
            detail=f"Audio longer than {MAX_SECONDS:.0f}s",
        )

    # preprocessor_config.json for this model sets do_normalize: true.
    return (audio - audio.mean()) / (audio.std() + 1e-7)


def ctc_decode(logits: np.ndarray) -> list[str]:
    """Greedy CTC: argmax, collapse repeats, drop blanks and specials."""
    inv = _state["inv_vocab"]
    skip = {"<pad>", "<s>", "</s>", "<unk>", "|"}
    out: list[str] = []
    previous = -1
    for index in logits.argmax(axis=-1):
        index = int(index)
        if index != previous and index != 0:
            symbol = inv.get(index, "")
            if symbol and symbol not in skip:
                out.append(symbol)
        previous = index
    return out


def recognize(audio: np.ndarray) -> dict:
    session = _state["session"]
    dtype = np.float16 if _state["fp16"] else np.float32
    started = time.time()
    logits = session.run(None, {_state["input"]: audio[None, :].astype(dtype)})[0]
    elapsed_ms = round(1000 * (time.time() - started))
    phones = ctc_decode(logits[0].astype(np.float32))
    return {
        "ipa": " ".join(phones),
        "phones": phones,
        "audio_seconds": round(audio.size / TARGET_SR, 2),
        "inference_ms": elapsed_ms,
        "model": _state["model"],
    }


# ── API ──────────────────────────────────────────────────────────────────────

class Base64Request(BaseModel):
    audio_base64: str


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok" if "session" in _state else "loading",
        "model": _state.get("model"),
        "load_seconds": _state.get("load_seconds"),
    }


@app.post("/recognize", dependencies=[Depends(require_token)])
async def recognize_upload(file: UploadFile = File(...)) -> dict:
    """Multipart upload — what the Flutter client posts."""
    return recognize(decode_audio(await file.read()))


@app.post("/recognize-base64", dependencies=[Depends(require_token)])
def recognize_base64(body: Base64Request) -> dict:
    """Base64 variant, matching how the existing whisper-proxy is called."""
    try:
        raw = base64.b64decode(body.audio_base64, validate=True)
    except Exception as error:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"Bad base64: {error}")
    return recognize(decode_audio(raw))
