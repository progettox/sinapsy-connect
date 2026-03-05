-- Time-series analytics (views, spent budget, matches) for authenticated brand.

create or replace function public.get_brand_analytics_timeseries(
  p_days integer default 30
)
returns table (
  bucket_date date,
  views_count integer,
  budget_spent numeric,
  matches_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  safe_days integer := greatest(1, least(coalesce(p_days, 30), 366));
  start_date date := current_date - (safe_days - 1);
begin
  if auth.uid() is null then
    return;
  end if;

  if to_regclass('public.campaigns') is null then
    return;
  end if;

  if to_regclass('public.campaign_views') is null then
    return query
    with my_campaigns as (
      select
        btrim(coalesce(to_jsonb(c)->>'id', to_jsonb(c)->>'campaignId', '')) as campaign_id,
        lower(btrim(coalesce(to_jsonb(c)->>'status', ''))) as status,
        coalesce(
          nullif(to_jsonb(c)->>'cash_offer', '')::numeric,
          nullif(to_jsonb(c)->>'cashOffer', '')::numeric,
          0::numeric
        ) as budget,
        coalesce(
          nullif(to_jsonb(c)->>'updated_at', '')::timestamptz,
          nullif(to_jsonb(c)->>'updatedAt', '')::timestamptz,
          nullif(to_jsonb(c)->>'created_at', '')::timestamptz,
          nullif(to_jsonb(c)->>'createdAt', '')::timestamptz
        ) as event_ts
      from public.campaigns c
      where btrim(coalesce(to_jsonb(c)->>'brand_id', to_jsonb(c)->>'brandId', ''))
            = auth.uid()::text
    ),
    day_series as (
      select generate_series(start_date, current_date, interval '1 day')::date as day
    ),
    performance_by_day as (
      select
        mc.event_ts::date as day,
        count(*) filter (where mc.status in ('matched', 'completed'))::integer as matches_count,
        coalesce(
          sum(case when mc.status in ('matched', 'completed') then mc.budget else 0 end),
          0
        )::numeric as budget_spent
      from my_campaigns mc
      where mc.event_ts is not null
        and mc.event_ts::date >= start_date
        and mc.event_ts::date <= current_date
      group by 1
    )
    select
      ds.day as bucket_date,
      0::integer as views_count,
      coalesce(p.budget_spent, 0)::numeric as budget_spent,
      coalesce(p.matches_count, 0)::integer as matches_count
    from day_series ds
    left join performance_by_day p on p.day = ds.day
    order by ds.day asc;
    return;
  end if;

  return query
  with my_campaigns as (
    select
      btrim(coalesce(to_jsonb(c)->>'id', to_jsonb(c)->>'campaignId', '')) as campaign_id,
      lower(btrim(coalesce(to_jsonb(c)->>'status', ''))) as status,
      coalesce(
        nullif(to_jsonb(c)->>'cash_offer', '')::numeric,
        nullif(to_jsonb(c)->>'cashOffer', '')::numeric,
        0::numeric
      ) as budget,
      coalesce(
        nullif(to_jsonb(c)->>'updated_at', '')::timestamptz,
        nullif(to_jsonb(c)->>'updatedAt', '')::timestamptz,
        nullif(to_jsonb(c)->>'created_at', '')::timestamptz,
        nullif(to_jsonb(c)->>'createdAt', '')::timestamptz
      ) as event_ts
    from public.campaigns c
    where btrim(coalesce(to_jsonb(c)->>'brand_id', to_jsonb(c)->>'brandId', ''))
          = auth.uid()::text
  ),
  day_series as (
    select generate_series(start_date, current_date, interval '1 day')::date as day
  ),
  views_by_day as (
    select
      (cv.viewed_at at time zone 'utc')::date as day,
      count(*)::integer as views_count
    from public.campaign_views cv
    join my_campaigns mc on mc.campaign_id = cv.campaign_id
    where cv.viewed_at >= start_date::timestamptz
      and cv.viewed_at < (current_date + 1)::timestamptz
    group by 1
  ),
  performance_by_day as (
    select
      mc.event_ts::date as day,
      count(*) filter (where mc.status in ('matched', 'completed'))::integer as matches_count,
      coalesce(
        sum(case when mc.status in ('matched', 'completed') then mc.budget else 0 end),
        0
      )::numeric as budget_spent
    from my_campaigns mc
    where mc.event_ts is not null
      and mc.event_ts::date >= start_date
      and mc.event_ts::date <= current_date
    group by 1
  )
  select
    ds.day as bucket_date,
    coalesce(v.views_count, 0)::integer as views_count,
    coalesce(p.budget_spent, 0)::numeric as budget_spent,
    coalesce(p.matches_count, 0)::integer as matches_count
  from day_series ds
  left join views_by_day v on v.day = ds.day
  left join performance_by_day p on p.day = ds.day
  order by ds.day asc;
end;
$$;

grant execute on function public.get_brand_analytics_timeseries(integer) to authenticated;
