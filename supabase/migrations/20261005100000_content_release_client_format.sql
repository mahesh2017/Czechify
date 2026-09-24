-- A content release can say which app versions are able to read it.
--
-- Every installed app picks the newest release with status = 'published' and
-- checks it on the device before installing it. Until now, that check
-- rejected the whole release if any lesson used something the app did not
-- know, such as a new exercise type. The app then stayed on its old content
-- for every unit, silently.
--
-- Apps from content format 2 on (docs/CURRICULUM_V1_2_PLAN_2026-09-24.md)
-- also read status = 'gated' releases, but only those whose
-- min_client_format they support. Apps already installed read 'published'
-- only and cannot be taught otherwise, so a release they cannot read must
-- never carry that status. The check constraint below makes that impossible
-- rather than a rule to remember.
--
-- Deploy before shipping an app that queries min_client_format: an app built
-- against a database without the column cannot fetch remote content (it
-- keeps its bundled content until the column exists).

begin;

alter table public.content_releases
  add column min_client_format integer not null default 1
    constraint content_releases_min_client_format_positive
    check (min_client_format >= 1);

alter table public.content_releases
  drop constraint if exists content_releases_status_check;
alter table public.content_releases
  add constraint content_releases_status_check
  check (status in ('draft', 'published', 'gated', 'deprecated'));

alter table public.content_releases
  add constraint content_releases_published_readable_by_every_app
  check (status <> 'published' or min_client_format = 1);

comment on column public.content_releases.min_client_format is
  'Oldest app content format that can read this release. Above 1 requires status gated, which apps before format 2 never read.';

drop policy if exists content_releases_public_read on public.content_releases;
create policy content_releases_public_read
  on public.content_releases
  for select
  to anon, authenticated
  using (status in ('published', 'gated'));

drop policy if exists content_release_items_published_read
  on public.content_release_items;
create policy content_release_items_published_read
  on public.content_release_items
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.content_releases release
      where release.release_id = content_release_items.release_id
        and release.status in ('published', 'gated')
    )
  );

drop policy if exists curriculum_pack_versions_published_read
  on public.curriculum_pack_versions;
create policy curriculum_pack_versions_published_read
  on public.curriculum_pack_versions
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.content_release_items item
      join public.content_releases release
        on release.release_id = item.release_id
      where item.pack_key = curriculum_pack_versions.pack_key
        and item.pack_version = curriculum_pack_versions.version
        and release.status in ('published', 'gated')
    )
  );

create index if not exists content_releases_readable_idx
  on public.content_releases (published_at desc)
  where status in ('published', 'gated');

commit;
