# Deliberately not baking the model in: it is ~339 MB and will be replaced by a
# Czech-capable checkpoint. Mounting it keeps the image small and makes a new
# model a volume swap rather than a rebuild.
FROM python:3.12-slim

# libsndfile is what soundfile binds to for WAV decoding.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libsndfile1 curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Run unprivileged.
RUN useradd --create-home --uid 10001 appuser
USER appuser

ENV MODEL_DIR=/models \
    MODEL_FILE=model_int8.onnx \
    PYTHONUNBUFFERED=1

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS http://localhost:8080/health || exit 1

# One worker on purpose: each holds its own ~900 MB copy of the model, and
# inference is short and CPU-bound, so a queue in front of one worker beats
# several workers competing for the same cores.
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
