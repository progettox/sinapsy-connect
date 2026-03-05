-- Monthly views stats for the authenticated brand.
-- Returns current month and previous month view counts using campaign_views logs.

create or replace function public.get_brand_campaign_views_monthly()
returns table (
  current_month integer,
  previous_month integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  start_current timestamptz := date_trunc('month', now());
  start_next timestamptz := start_current + interval '1 month';
  start_previous timestamptz := start_current - interval '1 month';
begin
  if auth.uid() is null then
    return query select 0::integer, 0::integer;
    return;
  end if;

  if to_regclass('public.campaigns') is null
     or to_regclass('public.campaign_views') is null then
    return query select 0::integer, 0::integer;
    return;
  end if;

  return query
  with my_campaigns as (
    select btrim(coalesce(to_jsonb(c)->>'id', to_jsonb(c)->>'campaignId', ''))
      as campaign_id
    from public.campaigns c
    where btrim(coalesce(to_jsonb(c)->>'brand_id', to_jsonb(c)->>'brandId', ''))
          = auth.uid()::text
  ),
  scoped_views as (
    select cv.viewed_at
    from public.campaign_views cv
    join my_campaigns mc on mc.campaign_id = cv.campaign_id
  )
  select
    count(*) filter (
      where viewed_at >= start_current and viewed_at < start_next
    )::integer as current_month,
    count(*) filter (
      where viewed_at >= start_previous and viewed_at < start_current
    )::integer as previous_month
  from scoped_views;
end;
$$;

grant execute on function public.get_brand_campaign_views_monthly() to authenticated;
