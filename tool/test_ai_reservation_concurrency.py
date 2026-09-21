#!/usr/bin/env python3
"""Real contention regression. Uses temporary accounts on the local stack only."""
import concurrent.futures
import json
import os
import subprocess
import time
import uuid

import shutil
from urllib.parse import urlparse
url = os.environ.get('AI_TEST_DATABASE_URL', 'postgresql://postgres:postgres@127.0.0.1:54322/postgres')
if urlparse(url).hostname not in ('localhost', '127.0.0.1', '::1'):
    raise SystemExit('Only the disposable loopback database is allowed.')
psql = os.environ.get('PSQL') or shutil.which('psql')
if not psql:
    raise SystemExit('psql is required; set PSQL to its executable path.')
cmd = [psql, url, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1']
user, request, session = [str(uuid.uuid4()) for _ in range(3)]

def sql(statement, name='reservation-audit'):
    run = subprocess.run(cmd, input=statement, text=True, capture_output=True, timeout=20,
                         env={**os.environ, 'PGAPPNAME': name})
    if run.returncode:
        raise RuntimeError(run.stderr)
    return run.stdout.strip()

holder = None
try:
    sql(f"insert into auth.users(id,is_anonymous,created_at) values('{user}',false,now()); insert into monetization_private.ai_daily_allowance(user_id,quota_day) values('{user}',(timezone('utc',now()))::date);")
    holder = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    holder.stdin.write(f"begin; select 1 from monetization_private.ai_daily_allowance where user_id='{user}' for update;\n\\echo LOCKED\n")
    holder.stdin.flush()
    assert holder.stdout.readline().strip() == '1'
    assert holder.stdout.readline().strip() == 'LOCKED'
    names = [f'audit-{user[:8]}-{i}' for i in range(2)]
    statement = f"select reserve_ai_request('{user}','{request}','conversation',repeat('a',64),'{session}',20,60,1,120);"
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        pending = [pool.submit(sql, statement, name) for name in names]
        for _ in range(100):
            count = sql(f"select count(*) from pg_stat_activity where application_name in ('{names[0]}','{names[1]}') and wait_event_type='Lock';")
            if count == '2':
                break
            time.sleep(0.05)
        else:
            raise RuntimeError('Workers did not both reach the contested row')
        holder.stdin.write('commit;\n\\q\n')
        holder.stdin.flush()
        holder.wait(timeout=5)
        outcomes = [json.loads(result.result())['outcome'] for result in pending]
        assert sorted(outcomes) == ['in_flight', 'reserved'], outcomes
        print('PASS: simultaneous identical requests dispatch once')
    assert sql(f"select conversation_count from monetization_private.ai_daily_allowance where user_id='{user}';") == '1'
    assert sql(f"select count(*) from monetization_private.ai_request_reservations where user_id='{user}';") == '1'
    sql(f"insert into monetization_private.ai_chat_sessions(user_id,session_id,turns) values('{user}','{session}',1);")
    summary_request = str(uuid.uuid4())
    def reserve_summary(request_id):
        return json.loads(sql(f"select reserve_ai_request('{user}','{request_id}','conversation_summary',repeat('b',64),'{session}',20,60,1,120);"))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        summaries = list(pool.map(reserve_summary, [summary_request, str(uuid.uuid4())]))
    assert sorted(r['outcome'] for r in summaries) == ['reserved', 'summary_not_due'], summaries
    assert sql(f"select summary_count from monetization_private.ai_daily_allowance where user_id='{user}';") == '1'
    print('PASS: simultaneous summaries reserve session progress once')
    # The winning summary consumed only the turns that existed at reservation.
    # A new chat turn arriving before completion must remain summarizable.
    winner = sql(f"select request_id from monetization_private.ai_request_reservations where user_id='{user}' and operation='conversation_summary';")
    sql(f"update monetization_private.ai_chat_sessions set turns=2 where user_id='{user}'; select complete_ai_request('{user}','{winner}',1,1,0,'test-sealed',60);")
    assert sql(f"select turns_at_last_summary from monetization_private.ai_chat_sessions where user_id='{user}';") == '1'
    next_request = str(uuid.uuid4())
    assert reserve_summary(next_request)['outcome'] == 'reserved'
    sql(f"select abandon_ai_request('{user}','{next_request}');")
    assert reserve_summary(str(uuid.uuid4()))['outcome'] == 'summary_not_due'
    print('PASS: late turns are preserved; unknown summary outcomes are not redispatched')

finally:
    if holder and holder.poll() is None:
        holder.kill()
        holder.wait(timeout=5)
    sql(f"delete from auth.users where id='{user}';")
    print('Synthetic audit account and its reservations removed.')
