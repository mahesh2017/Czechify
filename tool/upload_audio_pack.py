#!/usr/bin/env python3
"""Upload the generated audio pack + manifest to the `course-audio` bucket.

Uploads every MP3 referenced by assets/audio/manifest.json to the bucket root
as its basename (the app downloads by basename), then the manifest last so the
app never sees a manifest that points at files not yet uploaded. Idempotent:
re-runs overwrite (upsert), so an interrupted upload can simply be re-run.

Requires (never commit these):
  export SUPABASE_URL='https://<ref>.supabase.co'
  export SUPABASE_SERVICE_ROLE_KEY='...'   # service role, storage write

Usage:
  python3 tool/upload_audio_pack.py --dry-run
  python3 tool/upload_audio_pack.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "manifest.json"
# English unit-intro narration ships beside the Czech pack in the same
# bucket, under its own manifest (the Czech one is single-locale).
MANIFEST_EN = AUDIO / "manifest_en.json"
BUCKET = "course-audio"


def load_env_file() -> None:
    """Read credentials from a gitignored .env so they need supplying once.

    Environment variables already set win, so CI and one-off overrides still
    work. Only the storage-write key needs this; the app itself builds from
    env/prod.json, which holds nothing secret.
    """
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


def manifest_files(manifest: dict) -> list[str]:
    """Basenames of every MP3 the manifest references, de-duplicated."""
    names: set[str] = set()
    for voice in manifest.get("voices", {}).values():
        for path in voice.get("entries", {}).values():
            names.add(Path(path).name)
    return sorted(names)


def list_bucket(base: str, token: str) -> list[str]:
    """Every object name in the bucket, following pagination."""
    names: list[str] = []
    offset = 0
    while True:
        body = json.dumps(
            {"prefix": "", "limit": 1000, "offset": offset},
        ).encode("utf-8")
        request = urllib.request.Request(
            f"{base}/storage/v1/object/list/{BUCKET}", data=body, method="POST",
        )
        request.add_header("Authorization", f"Bearer {token}")
        request.add_header("apikey", token)
        request.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(request, timeout=60) as response:
            page = json.loads(response.read().decode("utf-8"))
        if not page:
            return names
        names.extend(item["name"] for item in page if item.get("name"))
        offset += len(page)


def delete_objects(base: str, token: str, names: list[str]) -> None:
    """Storage delete takes a batch of names; chunk so the body stays sane."""
    for start in range(0, len(names), 100):
        chunk = names[start:start + 100]
        body = json.dumps({"prefixes": chunk}).encode("utf-8")
        request = urllib.request.Request(
            f"{base}/storage/v1/object/{BUCKET}", data=body, method="DELETE",
        )
        request.add_header("Authorization", f"Bearer {token}")
        request.add_header("apikey", token)
        request.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status not in (200, 204):
                raise RuntimeError(f"delete -> HTTP {response.status}")


def put_object(url: str, data: bytes, content_type: str, token: str) -> None:
    request = urllib.request.Request(url, data=data, method="POST")
    request.add_header("Authorization", f"Bearer {token}")
    request.add_header("apikey", token)
    request.add_header("Content-Type", content_type)
    # x-upsert lets a re-run overwrite instead of 409-ing on existing objects.
    request.add_header("x-upsert", "true")
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status not in (200, 201):
            raise RuntimeError(f"{url} -> HTTP {response.status}")


def main() -> int:
    load_env_file()
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="only upload objects the bucket does not already have. Adding a "
             "handful of clips otherwise re-pushes the whole pack, which is "
             "minutes of transfer for no change.",
    )
    parser.add_argument(
        "--prune",
        action="store_true",
        help="after uploading, delete bucket objects the manifest no longer "
             "references — e.g. clips of course text that has since been edited",
    )
    args = parser.parse_args()

    if not MANIFEST.exists():
        print("No manifest — run tool/generate_audio_pack.py first.", file=sys.stderr)
        return 2
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    files = manifest_files(manifest)
    manifest_en = (json.loads(MANIFEST_EN.read_text(encoding="utf-8"))
                   if MANIFEST_EN.exists() else None)
    if manifest_en:
        files += manifest_files(manifest_en)

    missing_local = [n for n in files if not (AUDIO / n).exists()]
    if missing_local:
        print(f"{len(missing_local)} manifest files are missing on disk, e.g. "
              f"{missing_local[:3]} — generate them before uploading.", file=sys.stderr)
        return 2

    print(f"Manifest references {len(files)} MP3 files.")
    if args.dry_run:
        print("Dry run: would upload those files + manifest.json to "
              f"bucket '{BUCKET}'.")
        return 0

    base = os.environ.get("SUPABASE_URL")
    token = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not base or not token:
        print("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.", file=sys.stderr)
        return 2
    base = base.rstrip("/")

    if args.skip_existing:
        present = set(list_bucket(base, token))
        pending = [n for n in files if n not in present]
        print(f"{len(files) - len(pending)} already in the bucket; "
              f"uploading {len(pending)}.")
        files = pending

    for index, name in enumerate(files, 1):
        url = f"{base}/storage/v1/object/{BUCKET}/{name}"
        try:
            put_object(url, (AUDIO / name).read_bytes(), "audio/mpeg", token)
        except (urllib.error.URLError, RuntimeError) as error:
            print(f"Failed {name}: {error}", file=sys.stderr)
            return 1
        if index % 100 == 0 or index == len(files):
            print(f"[{index}/{len(files)}] uploaded")

    # Manifests always go up, even when every clip was already present — they
    # are what tells the app the new entries exist.

    # Manifest last: the app must never load a manifest ahead of its files.
    put_object(
        f"{base}/storage/v1/object/{BUCKET}/manifest.json",
        MANIFEST.read_bytes(),
        "application/json",
        token,
    )
    if manifest_en:
        put_object(
            f"{base}/storage/v1/object/{BUCKET}/manifest_en.json",
            MANIFEST_EN.read_bytes(),
            "application/json",
            token,
        )
        print("Uploaded manifest_en.json (intro narration).")
    print("Uploaded manifest.json. Pack is live.")

    if args.prune:
        # Only after the manifest is live, so a failure here can never leave the
        # bucket short of a file the manifest already points at. Anything not
        # referenced is unreachable by the app anyway — this is about not
        # leaving clips of since-edited course text sitting in a public bucket.
        keep = set(files) | {"manifest.json", "manifest_en.json"}
        stale = [n for n in list_bucket(base, token) if n not in keep]
        if not stale:
            print("Prune: nothing stale in the bucket.")
        else:
            print(f"Prune: deleting {len(stale)} objects no longer referenced "
                  f"(e.g. {stale[:2]}).")
            delete_objects(base, token, stale)
            print(f"Prune: removed {len(stale)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
