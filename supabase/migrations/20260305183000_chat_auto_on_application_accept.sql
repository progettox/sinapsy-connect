-- Chat stack hardening:
-- - ensures projects/chats/messages schema is present
-- - enforces RLS for participants
-- - auto-creates chat workspace when an application is accepted
-- - backfills missing chats for already accepted applications

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- BASE TABLES (idempotent)
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid()
);

alter table public.projects
  add column if not exists campaign_id text;
alter table public.projects
  add column if not exists brand_id text;
alter table public.projects
  add column if not exists partner_id text;
alter table public.projects
  add column if not exists status text not null default 'in_progress';
alter table public.projects
  add column if not exists created_at timestamptz default now();
alter table public.projects
  add column if not exists updated_at timestamptz default now();

create index if not exists projects_match_lookup_idx
  on public.projects (campaign_id, brand_id, partner_id);

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid()
);

alter table public.chats
  add column if not exists project_id text;
alter table public.chats
  add column if not exists campaign_id text;
alter table public.chats
  add column if not exists brand_id text;
alter table public.chats
  add column if not exists creator_id text;
alter table public.chats
  add column if not exists last_message text;
alter table public.chats
  add column if not exists created_at timestamptz default now();
alter table public.chats
  add column if not exists updated_at timestamptz default now();

create index if not exists chats_project_lookup_idx
  on public.chats (project_id);
create index if not exists chats_match_lookup_idx
  on public.chats (campaign_id, brand_id, creator_id);
create index if not exists chats_updated_at_idx
  on public.chats (updated_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid()
);

alter table public.messages
  add column if not exists chat_id text;
alter table public.messages
  add column if not exists sender_id text;
alter table public.messages
  add column if not exists body text;
alter table public.messages
  add column if not exists text text;
alter table public.messages
  add column if not exists created_at timestamptz default now();

create index if not exists messages_chat_created_idx
  on public.messages (chat_id, created_at);
create index if not exists messages_sender_created_idx
  on public.messages (sender_id, created_at desc);

-- ---------------------------------------------------------------------------
-- UPDATED_AT TRIGGERS
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_projects_set_updated_at on public.projects;
create trigger trg_projects_set_updated_at
before update on public.projects
for each row
execute function public.set_updated_at_column();

drop trigger if exists trg_chats_set_updated_at on public.chats;
create trigger trg_chats_set_updated_at
before update on public.chats
for each row
execute function public.set_updated_at_column();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.projects enable row level security;
alter table public.chats enable row level security;
alter table public.messages enable row level security;

drop policy if exists projects_select_participants on public.projects;
create policy projects_select_participants
on public.projects
for select
to authenticated
using (
  auth.uid()::text = brand_id::text
  or auth.uid()::text = partner_id::text
);

drop policy if exists projects_insert_participants on public.projects;
create policy projects_insert_participants
on public.projects
for insert
to authenticated
with check (
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

drop policy if exists chats_select_participants on public.chats;
create policy chats_select_participants
on public.chats
for select
to authenticated
using (
  auth.uid()::text = coalesce(brand_id::text, '')
  or auth.uid()::text = coalesce(creator_id::text, '')
  or exists (
    select 1
    from public.projects p
    where p.id::text = chats.project_id::text
      and (
        auth.uid()::text = p.brand_id::text
        or auth.uid()::text = p.partner_id::text
      )
  )
);

drop policy if exists chats_insert_participants on public.chats;
create policy chats_insert_participants
on public.chats
for insert
to authenticated
with check (
  auth.uid()::text = coalesce(brand_id::text, '')
  or auth.uid()::text = coalesce(creator_id::text, '')
  or exists (
    select 1
    from public.projects p
    where p.id::text = chats.project_id::text
      and (
        auth.uid()::text = p.brand_id::text
        or auth.uid()::text = p.partner_id::text
      )
  )
);

drop policy if exists chats_update_participants on public.chats;
create policy chats_update_participants
on public.chats
for update
to authenticated
using (
  auth.uid()::text = coalesce(brand_id::text, '')
  or auth.uid()::text = coalesce(creator_id::text, '')
  or exists (
    select 1
    from public.projects p
    where p.id::text = chats.project_id::text
      and (
        auth.uid()::text = p.brand_id::text
        or auth.uid()::text = p.partner_id::text
      )
  )
)
with check (
  auth.uid()::text = coalesce(brand_id::text, '')
  or auth.uid()::text = coalesce(creator_id::text, '')
  or exists (
    select 1
    from public.projects p
    where p.id::text = chats.project_id::text
      and (
        auth.uid()::text = p.brand_id::text
        or auth.uid()::text = p.partner_id::text
      )
  )
);

drop policy if exists messages_select_participants on public.messages;
create policy messages_select_participants
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.chats c
    left join public.projects p
      on p.id::text = c.project_id::text
    where c.id::text = messages.chat_id::text
      and (
        auth.uid()::text = coalesce(c.brand_id::text, '')
        or auth.uid()::text = coalesce(c.creator_id::text, '')
        or auth.uid()::text = coalesce(p.brand_id::text, '')
        or auth.uid()::text = coalesce(p.partner_id::text, '')
      )
  )
);

drop policy if exists messages_insert_participants on public.messages;
create policy messages_insert_participants
on public.messages
for insert
to authenticated
with check (
  auth.uid()::text = sender_id::text
  and exists (
    select 1
    from public.chats c
    left join public.projects p
      on p.id::text = c.project_id::text
    where c.id::text = messages.chat_id::text
      and (
        auth.uid()::text = coalesce(c.brand_id::text, '')
        or auth.uid()::text = coalesce(c.creator_id::text, '')
        or auth.uid()::text = coalesce(p.brand_id::text, '')
        or auth.uid()::text = coalesce(p.partner_id::text, '')
      )
      and coalesce(lower(p.status), '') <> 'disputed'
  )
);

drop policy if exists messages_update_none on public.messages;
create policy messages_update_none
on public.messages
for update
to authenticated
using (false)
with check (false);

drop policy if exists messages_delete_none on public.messages;
create policy messages_delete_none
on public.messages
for delete
to authenticated
using (false);

-- ---------------------------------------------------------------------------
-- MATCH -> PROJECT + CHAT AUTOCREATION
-- ---------------------------------------------------------------------------
create or replace function public.ensure_chat_for_match(
  p_campaign_id text,
  p_brand_id text,
  p_creator_id text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign_id text := nullif(trim(coalesce(p_campaign_id, '')), '');
  v_brand_id text := nullif(trim(coalesce(p_brand_id, '')), '');
  v_creator_id text := nullif(trim(coalesce(p_creator_id, '')), '');
  v_project_id text;
  v_chat_id text;
begin
  if v_campaign_id is null or v_brand_id is null or v_creator_id is null then
    return null;
  end if;

  select p.id::text
  into v_project_id
  from public.projects p
  where p.campaign_id::text = v_campaign_id
    and p.brand_id::text = v_brand_id
    and p.partner_id::text = v_creator_id
  order by p.created_at asc nulls first
  limit 1;

  if v_project_id is null then
    insert into public.projects (
      campaign_id,
      brand_id,
      partner_id,
      status,
      created_at,
      updated_at
    )
    values (
      v_campaign_id,
      v_brand_id,
      v_creator_id,
      'in_progress',
      now(),
      now()
    )
    returning id::text into v_project_id;
  end if;

  select c.id::text
  into v_chat_id
  from public.chats c
  where c.project_id::text = v_project_id
  order by c.created_at asc nulls first
  limit 1;

  if v_chat_id is null then
    select c.id::text
    into v_chat_id
    from public.chats c
    where c.campaign_id::text = v_campaign_id
      and c.brand_id::text = v_brand_id
      and c.creator_id::text = v_creator_id
    order by c.created_at asc nulls first
    limit 1;
  end if;

  if v_chat_id is null then
    insert into public.chats (
      project_id,
      campaign_id,
      brand_id,
      creator_id,
      created_at,
      updated_at
    )
    values (
      v_project_id,
      v_campaign_id,
      v_brand_id,
      v_creator_id,
      now(),
      now()
    )
    returning id::text into v_chat_id;
  else
    update public.chats c
    set
      project_id = coalesce(nullif(trim(c.project_id), ''), v_project_id),
      campaign_id = coalesce(nullif(trim(c.campaign_id), ''), v_campaign_id),
      brand_id = coalesce(nullif(trim(c.brand_id), ''), v_brand_id),
      creator_id = coalesce(nullif(trim(c.creator_id), ''), v_creator_id),
      updated_at = now()
    where c.id::text = v_chat_id;
  end if;

  return v_chat_id;
end;
$$;

create or replace function public.trg_create_chat_on_application_accept()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  payload jsonb := to_jsonb(new);
  old_payload jsonb := coalesce(to_jsonb(old), '{}'::jsonb);
  v_status text := lower(coalesce(payload ->> 'status', ''));
  v_old_status text := lower(coalesce(old_payload ->> 'status', ''));
  v_campaign_id text := coalesce(
    payload ->> 'campaign_id',
    payload ->> 'campaignId'
  );
  v_creator_id text := coalesce(
    payload ->> 'applicant_id',
    payload ->> 'creator_id',
    payload ->> 'creatorId'
  );
  v_brand_id text := coalesce(
    payload ->> 'brand_id',
    payload ->> 'brandId'
  );
begin
  if v_status <> 'accepted' then
    return new;
  end if;

  if tg_op = 'UPDATE' and v_old_status = 'accepted' then
    return new;
  end if;

  if nullif(trim(coalesce(v_brand_id, '')), '') is null then
    select coalesce(
      to_jsonb(c) ->> 'brand_id',
      to_jsonb(c) ->> 'brandId'
    )
    into v_brand_id
    from public.campaigns c
    where c.id::text = v_campaign_id::text
    limit 1;
  end if;

  perform public.ensure_chat_for_match(v_campaign_id, v_brand_id, v_creator_id);
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.applications') is null then
    return;
  end if;

  drop trigger if exists trg_create_chat_on_application_accept on public.applications;
  create trigger trg_create_chat_on_application_accept
  after insert or update on public.applications
  for each row
  execute function public.trg_create_chat_on_application_accept();
end;
$$;

-- Backfill: ensure accepted applications have a chat workspace.
do $$
declare
  row_record record;
  payload jsonb;
  v_campaign_id text;
  v_creator_id text;
  v_brand_id text;
begin
  if to_regclass('public.applications') is null then
    return;
  end if;

  for row_record in
    select *
    from public.applications
  loop
    payload := to_jsonb(row_record);
    if lower(coalesce(payload ->> 'status', '')) <> 'accepted' then
      continue;
    end if;

    v_campaign_id := coalesce(
      payload ->> 'campaign_id',
      payload ->> 'campaignId'
    );
    v_creator_id := coalesce(
      payload ->> 'applicant_id',
      payload ->> 'creator_id',
      payload ->> 'creatorId'
    );
    v_brand_id := coalesce(
      payload ->> 'brand_id',
      payload ->> 'brandId'
    );

    if nullif(trim(coalesce(v_brand_id, '')), '') is null then
      select coalesce(
        to_jsonb(c) ->> 'brand_id',
        to_jsonb(c) ->> 'brandId'
      )
      into v_brand_id
      from public.campaigns c
      where c.id::text = v_campaign_id::text
      limit 1;
    end if;

    perform public.ensure_chat_for_match(v_campaign_id, v_brand_id, v_creator_id);
  end loop;
end;
$$;

-- Realtime stream support for chat payloads.
do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'messages'
    ) then
      alter publication supabase_realtime add table public.messages;
    end if;
  end if;
end;
$$;
