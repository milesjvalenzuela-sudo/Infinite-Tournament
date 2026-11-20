-- Infinite Tournament: enforce character ownership when submitting stories.
-- Safe to run after the existing tournament migrations; it does not delete data.

create or replace function public.submit_match_story(
  p_match_id uuid,
  p_character_id uuid,
  p_content text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  match_row public.matches%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Please sign in first.';
  end if;

  -- Lock the matchup while checking and creating the submission.
  select * into match_row
  from public.matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'Match not found.';
  end if;

  if match_row.status not in ('open', 'writing') then
    raise exception 'This matchup is not accepting submissions.';
  end if;

  if p_character_id is null
     or p_character_id not in (match_row.character_a_id, match_row.character_b_id) then
    raise exception 'Choose one of the characters in this matchup.';
  end if;

  -- Critical security check: the signed-in user must own the selected character.
  if not exists (
    select 1
    from public.characters
    where id = p_character_id
      and owner_id = auth.uid()
  ) then
    raise exception 'You can only submit a story for a character you own.';
  end if;

  if length(trim(coalesce(p_content, ''))) < 100 then
    raise exception 'Your battle story must be at least 100 characters.';
  end if;

  if exists (
    select 1
    from public.submissions
    where match_id = p_match_id
      and character_id = p_character_id
  ) then
    raise exception 'A story has already been submitted for this character.';
  end if;

  insert into public.submissions(match_id, character_id, writer_id, content, status)
  values (p_match_id, p_character_id, auth.uid(), trim(p_content), 'published')
  returning id into new_id;

  if (
    select count(*)
    from public.submissions
    where match_id = p_match_id
      and status = 'published'
  ) >= 2 then
    update public.matches
    set status = 'voting'
    where id = p_match_id;
  else
    update public.matches
    set status = 'writing'
    where id = p_match_id;
  end if;

  return new_id;
end;
$$;

grant execute on function public.submit_match_story(uuid, uuid, text) to authenticated;
