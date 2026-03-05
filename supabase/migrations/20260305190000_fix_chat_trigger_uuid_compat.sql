-- Fix ensure_chat_for_match for schemas where relation keys are UUID.

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
    begin
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
    exception
      when datatype_mismatch then
        insert into public.projects (
          campaign_id,
          brand_id,
          partner_id,
          status,
          created_at,
          updated_at
        )
        values (
          v_campaign_id::uuid,
          v_brand_id::uuid,
          v_creator_id::uuid,
          'in_progress',
          now(),
          now()
        )
        returning id::text into v_project_id;
    end;
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
    begin
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
    exception
      when datatype_mismatch then
        insert into public.chats (
          project_id,
          campaign_id,
          brand_id,
          creator_id,
          created_at,
          updated_at
        )
        values (
          v_project_id::uuid,
          v_campaign_id::uuid,
          v_brand_id::uuid,
          v_creator_id::uuid,
          now(),
          now()
        )
        returning id::text into v_chat_id;
    end;
  else
    update public.chats c
    set updated_at = now()
    where c.id::text = v_chat_id;
  end if;

  return v_chat_id;
end;
$$;

-- Re-run backfill after function fix.
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
