-- Infinite Tournament V7: unlimited character roster, one entrant per writer,
-- and a reusable tournament reset. Run once in Supabase SQL Editor.
-- Existing accounts and character profiles are preserved.

alter table public.characters
  add column if not exists selected_for_tournament boolean not null default false;

-- Enforce one selected character per writer at the database level.
create unique index if not exists one_selected_character_per_writer
  on public.characters(owner_id)
  where selected_for_tournament = true and owner_id is not null;

create or replace function public.set_tournament_character(p_character_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Please sign in first.';
  end if;
  if not exists (
    select 1 from public.characters
    where id = p_character_id and owner_id = auth.uid()
  ) then
    raise exception 'You can only select a character you own.';
  end if;
  if exists (select 1 from public.matches) then
    raise exception 'The tournament has already started. An administrator must reset it before writers can change their selected character.';
  end if;
  if exists (
    select 1 from public.characters
    where id = p_character_id and status = 'eliminated'
  ) then
    raise exception 'This character has been eliminated from the current tournament.';
  end if;
  update public.characters
    set selected_for_tournament = false
    where owner_id = auth.uid() and selected_for_tournament = true;
  update public.characters
    set selected_for_tournament = true
    where id = p_character_id and owner_id = auth.uid();
end;
$$;

grant execute on function public.set_tournament_character(uuid) to authenticated;

-- Replace the manual generator so only each writer's selected entrant is eligible.
create or replace function public.admin_generate_round(p_bracket_stage text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare new_round uuid; next_num integer; eligible uuid[]; i integer; total integer;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='admin') then
    raise exception 'Administrator access required.';
  end if;
  if p_bracket_stage not in ('winners','elimination','grand_final') then
    raise exception 'Invalid bracket stage.';
  end if;
  select coalesce(max(round_number),0)+1 into next_num from public.tournament_rounds;
  if p_bracket_stage='winners' then
    select array_agg(id order by random()) into eligible from public.characters
      where status='active' and coalesce(losses,0)=0 and selected_for_tournament=true;
  elsif p_bracket_stage='elimination' then
    select array_agg(id order by random()) into eligible from public.characters
      where status='active' and coalesce(losses,0)=1 and selected_for_tournament=true;
  else
    select array_agg(id order by random()) into eligible from public.characters
      where status='active' and coalesce(losses,0)<=1 and selected_for_tournament=true;
  end if;
  total:=coalesce(array_length(eligible,1),0);
  if total<2 then
    raise exception 'Not enough selected eligible characters. Each writer must select one character, and at least two eligible characters are needed.';
  end if;
  insert into public.tournament_rounds(round_number,bracket_stage,status,starts_at)
    values(next_num,p_bracket_stage,'open',now()) returning id into new_round;
  i:=1;
  while i<total loop
    insert into public.matches(round_id,character_a_id,character_b_id,status,bracket_stage,closes_at)
      values(new_round,eligible[i],eligible[i+1],'open',p_bracket_stage,now()+interval '3 days');
    i:=i+2;
  end loop;
  return new_round;
end;
$$;

grant execute on function public.admin_generate_round(text) to authenticated;

-- Destructive by design: clears this tournament's history, but keeps all writer
-- accounts and character records. The next tournament can use different characters.
create or replace function public.admin_reset_tournament()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='admin') then
    raise exception 'Administrator access required.';
  end if;
  -- Keep canon_archive as permanent history; its match/submission links are
  -- nullable and will be detached automatically when matches are deleted.
  delete from public.matches;
  delete from public.tournament_rounds;
  update public.characters
    set losses = 0,
        status = 'active',
        selected_for_tournament = false;
end;
$$;

grant execute on function public.admin_reset_tournament() to authenticated;
