#!/usr/bin/env python3
"""Course lesson manifest: which bundled lesson belongs to which unit.

  python3 tool/generate_course_lessons.py           # rewrite the fixture
  python3 tool/generate_course_lessons.py --sql     # print the migration rows
  python3 tool/generate_course_lessons.py --check   # fail if the fixture is stale
  python3 tool/generate_course_lessons.py --check-db  # also compare the local database

The existing-user migration decides which units a learner reached from these
rows, never from the unit ID a client wrote into its own progress, and treats
every lesson of a unit as required, as the app's progression does.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "docs/monetization/fixtures/course_lessons.v1.json"


def lessons():
    rows = []
    for path in sorted((ROOT / "assets/curriculum/lessons").glob("*.json")):
        data = json.loads(path.read_text())
        rows.append({"lesson_id": data["id"], "unit_id": data["unit_id"]})
    rows.sort(key=lambda row: row["lesson_id"])
    ids = [row["lesson_id"] for row in rows]
    if len(ids) != len(set(ids)):
        raise SystemExit("Duplicate lesson IDs in assets/curriculum/lessons")
    return rows


def manifest():
    rows = lessons()
    digest = hashlib.sha256(
        "\n".join(f"{r['lesson_id']}:{r['unit_id']}" for r in rows).encode()
    ).hexdigest()
    return {"schema_version": 1, "manifest_sha256": digest, "lessons": rows}


def check_database(current):
    url = os.environ.get("COURSE_LESSONS_TEST_DATABASE_URL",
                         "postgresql://postgres:postgres@127.0.0.1:54322/postgres")
    if urlparse(url).hostname not in ("localhost", "127.0.0.1", "::1"):
        raise SystemExit("Refusing a non-loopback database; use the disposable local stack.")
    psql = os.environ.get("PSQL") or shutil.which("psql")
    if not psql:
        raise SystemExit("psql is required; set PSQL to its executable path.")
    out = subprocess.run(
        [psql, url, "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-c",
         "select coalesce(jsonb_agg(jsonb_build_object('lesson_id',lesson_id,'unit_id',unit_id) "
         "order by lesson_id),'[]') from monetization_private.course_lessons;"],
        capture_output=True, text=True, check=True).stdout
    if json.loads(out) != current["lessons"]:
        raise SystemExit("Server course lessons differ from the bundled lessons; ship a migration")
    print(f"PASS: server course lessons match the manifest ({current['manifest_sha256'][:12]})")


def main():
    current = manifest()
    text = json.dumps(current, indent=2) + "\n"
    if "--check" in sys.argv or "--check-db" in sys.argv:
        if FIXTURE.read_text() != text:
            raise SystemExit("course_lessons.v1.json is stale; run tool/generate_course_lessons.py")
        print(f"PASS: {len(current['lessons'])} course lessons match the bundled assets")
        if "--check-db" in sys.argv:
            check_database(current)
    elif "--sql" in sys.argv:
        print(",\n".join(f"  ({r['lesson_id']}, {r['unit_id']})" for r in current["lessons"]))
    else:
        FIXTURE.write_text(text)
        print(f"Wrote {len(current['lessons'])} lessons, manifest {current['manifest_sha256'][:12]}")


if __name__ == "__main__":
    main()
