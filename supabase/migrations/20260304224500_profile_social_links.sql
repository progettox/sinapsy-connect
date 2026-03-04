-- Social links for profile public rail and onboarding.
-- Adds dedicated columns for Instagram, TikTok and optional website.

do $$
begin
  if to_regclass('public.profiles') is null then
    return;
  end if;

  alter table public.profiles
    add column if not exists instagram_url text;

  alter table public.profiles
    add column if not exists tiktok_url text;

  alter table public.profiles
    add column if not exists website_url text;
end $$;
