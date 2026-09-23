#!/usr/bin/env python3
"""Real PostgreSQL contention + manifest checks, on the disposable LOCAL stack.

Run after `supabase db reset` and `supabase test db`:
  python3 tool/test_referral_concurrency.py
Set PSQL to the psql executable when it is not on PATH. No third-party Python
packages are needed. Only loopback Supabase URLs are accepted. Test accounts
are removed and campaign controls restored even on assertion failure.
"""

import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from urllib.parse import urlparse
import uuid


ROOT = Path(__file__).resolve().parents[1]
URL = os.environ.get(
    "REFERRAL_TEST_DATABASE_URL",
    "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
)
PSQL = os.environ.get("PSQL") or shutil.which("psql")
if urlparse(URL).hostname not in ("localhost", "127.0.0.1", "::1"):
    raise SystemExit("Refusing a non-loopback database; use the disposable local stack.")
if not PSQL:
    raise SystemExit("psql is required; set PSQL to its executable path.")
CMD = [PSQL, URL, "-X", "-qAt", "-v", "ON_ERROR_STOP=1"]


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def sql(statement, app_name="czechify-referral-test"):
    result = subprocess.run(
        CMD, input=statement, text=True, capture_output=True, timeout=30,
        env={**os.environ, "PGAPPNAME": app_name},
    )
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip()


def query(statement):
    return json.loads(sql(statement))


def manifest_check():
    fixture = json.loads((ROOT / "docs/monetization/fixtures/campaign_manifest.v1.json").read_text())
    expected = []
    for unit in fixture["free_unit_lessons"]:
        for lesson in unit["lessons"]:
            raw = (ROOT / lesson["source"]).read_bytes()
            assert hashlib.sha256(raw).hexdigest() == lesson["sha256"], "Bundled lesson changed"
            content = json.loads(raw)
            assert [e["id"] for e in content["exercises"]] == lesson["exercise_ids"]
            assert [e["id"] for e in content["exercises"] if e["type"] == "teaching"] == lesson["teaching_exercise_ids"]
            expected.append({
                "unit_id": unit["unit_id"], "lesson_id": lesson["lesson_id"],
                "lesson_hash": lesson["sha256"], "exercise_ids": lesson["exercise_ids"],
                "teaching_ids": lesson["teaching_exercise_ids"],
            })
    expected.sort(key=lambda row: row["lesson_id"])
    actual = query("""select jsonb_agg(to_jsonb(m)-'campaign_id' order by lesson_id)
        from monetization_private.referral_manifest_lessons m;""")
    assert actual == expected, "SQL manifest differs from the actual eight bundled lessons"
    payload = "25|" + "|".join(
        f"{row['unit_id']}:{row['lesson_id']}:{row['lesson_hash']}:"
        + ",".join(map(str, row["exercise_ids"])) + ":" + ",".join(map(str, row["teaching_ids"]))
        for row in expected
    )
    assert sql("select manifest_sha256 from monetization_private.referral_campaigns;") == hashlib.sha256(payload.encode()).hexdigest()
    print("PASS: server manifest, source hashes, exercise coverage and campaign digest")


def run_case(case):
    owner = str(uuid.uuid4())
    friends = {request["claim"]: str(uuid.uuid4()) for request in case["input"]["parallel_requests"]}
    claims = {name: str(uuid.uuid4()) for name in friends}
    users = [owner, *friends.values()]
    ids = ",".join(map(literal, users))
    claim_ids = ",".join(map(literal, claims.values()))
    controls = query("""select jsonb_build_object('enabled',enabled,'processing_paused',processing_paused,
        'starts_at',starts_at,'claim_closes_at',claim_closes_at,'ends_at',ends_at)
        from monetization_private.referral_campaigns where id='a1-referral-v1';""")
    holder = None
    try:
        sql("""update monetization_private.referral_campaigns set enabled=true,processing_paused=true,
            starts_at=now()-interval '1 day',claim_closes_at=now()+interval '1 month',ends_at=now()+interval '2 months';""")
        sql("insert into auth.users(id,is_anonymous,created_at) values " + ",".join(
            f"({literal(user)},false,now()-interval '1 hour')" for user in users
        ) + ";" + f"""insert into auth.identities(user_id,provider,provider_id,identity_data)
            select id,'email',id::text,'{{}}'::jsonb from auth.users where id in ({ids});
            select get_or_create_referral_code({literal(owner)},'a1-referral-v1');""")
        for name, friend in friends.items():
            # Use the actual claim RPC, then retain its generated UUID.
            response = query(f"""select claim_referral({literal(friend)},'a1-referral-v1',
                (select code from monetization_private.referral_codes where owner_id={literal(owner)}));""")
            claims[name] = response["claim_id"]
            claim_ids = ",".join(map(literal, claims.values()))
            for lesson in query("select jsonb_agg(to_jsonb(m) order by lesson_id) from monetization_private.referral_manifest_lessons m where unit_id=1;"):
                now = sql("select now();")
                receipt = {
                    "schema_version": 1, "claim_id": claims[name], "campaign_id": "a1-referral-v1",
                    "content_revision": 25, "lesson_id": lesson["lesson_id"], "attempt_id": str(uuid.uuid4()),
                    "started_at_client": now, "completed_at_client": now,
                    "initial_coverage": [{"exercise_id": exercise, "interaction":
                        "teaching_acknowledged" if exercise in lesson["teaching_ids"] else "answered_incorrectly"}
                        for exercise in lesson["exercise_ids"]],
                }
                payload = json.dumps(receipt, sort_keys=True, separators=(",", ":"))
                digest = hashlib.sha256(payload.encode()).hexdigest()
                accepted = query(f"select accept_verified_referral_receipt({literal(friend)},{literal(claims[name])},{literal(payload)}::jsonb,{literal(digest)},'verified');")
                assert accepted["status"] == "accepted", accepted
        for unit in case["input"]["existing_owned_unit_ids"]:
            sql(f"select set_course_unit_grant({literal(owner)},{int(unit)},'legacy','{owner}-test-{int(unit)}',null,false,'test setup');")
        sql("update monetization_private.referral_campaigns set processing_paused=false;")

        # A third connection holds the shared beneficiary row. Both workers
        # must actually block on a DB lock before release; sleeps alone would
        # let sequential transactions masquerade as a concurrency test.
        holder = subprocess.Popen(CMD, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        holder.stdin.write(f"begin; select 1 from public.monetization_accounts where user_id={literal(owner)} for update;\n\\echo LOCKED\n")
        holder.stdin.flush()
        assert holder.stdout.readline().strip() == "1"
        assert holder.stdout.readline().strip() == "LOCKED"
        names = [f"referral-{owner[:8]}-{index}" for index in range(2)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            pending = [pool.submit(sql, f"select process_referral_claim({literal(claims[request['claim']])});", names[index])
                       for index, request in enumerate(case["input"]["parallel_requests"])]
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                blocked = int(sql("select count(*) from pg_stat_activity where application_name in ("
                                  + ",".join(map(literal, names)) + ") and wait_event_type='Lock';"))
                if blocked == 2:
                    break
                time.sleep(0.05)
            else:
                raise AssertionError("Both competing transactions did not reach the lock")
            holder.stdin.write("commit;\n\\q\n")
            holder.stdin.flush()
            holder.wait(timeout=10)
            for result in pending:
                result.result(timeout=15)
        expected = case["expected"]
        units = query(f"select coalesce(jsonb_agg(unit_id order by unit_id),'[]'::jsonb) from public.course_unit_grants where user_id={literal(owner)} and source='referral';")
        assert units == expected["new_unit_ids"], (case["id"], units)
        events = query(f"select jsonb_agg(to_jsonb(e)) from monetization_private.referral_reward_events e where claim_id in ({claim_ids});")
        assert len(events) == expected["reward_event_count"], events
        if "outcome_counts" in expected:
            assert {outcome: sum(e["outcome"] == outcome for e in events) for outcome in ("granted", "cap_reached")} == expected["outcome_counts"]
        for table in ("entitlement_audit", "monetization_outbox"):
            assert int(sql(f"select count(*) from monetization_private.{table} where user_id={literal(owner)};")) == len(units) + len(case["input"]["existing_owned_unit_ids"])
        print(f"PASS: {case['id']} (both transactions contended on the beneficiary lock)")
    finally:
        if holder and holder.poll() is None:
            holder.kill()
            holder.wait(timeout=5)
        for table in ("referral_review_cases", "referral_reward_events", "referral_milestones", "referral_lesson_qualifications", "referral_receipts"):
            sql(f"delete from monetization_private.{table} where claim_id in ({claim_ids});")
        sql(f"delete from monetization_private.referral_claims where id in ({claim_ids}); delete from auth.users where id in ({ids});")
        # Test-owned audit rows have no actor after Auth deletion; remove using
        # the known source keys, not broad null-owner cleanup.
        sources = [f"{claim}:1" for claim in claims.values()] + [f"{owner}-test-{unit}" for unit in case["input"]["existing_owned_unit_ids"]]
        if sources:
            sql("delete from monetization_private.entitlement_audit where user_id is null and source_key in (" + ",".join(map(literal, sources)) + ");")
        assignments = ",".join(f"{key}=" + ("null" if value is None else str(value).lower() if isinstance(value, bool) else literal(value)) for key, value in controls.items())
        sql(f"update monetization_private.referral_campaigns set {assignments} where id='a1-referral-v1';")


def manifest_lessons(unit):
    return query(f"select jsonb_agg(to_jsonb(m) order by lesson_id) from monetization_private.referral_manifest_lessons m where unit_id={unit};")


def receipt_sql(friend, claim, lesson):
    """The statement that submits one lesson receipt, as the API does."""
    now = sql("select now();")
    receipt = {
        "schema_version": 1, "claim_id": claim, "campaign_id": "a1-referral-v1",
        "content_revision": 25, "lesson_id": lesson["lesson_id"], "attempt_id": str(uuid.uuid4()),
        "started_at_client": now, "completed_at_client": now,
        "initial_coverage": [{"exercise_id": exercise, "interaction":
            "teaching_acknowledged" if exercise in lesson["teaching_ids"] else "answered_incorrectly"}
            for exercise in lesson["exercise_ids"]],
    }
    payload = json.dumps(receipt, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(payload.encode()).hexdigest()
    return (f"select accept_verified_referral_receipt({literal(friend)},{literal(claim)},"
            f"{literal(payload)}::jsonb,{literal(digest)},'verified');")


def mutual_invitation_case():
    """Two learners who invited each other, processed at the same time.

    Since the friend's trial landed, one claim writes to both accounts, so a
    pair of claims can touch the same two rows from opposite sides. Locking
    each claim's own beneficiary first would let one hold A wanting B while
    the other holds B wanting A: a deadlock PostgreSQL resolves by killing a
    transaction, losing a reward. Both must take the lower account ID first,
    whichever side of their claim it is on. That is what this checks: both
    workers block on the SAME row, then both finish.
    """
    a, b = sorted(str(uuid.uuid4()) for _ in range(2))
    ids = ",".join(map(literal, (a, b)))
    controls = query("""select jsonb_build_object('enabled',enabled,'processing_paused',processing_paused,
        'starts_at',starts_at,'claim_closes_at',claim_closes_at,'ends_at',ends_at)
        from monetization_private.referral_campaigns where id='a1-referral-v1';""")
    holder = None
    claims = {}
    try:
        sql("""update monetization_private.referral_campaigns set enabled=true,processing_paused=true,
            starts_at=now()-interval '1 day',claim_closes_at=now()+interval '1 month',ends_at=now()+interval '2 months';""")
        sql("insert into auth.users(id,is_anonymous,created_at) values " + ",".join(
            f"({literal(user)},false,now()-interval '1 hour')" for user in (a, b)
        ) + ";" + f"""insert into auth.identities(user_id,provider,provider_id,identity_data)
            select id,'email',id::text,'{{}}'::jsonb from auth.users where id in ({ids});""")
        for inviter, friend in ((a, b), (b, a)):
            sql(f"select get_or_create_referral_code({literal(inviter)},'a1-referral-v1');")
            response = query(f"""select claim_referral({literal(friend)},'a1-referral-v1',
                (select code from monetization_private.referral_codes where owner_id={literal(inviter)}));""")
            assert "claim_id" in response, response
            claims[friend] = response["claim_id"]
            # Both free units, so processing decides the second milestone and
            # the friend's trial in the same transaction.
            for unit in (1, 2):
                for lesson in manifest_lessons(unit):
                    accepted = query(receipt_sql(friend, claims[friend], lesson))
                    assert accepted["status"] == "accepted", accepted
        claim_ids = ",".join(map(literal, claims.values()))
        sql("update monetization_private.referral_campaigns set processing_paused=false;")

        # A third connection holds the LOWER account. Correct ordering makes
        # both workers queue behind it; beneficiary-first ordering would let
        # one run ahead, take the other row and deadlock.
        holder = subprocess.Popen(CMD, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        holder.stdin.write(f"begin; select 1 from public.monetization_accounts where user_id={literal(a)} for update;\n\\echo LOCKED\n")
        holder.stdin.flush()
        assert holder.stdout.readline().strip() == "1"
        assert holder.stdout.readline().strip() == "LOCKED"
        names = [f"mutual-{a[:8]}-{index}" for index in range(2)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            pending = [pool.submit(sql, f"select process_referral_claim({literal(claim)});", names[index])
                       for index, claim in enumerate(claims.values())]
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                blocked = int(sql("select count(*) from pg_stat_activity where application_name in ("
                                  + ",".join(map(literal, names)) + ") and wait_event_type='Lock';"))
                if blocked == 2:
                    break
                time.sleep(0.05)
            else:
                raise AssertionError("Both transactions did not queue on the same account row")
            holder.stdin.write("commit;\n\\q\n")
            holder.stdin.flush()
            holder.wait(timeout=10)
            for result in pending:
                # A deadlock surfaces here as SQLSTATE 40P01.
                result.result(timeout=15)
        for user in (a, b):
            trial = sql(f"""select count(*) from public.course_access_windows
                where user_id={literal(user)} and kind='referral_trial' and ends_at>now();""")
            assert int(trial) == 1, (user, trial)
            earned = sql(f"select count(*) from public.course_unit_grants where user_id={literal(user)} and source='referral';")
            assert int(earned) == 2, (user, earned)
        print("PASS: mutual_invitation (both transactions queued on the same account, no deadlock)")
    finally:
        if holder and holder.poll() is None:
            holder.kill()
            holder.wait(timeout=5)
        if claims:
            claim_ids = ",".join(map(literal, claims.values()))
            for table in ("referral_review_cases", "referral_reward_events", "referral_milestones",
                          "referral_lesson_qualifications", "referral_receipts"):
                sql(f"delete from monetization_private.{table} where claim_id in ({claim_ids});")
            sql(f"delete from monetization_private.referral_claims where id in ({claim_ids});")
        sql(f"delete from auth.users where id in ({ids});")
        # Audit rows outlive their account, so remove this run's by source key:
        # both milestones of each claim, and the trial keyed by the claim.
        sources = [f"{claim}:{ordinal}" for claim in claims.values() for ordinal in (1, 2)]
        sources += [str(claim) for claim in claims.values()]
        if sources:
            sql("delete from monetization_private.entitlement_audit where user_id is null and source_key in ("
                + ",".join(map(literal, sources)) + ");")
        assignments = ",".join(f"{key}=" + ("null" if value is None else str(value).lower() if isinstance(value, bool) else literal(value)) for key, value in controls.items())
        sql(f"update monetization_private.referral_campaigns set {assignments} where id='a1-referral-v1';")


def mutual_receipt_case():
    """The same pair of learners, through the path the app actually uses.

    Each friend's last lesson receipt decides their claim. Receipts (and
    review decisions) used to lock the inviter before claim processing took
    its ordered locks, so the pair could still deadlock even with processing
    fixed. Here the higher account is held; A's receipt queues on it first,
    then B's receipt takes the lower account and queues behind. Released, A's
    transaction gets the higher row and needs the lower one next: with the
    old order that is a deadlock, with ordered locks B's receipt never took
    the lower row ahead of A.
    """
    a, b = sorted(str(uuid.uuid4()) for _ in range(2))
    ids = ",".join(map(literal, (a, b)))
    controls = query("""select jsonb_build_object('enabled',enabled,'processing_paused',processing_paused,
        'starts_at',starts_at,'claim_closes_at',claim_closes_at,'ends_at',ends_at)
        from monetization_private.referral_campaigns where id='a1-referral-v1';""")
    holder = None
    claims = {}
    try:
        sql("""update monetization_private.referral_campaigns set enabled=true,processing_paused=false,
            starts_at=now()-interval '1 day',claim_closes_at=now()+interval '1 month',ends_at=now()+interval '2 months';""")
        sql("insert into auth.users(id,is_anonymous,created_at) values " + ",".join(
            f"({literal(user)},false,now()-interval '1 hour')" for user in (a, b)
        ) + ";" + f"""insert into auth.identities(user_id,provider,provider_id,identity_data)
            select id,'email',id::text,'{{}}'::jsonb from auth.users where id in ({ids});""")
        lessons = manifest_lessons(1) + manifest_lessons(2)
        for inviter, friend in ((a, b), (b, a)):
            sql(f"select get_or_create_referral_code({literal(inviter)},'a1-referral-v1');")
            response = query(f"""select claim_referral({literal(friend)},'a1-referral-v1',
                (select code from monetization_private.referral_codes where owner_id={literal(inviter)}));""")
            assert "claim_id" in response, response
            claims[friend] = response["claim_id"]
            # Everything but the last lesson; that receipt decides the claim.
            for lesson in lessons[:-1]:
                accepted = query(receipt_sql(friend, claims[friend], lesson))
                assert accepted["status"] == "accepted", accepted
        last = {friend: receipt_sql(friend, claims[friend], lessons[-1]) for friend in (a, b)}

        holder = subprocess.Popen(CMD, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        holder.stdin.write(f"begin; select 1 from public.monetization_accounts where user_id={literal(b)} for update;\n\\echo LOCKED\n")
        holder.stdin.flush()
        assert holder.stdout.readline().strip() == "1"
        assert holder.stdout.readline().strip() == "LOCKED"

        def waiting(name):
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if int(sql(f"select count(*) from pg_stat_activity where application_name={literal(name)} and wait_event_type='Lock';")):
                    return
                time.sleep(0.05)
            raise AssertionError(f"{name} never waited on a lock")

        names = [f"receipt-{a[:8]}-{index}" for index in range(2)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(sql, last[a], names[0])
            waiting(names[0])
            second = pool.submit(sql, last[b], names[1])
            waiting(names[1])
            holder.stdin.write("commit;\n\\q\n")
            holder.stdin.flush()
            holder.wait(timeout=10)
            for result in (first, second):
                # A deadlock surfaces here as SQLSTATE 40P01.
                result.result(timeout=15)
        for user in (a, b):
            trial = sql(f"""select count(*) from public.course_access_windows
                where user_id={literal(user)} and kind='referral_trial' and ends_at>now();""")
            assert int(trial) == 1, (user, trial)
            earned = sql(f"select count(*) from public.course_unit_grants where user_id={literal(user)} and source='referral';")
            assert int(earned) == 2, (user, earned)
        print("PASS: mutual_receipts (the receipt path locks both accounts in order, no deadlock)")
    finally:
        if holder and holder.poll() is None:
            holder.kill()
            holder.wait(timeout=5)
        if claims:
            claim_ids = ",".join(map(literal, claims.values()))
            for table in ("referral_review_cases", "referral_reward_events", "referral_milestones",
                          "referral_lesson_qualifications", "referral_receipts"):
                sql(f"delete from monetization_private.{table} where claim_id in ({claim_ids});")
            sql(f"delete from monetization_private.referral_claims where id in ({claim_ids});")
        sql(f"delete from auth.users where id in ({ids});")
        sources = [f"{claim}:{ordinal}" for claim in claims.values() for ordinal in (1, 2)]
        sources += [str(claim) for claim in claims.values()]
        if sources:
            sql("delete from monetization_private.entitlement_audit where user_id is null and source_key in ("
                + ",".join(map(literal, sources)) + ");")
        assignments = ",".join(f"{key}=" + ("null" if value is None else str(value).lower() if isinstance(value, bool) else literal(value)) for key, value in controls.items())
        sql(f"update monetization_private.referral_campaigns set {assignments} where id='a1-referral-v1';")


if __name__ == "__main__":
    manifest_check()
    cases = json.loads((ROOT / "docs/monetization/fixtures/decision_cases.v1.json").read_text())["cases"]
    scenarios = [case for case in cases if case["kind"] == "transaction_scenario"]
    assert len(scenarios) == 3
    for scenario in scenarios:
        run_case(scenario)
    mutual_invitation_case()
    mutual_receipt_case()
