begin;

-- Make the rollback-only test self-contained on hosted projects where the
-- extension registry can exist without its functions in the schema dump.
drop extension if exists pgtap cascade;
create extension pgtap with schema public;
set local search_path = public;
select public.plan(14);

select public.has_table(
  'public',
  'curriculum_pack_versions',
  'immutable pack versions table exists'
);
select public.has_table(
  'public',
  'content_release_items',
  'normalized release items table exists'
);
select public.ok(
  (select relrowsecurity
   from pg_class
   where oid = 'public.curriculum_pack_versions'::regclass)
  and
  (select relrowsecurity
   from pg_class
   where oid = 'public.content_release_items'::regclass),
  'RLS is enabled on both release delivery tables'
);
select public.ok(
  has_table_privilege('anon', 'public.curriculum_pack_versions', 'SELECT')
  and has_table_privilege('authenticated', 'public.curriculum_pack_versions', 'SELECT')
  and not has_table_privilege('anon', 'public.curriculum_pack_versions', 'INSERT,UPDATE,DELETE'),
  'pack versions expose read-only Data API grants'
);
select public.ok(
  has_table_privilege('anon', 'public.content_release_items', 'SELECT')
  and has_table_privilege('authenticated', 'public.content_release_items', 'SELECT')
  and not has_table_privilege('anon', 'public.content_release_items', 'INSERT,UPDATE,DELETE'),
  'release items expose read-only Data API grants'
);

set local role service_role;

insert into public.curriculum_pack_versions (
  pack_key, version, content, checksum
) values (
  'assets/curriculum/test.json',
  1,
  '{"ok":true}'::jsonb,
  repeat('a', 64)
);
insert into public.content_releases (
  release_id, version, status, content_checksum, pack_refs, published_at
) values (
  'test-release',
  1,
  'published',
  repeat('b', 64),
  '[]'::jsonb,
  now()
);
insert into public.content_release_items (
  release_id, pack_key, pack_version, checksum, position
) values (
  'test-release',
  'assets/curriculum/test.json',
  1,
  repeat('a', 64),
  0
);

select public.throws_ok(
  $$update public.curriculum_pack_versions
    set content = '{"changed":true}'::jsonb
    where pack_key = 'assets/curriculum/test.json' and version = 1$$,
  '55000',
  'curriculum pack versions are immutable',
  'published pack content cannot be mutated'
);
select public.throws_ok(
  $$delete from public.curriculum_pack_versions
    where pack_key = 'assets/curriculum/test.json' and version = 1$$,
  '55000',
  'curriculum pack versions are immutable',
  'published pack versions cannot be deleted'
);
select public.throws_ok(
    $$insert into public.content_release_items (
      release_id, pack_key, pack_version, checksum, position
    ) values (
      'test-release', 'assets/curriculum/missing.json', 2, repeat('a', 64), 1
    )$$,
  '23503',
  null,
  'release item must reference an exact existing pack version'
);

-- min_client_format (20261005100000): a release old apps cannot read must
-- be 'gated', which they never query.
select public.throws_ok(
  $$insert into public.content_releases (
      release_id, version, status, content_checksum, pack_refs,
      min_client_format, published_at
    ) values (
      'too-new-for-old-apps', 2, 'published', repeat('c', 64), '[]'::jsonb,
      2, now()
    )$$,
  '23514',
  null,
  'a release old apps cannot read cannot be published to them'
);
select public.lives_ok(
  $$insert into public.content_releases (
      release_id, version, status, content_checksum, pack_refs,
      min_client_format, published_at
    ) values (
      'gated-release', 3, 'gated', repeat('d', 64), '[]'::jsonb, 2, now()
    )$$,
  'a release for newer apps can be gated'
);
select public.is(
  (select min_client_format from public.content_releases
   where release_id = 'test-release'),
  1,
  'existing releases stay readable by every app'
);

set local role anon;

select public.is(
  (select count(*)::integer from public.content_releases
   where release_id in ('test-release', 'gated-release')),
  2,
  'anonymous clients can read published and gated releases'
);

select public.is(
  (select count(*)::integer from public.content_release_items),
  1,
  'anonymous clients can read items of published releases'
);
select public.is(
  (select count(*)::integer from public.curriculum_pack_versions),
  1,
  'anonymous clients can read pack versions referenced by published releases'
);

select * from public.finish();
rollback;
