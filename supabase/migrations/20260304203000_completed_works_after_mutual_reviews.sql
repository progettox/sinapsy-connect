-- Incrementa completed_works_count solo quando:
-- 1) brand + creator hanno concluso il lavoro (campagna completed)
-- 2) entrambe le review (brand->creator e creator->brand) sono presenti.
--
-- Logica idempotente: l'incremento avviene una sola volta per campagna.

-- ---------------------------------------------------------------------------
-- SUPPORT TABLE (idempotenza)
-- ---------------------------------------------------------------------------
create table if not exists public.completed_work_awards (
  campaign_id text primary key,
  brand_user_id text not null,
  creator_user_id text not null,
  awarded_at timestamptz not null default now()
);

create index if not exists completed_work_awards_brand_idx
  on public.completed_work_awards (brand_user_id);

create index if not exists completed_work_awards_creator_idx
  on public.completed_work_awards (creator_user_id);

-- ---------------------------------------------------------------------------
-- PROFILES: colonna contatore lavori completati
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.profiles') is not null then
    execute '
      alter table public.profiles
      add column if not exists completed_works_count integer not null default 0
    ';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Helper: incrementa completed_works_count per un profilo
-- Supporta schemi con chiave id o user_id (confronto testuale).
-- ---------------------------------------------------------------------------
create or replace function public.increment_completed_works_for_profile(
  p_user_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  has_profiles boolean;
  has_completed_col boolean;
  has_id_col boolean;
  has_user_id_col boolean;
begin
  if p_user_id is null or btrim(p_user_id) = '' then
    return;
  end if;

  has_profiles := to_regclass('public.profiles') is not null;
  if not has_profiles then
    return;
  end if;

  select exists(
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'completed_works_count'
  )
  into has_completed_col;

  if not has_completed_col then
    return;
  end if;

  select exists(
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'id'
  )
  into has_id_col;

  select exists(
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'user_id'
  )
  into has_user_id_col;

  if has_id_col then
    execute '
      update public.profiles
      set completed_works_count = coalesce(completed_works_count, 0) + 1
      where id::text = $1
    '
    using btrim(p_user_id);

    if found then
      return;
    end if;
  end if;

  if has_user_id_col then
    execute '
      update public.profiles
      set completed_works_count = coalesce(completed_works_count, 0) + 1
      where user_id::text = $1
    '
    using btrim(p_user_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger function: assegna +1 ai lavori completati quando entrambe le review
-- sono presenti per la coppia brand/creator della campagna completed.
-- ---------------------------------------------------------------------------
create or replace function public.award_completed_work_on_mutual_reviews()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_campaign_id text;
  from_user_id text;
  to_user_id text;

  campaign_data jsonb;
  campaign_status text;
  brand_user_id text;
  creator_user_id text;

  has_projects boolean;
  has_applications boolean;
  has_brand_to_creator boolean;
  has_creator_to_brand boolean;

  inserted_campaign_id text;
begin
  clean_campaign_id := btrim(
    coalesce(to_jsonb(new)->>'campaign_id', to_jsonb(new)->>'campaignId', '')
  );
  from_user_id := btrim(
    coalesce(to_jsonb(new)->>'from_user_id', to_jsonb(new)->>'fromUserId', '')
  );
  to_user_id := btrim(
    coalesce(to_jsonb(new)->>'to_user_id', to_jsonb(new)->>'toUserId', '')
  );

  if clean_campaign_id = '' or from_user_id = '' or to_user_id = '' then
    return new;
  end if;

  -- Già processata: niente doppio incremento.
  if exists (
    select 1
    from public.completed_work_awards a
    where a.campaign_id = clean_campaign_id
  ) then
    return new;
  end if;

  if to_regclass('public.campaigns') is null then
    return new;
  end if;

  select to_jsonb(c)
  into campaign_data
  from public.campaigns c
  where coalesce(to_jsonb(c)->>'id', to_jsonb(c)->>'campaignId') =
        clean_campaign_id
  limit 1;

  if campaign_data is null then
    return new;
  end if;

  campaign_status := lower(coalesce(campaign_data->>'status', ''));
  if campaign_status <> 'completed' then
    return new;
  end if;

  brand_user_id := btrim(
    coalesce(campaign_data->>'brand_id', campaign_data->>'brandId', '')
  );

  has_projects := to_regclass('public.projects') is not null;
  has_applications := to_regclass('public.applications') is not null;

  creator_user_id := '';

  if has_projects then
    select btrim(
      coalesce(
        p.j->>'partner_id',
        p.j->>'partnerId',
        p.j->>'creator_id',
        p.j->>'creatorId',
        p.j->>'applicant_id',
        p.j->>'applicantId',
        ''
      )
    )
    into creator_user_id
    from (
      select to_jsonb(pr) as j
      from public.projects pr
      where coalesce(to_jsonb(pr)->>'campaign_id', to_jsonb(pr)->>'campaignId')
            = clean_campaign_id
      order by
        case
          when lower(coalesce(to_jsonb(pr)->>'status', '')) = 'completed'
            then 0
          else 1
        end,
        coalesce(
          to_jsonb(pr)->>'updated_at',
          to_jsonb(pr)->>'updatedAt',
          to_jsonb(pr)->>'created_at',
          to_jsonb(pr)->>'createdAt',
          ''
        ) desc
      limit 1
    ) p;
  end if;

  if (creator_user_id is null or creator_user_id = '') and has_applications then
    select btrim(
      coalesce(
        a.j->>'applicant_id',
        a.j->>'creator_id',
        a.j->>'creatorId',
        a.j->>'applicantId',
        ''
      )
    )
    into creator_user_id
    from (
      select to_jsonb(ap) as j
      from public.applications ap
      where coalesce(to_jsonb(ap)->>'campaign_id', to_jsonb(ap)->>'campaignId')
            = clean_campaign_id
        and lower(coalesce(to_jsonb(ap)->>'status', '')) = 'accepted'
      limit 1
    ) a;
  end if;

  brand_user_id := btrim(coalesce(brand_user_id, ''));
  creator_user_id := btrim(coalesce(creator_user_id, ''));

  if brand_user_id = '' or creator_user_id = '' or brand_user_id = creator_user_id then
    return new;
  end if;

  -- Considera solo review tra i 2 partecipanti della collaborazione.
  if not (
    (from_user_id = brand_user_id and to_user_id = creator_user_id) or
    (from_user_id = creator_user_id and to_user_id = brand_user_id)
  ) then
    return new;
  end if;

  select exists (
    select 1
    from public.reviews r
    where coalesce(to_jsonb(r)->>'campaign_id', to_jsonb(r)->>'campaignId')
          = clean_campaign_id
      and coalesce(to_jsonb(r)->>'from_user_id', to_jsonb(r)->>'fromUserId')
          = brand_user_id
      and coalesce(to_jsonb(r)->>'to_user_id', to_jsonb(r)->>'toUserId')
          = creator_user_id
  )
  into has_brand_to_creator;

  select exists (
    select 1
    from public.reviews r
    where coalesce(to_jsonb(r)->>'campaign_id', to_jsonb(r)->>'campaignId')
          = clean_campaign_id
      and coalesce(to_jsonb(r)->>'from_user_id', to_jsonb(r)->>'fromUserId')
          = creator_user_id
      and coalesce(to_jsonb(r)->>'to_user_id', to_jsonb(r)->>'toUserId')
          = brand_user_id
  )
  into has_creator_to_brand;

  if not (has_brand_to_creator and has_creator_to_brand) then
    return new;
  end if;

  insert into public.completed_work_awards (
    campaign_id,
    brand_user_id,
    creator_user_id
  )
  values (
    clean_campaign_id,
    brand_user_id,
    creator_user_id
  )
  on conflict (campaign_id) do nothing
  returning campaign_id into inserted_campaign_id;

  if inserted_campaign_id is null then
    return new;
  end if;

  perform public.increment_completed_works_for_profile(brand_user_id);
  perform public.increment_completed_works_for_profile(creator_user_id);

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger su reviews (solo se la tabella esiste)
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.reviews') is not null then
    execute '
      drop trigger if exists trg_award_completed_work_on_review
      on public.reviews
    ';
    execute '
      create trigger trg_award_completed_work_on_review
      after insert on public.reviews
      for each row
      execute function public.award_completed_work_on_mutual_reviews()
    ';
  end if;
end $$;

