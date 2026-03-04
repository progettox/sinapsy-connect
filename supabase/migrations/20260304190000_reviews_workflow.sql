-- Reviews + work completion workflow
-- Idempotent migration for Supabase Postgres.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- REVIEWS TABLE
-- ---------------------------------------------------------------------------
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid()
);

alter table public.reviews
  add column if not exists campaign_id text;
alter table public.reviews
  add column if not exists from_user_id text;
alter table public.reviews
  add column if not exists to_user_id text;
alter table public.reviews
  add column if not exists rating int;
alter table public.reviews
  add column if not exists text text;
alter table public.reviews
  add column if not exists created_at timestamptz default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reviews_rating_check'
  ) then
    alter table public.reviews
      add constraint reviews_rating_check check (rating between 1 and 5);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reviews_no_self'
  ) then
    alter table public.reviews
      add constraint reviews_no_self check (from_user_id <> to_user_id);
  end if;
end $$;

create unique index if not exists reviews_once_per_side_idx
  on public.reviews (campaign_id, from_user_id, to_user_id);

create index if not exists reviews_to_user_idx
  on public.reviews (to_user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- PROJECT STATUS FOR DOUBLE-CHECK WORKFLOW
-- ---------------------------------------------------------------------------
alter table public.projects
  add column if not exists status text not null default 'in_progress';

do $$
begin
  -- Drop only known/legacy status constraints if present.
  alter table public.projects drop constraint if exists projects_status_check;
  alter table public.projects drop constraint if exists projects_status_valid;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'projects_status_check'
      and conrelid = 'public.projects'::regclass
  ) then
    alter table public.projects
      add constraint projects_status_check
      check (
        status in (
          'in_progress',
          'delivered_brand',
          'delivered_creator',
          'completed',
          'disputed'
        )
      );
  end if;
end $$;

update public.projects
set status = 'delivered_creator'
where status = 'delivered';

-- ---------------------------------------------------------------------------
-- RLS: REVIEWS
-- ---------------------------------------------------------------------------
alter table public.reviews enable row level security;

drop policy if exists reviews_select_participants on public.reviews;
create policy reviews_select_participants
on public.reviews
for select
to authenticated
using (
  auth.uid()::text = from_user_id::text
  or auth.uid()::text = to_user_id::text
);

drop policy if exists reviews_insert_from_self on public.reviews;
create policy reviews_insert_from_self
on public.reviews
for insert
to authenticated
with check (
  auth.uid()::text = from_user_id::text
);

drop policy if exists reviews_update_none on public.reviews;
create policy reviews_update_none
on public.reviews
for update
to authenticated
using (false)
with check (false);

drop policy if exists reviews_delete_none on public.reviews;
create policy reviews_delete_none
on public.reviews
for delete
to authenticated
using (false);

-- ---------------------------------------------------------------------------
-- RLS: PROJECTS
-- ---------------------------------------------------------------------------
alter table public.projects enable row level security;

drop policy if exists projects_select_participants on public.projects;
create policy projects_select_participants
on public.projects
for select
to authenticated
using (
  auth.uid()::text = brand_id::text
  or auth.uid()::text = partner_id::text
);

drop policy if exists projects_update_participants on public.projects;
create policy projects_update_participants
on public.projects
for update
to authenticated
using (
  auth.uid()::text = brand_id::text
  or auth.uid()::text = partner_id::text
)
with check (
  auth.uid()::text = brand_id::text
  or auth.uid()::text = partner_id::text
);

-- ---------------------------------------------------------------------------
-- RLS: CAMPAIGNS COMPLETION BY PARTICIPANTS
-- ---------------------------------------------------------------------------
alter table public.campaigns enable row level security;

drop policy if exists campaigns_complete_by_participants on public.campaigns;
create policy campaigns_complete_by_participants
on public.campaigns
for update
to authenticated
using (
  auth.uid()::text = brand_id::text
  or exists (
    select 1
    from public.projects p
    where p.campaign_id::text = campaigns.id::text
      and p.partner_id::text = auth.uid()::text
  )
)
with check (status = 'completed');
