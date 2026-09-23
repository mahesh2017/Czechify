#!/usr/bin/env python3
"""Course AI task manifest: every writing task the app can ask the server to
evaluate, taken from the bundled exam banks.

  python3 tool/generate_course_ai_tasks.py          # rewrite the fixture
  python3 tool/generate_course_ai_tasks.py --sql    # print the migration rows
  python3 tool/generate_course_ai_tasks.py --check  # fail if the fixture is stale
  python3 tool/generate_course_ai_tasks.py --check-db  # also compare the local database

The server builds evaluation prompts only from these rows, never from text the
client sends, so a task changed in the app must be regenerated and shipped in a
new migration before the app that uses it.
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
BANKS = ["assets/curriculum/exam_bank_permres_a1.json", "assets/curriculum/exam_bank_permres_a2.json"]
FIXTURE = ROOT / "docs/monetization/fixtures/course_ai_tasks.v1.json"


def tasks():
    rows = []
    for bank in BANKS:
        raw = (ROOT / bank).read_bytes()
        data = json.loads(raw)
        for exam in data["exams"]:
            for s, section in enumerate(exam["sections"]):
                if section["type"] != "writing":
                    continue
                for q, question in enumerate(section["questions"]):
                    rows.append({
                        "task_id": f"{exam['id']}/s{s}/q{q}",
                        "operation": "writing_evaluation",
                        "level": data["level"].lower(),
                        # The exact text the app sent as task_description.
                        "task_description": question["prompt"],
                        "source": bank,
                        "source_sha256": hashlib.sha256(raw).hexdigest(),
                    })
    rows.sort(key=lambda row: row["task_id"])
    return rows


def manifest():
    rows = tasks()
    digest = hashlib.sha256("\n".join(
        f"{r['task_id']}|{r['operation']}|{r['level']}|{r['task_description']}" for r in rows
    ).encode()).hexdigest()
    return {"schema_version": 1, "manifest_sha256": digest, "tasks": rows}


def sql_literal(value):
    return "'" + value.replace("'", "''") + "'"


def check_database(current):
    url = os.environ.get("COURSE_AI_TEST_DATABASE_URL",
                         "postgresql://postgres:postgres@127.0.0.1:54322/postgres")
    if urlparse(url).hostname not in ("localhost", "127.0.0.1", "::1"):
        raise SystemExit("Refusing a non-loopback database; use the disposable local stack.")
    psql = os.environ.get("PSQL") or shutil.which("psql")
    if not psql:
        raise SystemExit("psql is required; set PSQL to its executable path.")
    out = subprocess.run(
        [psql, url, "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-c",
         "select coalesce(jsonb_agg(jsonb_build_object('task_id',task_id,'operation',operation,"
         "'level',level,'task_description',task_description) order by task_id),'[]') "
         "from monetization_private.course_ai_tasks;"],
        capture_output=True, text=True, check=True).stdout
    expected = [{k: r[k] for k in ("task_id", "operation", "level", "task_description")}
                for r in current["tasks"]]
    if json.loads(out) != expected:
        raise SystemExit("Server course AI tasks differ from the bundled exam banks; ship a migration")
    print(f"PASS: server course AI tasks match the manifest ({current['manifest_sha256'][:12]})")


def main():
    current = manifest()
    text = json.dumps(current, ensure_ascii=False, indent=2) + "\n"
    if "--check" in sys.argv or "--check-db" in sys.argv:
        if FIXTURE.read_text() != text:
            raise SystemExit("course_ai_tasks.v1.json is stale; run tool/generate_course_ai_tasks.py")
        print(f"PASS: {len(current['tasks'])} course AI tasks match the bundled exam banks")
        if "--check-db" in sys.argv:
            check_database(current)
    elif "--sql" in sys.argv:
        print(",\n".join(
            f"  ({sql_literal(r['task_id'])}, {sql_literal(r['operation'])}, {sql_literal(r['level'])}, "
            f"{sql_literal(r['task_description'])})" for r in current["tasks"]
        ))
    else:
        FIXTURE.write_text(text)
        print(f"Wrote {len(current['tasks'])} tasks, manifest {current['manifest_sha256'][:12]}")


if __name__ == "__main__":
    main()
