-- Campaign views tracking (unique per creator per campaign)
-- Adds a counter on campaigns and an RPC to track views safely.

create table if not exists public.campaign_views (
  campaign_id text not null,
  viewer_id text not null,
  viewed_at timestamptz not null default now(),
  primary key (campaign_id, viewer_id)
);

create index if not exists campaign_views_viewer_idx
  on public.campaign_views (viewer_id, viewed_at desc);

do $$
begin
  if to_regclass('public.campaigns') is not null then
    execute '
      alter table public.campaigns
      add column if not exists views_count integer not null default 0
    ';
  end if;
end $$;

alter table public.campaign_views enable row level security;

drop policy if exists campaign_views_insert_self on public.campaign_views;
create policy campaign_views_insert_self
on public.campaign_views
for insert
to authenticated
with check (auth.uid()::text = viewer_id::text);

drop policy if exists campaign_views_select_self on public.campaign_views;
create policy campaign_views_select_self
on public.campaign_views
for select
to authenticated
using (auth.uid()::text = viewer_id::text);

create or replace function public.track_campaign_views(p_campaign_ids text[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_campaign_id text;
  inserted_count integer := 0;
  is_trackable boolean;
begin
  if auth.uid() is null then
    return 0;
  end if;

  if p_campaign_ids is null or coalesce(array_length(p_campaign_ids, 1), 0) = 0 then
    return 0;
  end if;

  if to_regclass('public.campaigns') is null then
    return 0;
  end if;

  foreach clean_campaign_id in array p_campaign_ids loop
    clean_campaign_id := btrim(coalesce(clean_campaign_id, ''));
    if clean_campaign_id = '' then
      continue;
    end if;

    select exists (
      select 1
      from public.campaigns c
      where coalesce(to_jsonb(c)->>'id', to_jsonb(c)->>'campaignId') = clean_campaign_id
        and lower(coalesce(to_jsonb(c)->>'status', '')) = 'active'
    )
    into is_trackable;

    if not is_trackable then
      continue;
    end if;

    insert into public.campaign_views (campaign_id, viewer_id)
    values (clean_campaign_id, auth.uid()::text)
    on conflict (campaign_id, viewer_id) do nothing;

    if not found then
      continue;
    end if;

    update public.campaigns c
    set views_count = coalesce(c.views_count, 0) + 1
    where coalesce(to_jsonb(c)->>'id', to_jsonb(c)->>'campaignId') = clean_campaign_id;

    inserted_count := inserted_count + 1;
  end loop;

  return inserted_count;
end;
$$;

grant execute on function public.track_campaign_views(text[]) to authenticated;
