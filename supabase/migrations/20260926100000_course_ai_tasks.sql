-- Course AI authorization (engineering spec §6). Course feedback is built
-- only from server-known tasks: the client names a task, the server supplies
-- its text and checks the account can open that level. It has its own daily
-- counter, apart from paid chat and from the legacy shared counter.
--
-- Rows come from tool/generate_course_ai_tasks.py; CI checks them against the
-- bundled exam banks (docs/monetization/fixtures/course_ai_tasks.v1.json).
begin;

create table monetization_private.course_ai_tasks (
  task_id text primary key check (task_id ~ '^[a-z0-9-]+/s[0-9]+/q[0-9]+$'),
  operation text not null check (operation in ('writing_evaluation')),
  level text not null check (level in ('a1','a2')),
  task_description text not null check (length(task_description) between 1 and 2000)
);
alter table monetization_private.course_ai_tasks enable row level security;
revoke all on monetization_private.course_ai_tasks from public, anon, authenticated, service_role;

insert into monetization_private.course_ai_tasks(task_id, operation, level, task_description) values
  ('a1-practice-1/s1/q0', 'writing_evaluation', 'a1', 'Write about yourself: your name, age, where you live, what you do, and what you like to do in your free time. Write at least 30 words in Czech.'),
  ('a1-practice-2/s1/q0', 'writing_evaluation', 'a1', 'You are writing an email to your Czech friend. Tell them what you did last weekend (at least 30 words in Czech). Use past tense.'),
  ('a1-practice-2/s1/q1', 'writing_evaluation', 'a1', 'Write a short message to a restaurant to reserve a table for 4 people on Friday at 7 PM. Include your name and phone number. Write at least 20 words in Czech.'),
  ('a1-practice-3/s1/q0', 'writing_evaluation', 'a1', 'Write a short text about your family. Describe who is in your family, where they live, and what they do. Write at least 40 words in Czech.'),
  ('a1-practice-3/s1/q1', 'writing_evaluation', 'a1', 'You want to buy a phone. Write a message to a shop asking about: the price, available colors, and warranty. Write at least 25 words in Czech.'),
  ('a2-practice-1/s1/q0', 'writing_evaluation', 'a2', 'Napište e-mail svému nadřízenému (šéfovi/šéfové), ve kterém se omluvíte za to, že nemůžete přijít do práce. Uveďte důvod (např. nemoc, rodinný problém), řekněte, jak dlouho budete chybět, a navrhněte, jak nahradíte zmeškanou práci. (60–80 slov)'),
  ('a2-practice-1/s1/q1', 'writing_evaluation', 'a2', 'Popište svůj byt nebo dům. Napište, kde bydlíte, kolik máte pokojů, co se vám na vašem bydlení líbí a co byste chtěli změnit. (50–70 slov)'),
  ('a2-practice-2/s1/q0', 'writing_evaluation', 'a2', 'Napište e-mail příteli nebo přítelkyni, ve kterém je pozvete na oslavu narozenin. Napište, kdy a kde se oslava koná, co byste chtěli dostat jako dárek (nebo že dárky nechcete), a co se bude na oslavě dělat. (60–80 slov)'),
  ('a2-practice-2/s1/q1', 'writing_evaluation', 'a2', 'Napište svůj názor na to, zda je lepší bydlet ve městě nebo na vesnici. Uveďte výhody a nevýhody obou možností a řekněte, kde byste chtěli bydlet v budoucnu. (50–70 slov)'),
  ('a2-practice-3/s1/q0', 'writing_evaluation', 'a2', 'Napište stížnost do restaurace, ve které jste byli nespokojeni s jídlem nebo službou. Popište, co se stalo, kdy se to stalo a co byste chtěli, aby restaurace udělala. (60–80 slov)'),
  ('a2-practice-3/s1/q1', 'writing_evaluation', 'a2', 'Napište krátký článek o svém městě nebo vesnici. Popište, co se tam nachází, co je zajímavého a proč by turisté měli vaše město navštívit. (50–70 slov)');

alter table monetization_private.ai_daily_allowance
  add column feedback_count integer not null default 0 check (feedback_count >= 0);

-- Whether the account can open every unit of a level, by the same sources as
-- the app's CourseAccessPolicy: free units, an active staff override, Core,
-- a migration grace window, or permanent unit grants.
create function public.has_course_level_access(p_user uuid, p_level text)
returns boolean language sql stable security definer set search_path = '' as $$
  with level_units(unit_id) as (
    select unnest(case p_level
      when 'a1' then array[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,28,30]
      when 'a2' then array[16,17,18,19,20,21,22,23,24,25,26,27,29,31]
      else array[]::integer[] end)
  )
  select exists (select 1 from level_units)
    and (
      exists (select 1 from public.curriculum_entitlements c where c.user_id = p_user
        and c.unlock_all and (c.expires_at is null or c.expires_at > now()))
      or exists (select 1 from monetization_private.feature_entitlements e where e.user_id = p_user
        and e.feature = 'core' and e.state in ('active','in_grace_period','canceled')
        and e.valid_until > now())
      or exists (select 1 from public.course_access_windows w where w.user_id = p_user
        and w.starts_at <= now() and w.ends_at > now())
      or not exists (select 1 from level_units u
        where u.unit_id not in (1, 2)
          and not exists (select 1 from public.course_unit_grants g
            where g.user_id = p_user and g.unit_id = u.unit_id and g.revoked_at is null))
    );
$$;

-- The server's task, and whether this account may have it evaluated. Null for
-- a task the server does not know.
create function public.course_ai_task(p_user uuid, p_task text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('task_id', t.task_id, 'operation', t.operation, 'level', t.level,
      'task_description', t.task_description,
      'allowed', public.has_course_level_access(p_user, t.level))
  from monetization_private.course_ai_tasks t where t.task_id = p_task;
$$;

-- One course-feedback request from today's allowance. The conditional update
-- is the atomic check, as for the other allowances.
create function public.consume_ai_feedback(p_user uuid, p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare today date := (timezone('utc', now()))::date; counted integer;
begin
  if p_limit < 1 then return jsonb_build_object('allowed', false); end if;
  insert into monetization_private.ai_daily_allowance(user_id, quota_day, feedback_count)
    values (p_user, today, 1)
  on conflict (user_id, quota_day) do update
    set feedback_count = monetization_private.ai_daily_allowance.feedback_count + 1
    where monetization_private.ai_daily_allowance.feedback_count < p_limit
  returning feedback_count into counted;
  if counted is null then
    return jsonb_build_object('allowed', false,
      'resets_at', (today + 1)::timestamp at time zone 'UTC');
  end if;
  return jsonb_build_object('allowed', true, 'quota_day', today, 'remaining', p_limit - counted);
end $$;

-- Returns a feedback request to the day it was taken from.
create function public.refund_ai_feedback(p_user uuid, p_day date)
returns void language sql security definer set search_path = '' as $$
  update monetization_private.ai_daily_allowance set feedback_count = greatest(0, feedback_count - 1)
    where user_id = p_user and quota_day = p_day;
$$;

revoke all on function public.has_course_level_access(uuid, text), public.course_ai_task(uuid, text),
  public.consume_ai_feedback(uuid, integer), public.refund_ai_feedback(uuid, date)
  from public, anon, authenticated;
grant execute on function public.has_course_level_access(uuid, text), public.course_ai_task(uuid, text),
  public.consume_ai_feedback(uuid, integer), public.refund_ai_feedback(uuid, date)
  to service_role;
commit;
