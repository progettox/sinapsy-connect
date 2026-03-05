-- Message read receipts for 1:1 chats.
-- Adds read timestamp and exposes a secure RPC for participants.

alter table public.messages
  add column if not exists read_at timestamptz;

create index if not exists messages_chat_read_idx
  on public.messages (chat_id, read_at);

create or replace function public.mark_chat_messages_read(p_chat_id text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  viewer_id text := auth.uid()::text;
  updated_rows integer := 0;
  can_access boolean := false;
begin
  if viewer_id is null or btrim(coalesce(p_chat_id, '')) = '' then
    return 0;
  end if;

  select exists (
    select 1
    from public.chats c
    left join public.projects p
      on p.id::text = c.project_id::text
    where c.id::text = p_chat_id
      and (
        viewer_id = coalesce(c.brand_id::text, '')
        or viewer_id = coalesce(c.creator_id::text, '')
        or viewer_id = coalesce(p.brand_id::text, '')
        or viewer_id = coalesce(p.partner_id::text, '')
      )
  )
  into can_access;

  if not can_access then
    return 0;
  end if;

  update public.messages m
  set read_at = now()
  where m.chat_id::text = p_chat_id
    and m.sender_id::text <> viewer_id
    and m.read_at is null;

  get diagnostics updated_rows = row_count;
  return updated_rows;
end;
$$;

grant execute on function public.mark_chat_messages_read(text) to authenticated;
