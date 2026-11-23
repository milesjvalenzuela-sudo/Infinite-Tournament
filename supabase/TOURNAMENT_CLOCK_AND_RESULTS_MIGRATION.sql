-- Infinite Tournament V8
-- Adds deterministic match closure rules, archived match results, active-match filtering
-- support, and a three-day server-side tournament clock.
-- Run this once in Supabase SQL Editor AFTER the existing V7 migrations.
-- Existing accounts, characters, submissions, votes, and canon archive rows are preserved.


-- A tournament identifier separates the current competition from preserved archive history.
create table if not exists public.tournament_state (
  singleton boolean primary key default true check (singleton = true),
  current_tournament_id uuid not null default gen_random_uuid(),
  started_at timestamptz,
  updated_at timestamptz not null default now()
);
insert into public.tournament_state(singleton)
values (true) on conflict (singleton) do nothing;

alter table public.tournament_rounds add column if not exists tournament_id uuid;
alter table public.matches add column if not exists tournament_id uuid;
update public.tournament_rounds
set tournament_id = (select current_tournament_id from public.tournament_state where singleton = true)
where tournament_id is null;
update public.matches m
set tournament_id = coalesce(r.tournament_id, (select current_tournament_id from public.tournament_state where singleton = true))
from public.tournament_rounds r
where m.round_id = r.id and m.tournament_id is null;
update public.matches
set tournament_id = (select current_tournament_id from public.tournament_state where singleton = true)
where tournament_id is null;
create index if not exists tournament_rounds_tournament_idx on public.tournament_rounds(tournament_id, round_number);
create index if not exists matches_tournament_idx on public.matches(tournament_id, status);

alter table public.tournament_state enable row level security;
drop policy if exists tournament_state_public_read on public.tournament_state;
create policy tournament_state_public_read on public.tournament_state for select to anon, authenticated using (true);
grant select on public.tournament_state to anon, authenticated;

-- Compatibility trigger for databases that still have the original required
-- character_one_id / character_two_id columns alongside character_a_id / character_b_id.
create or replace function public.sync_match_character_columns()
returns trigger
language plpgsql
as $$
begin
  new.character_one_id := coalesce(new.character_one_id, new.character_a_id);
  new.character_two_id := coalesce(new.character_two_id, new.character_b_id);
  new.character_a_id := coalesce(new.character_a_id, new.character_one_id);
  new.character_b_id := coalesce(new.character_b_id, new.character_two_id);
  return new;
end;
$$;

drop trigger if exists sync_match_character_columns_trigger on public.matches;
create trigger sync_match_character_columns_trigger
before insert or update on public.matches
for each row execute function public.sync_match_character_columns();

-- Ensure submissions fill both the legacy required title/story fields and the
-- newer content field used by the website.
create or replace function public.submit_match_story(p_match_id uuid, p_character_id uuid, p_content text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_id uuid;
  match_row public.matches%rowtype;
  character_name text;
  opponent_name text;
  opponent_id uuid;
begin
  if auth.uid() is null then raise exception 'Please sign in first.'; end if;
  select * into match_row from public.matches where id = p_match_id for update;
  if not found then raise exception 'Match not found.'; end if;
  if match_row.status not in ('open', 'writing') then raise exception 'This matchup is not accepting submissions.'; end if;
  if p_character_id not in (match_row.character_a_id, match_row.character_b_id) then
    raise exception 'Choose one of the characters in this matchup.';
  end if;
  if not exists (select 1 from public.characters where id = p_character_id and owner_id = auth.uid()) then
    raise exception 'You can only submit a story for a character you own.';
  end if;
  if length(trim(coalesce(p_content, ''))) < 100 then
    raise exception 'Your battle story must be at least 100 characters.';
  end if;
  if exists (select 1 from public.submissions where match_id = p_match_id and character_id = p_character_id) then
    raise exception 'A story has already been submitted for this character.';
  end if;

  opponent_id := case when p_character_id = match_row.character_a_id then match_row.character_b_id else match_row.character_a_id end;
  select name into character_name from public.characters where id = p_character_id;
  select name into opponent_name from public.characters where id = opponent_id;

  insert into public.submissions(
    match_id, character_id, writer_id, title, story, content, is_published, status
  ) values (
    p_match_id, p_character_id, auth.uid(),
    coalesce(character_name, 'Character') || ' vs. ' || coalesce(opponent_name, 'Opponent'),
    trim(p_content), trim(p_content), true, 'published'
  ) returning id into new_id;

  if (select count(*) from public.submissions where match_id = p_match_id and status = 'published') >= 2 then
    update public.matches set status = 'voting' where id = p_match_id;
  end if;
  return new_id;
end;
$$;

grant execute on function public.submit_match_story(uuid, uuid, text) to authenticated;

-- Record how a match was decided. Existing rows remain valid (NULL means legacy result).
alter table public.matches
  add column if not exists result_method text,
  add column if not exists result_note text;

-- Keep this column constrained to the supported result types.
alter table public.matches drop constraint if exists matches_result_method_check;
alter table public.matches add constraint matches_result_method_check
  check (result_method is null or result_method in ('votes', 'single_submission', 'coin_flip'));

-- Internal close function. It locks the match and writes the result exactly once.
create or replace function public.finish_match_internal(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m public.matches%rowtype;
  submission_count integer;
  vote_count integer;
  winning_submission uuid;
  winning_character uuid;
  losing_character uuid;
  method text;
  winning_title text;
  winning_story text;
  winning_votes integer;
begin
  select * into m from public.matches where id = p_match_id for update;
  if not found then raise exception 'Match not found.'; end if;
  if m.status = 'closed' then return; end if;

  select count(*) into submission_count
  from public.submissions s
  where s.match_id = p_match_id and s.status = 'published';

  if submission_count = 0 then
    raise exception 'This match has no submitted stories. An administrator must resolve it before the next round can begin.';
  elsif submission_count = 1 then
    select s.id, s.character_id, coalesce(nullif(s.title, ''), c.name || ' wins'),
           coalesce(s.content, s.story, '')
      into winning_submission, winning_character, winning_title, winning_story
    from public.submissions s
    left join public.characters c on c.id = s.character_id
    where s.match_id = p_match_id and s.status = 'published'
    order by s.created_at asc limit 1;
    method := 'single_submission';
  else
    select count(*) into vote_count
    from public.votes v
    join public.submissions s on s.id = v.submission_id
    where s.match_id = p_match_id and s.status = 'published';

    if vote_count = 0 then
      -- One random draw; the selected submission and method are persisted on the match.
      select s.id, s.character_id, coalesce(nullif(s.title, ''), c.name || ' wins'),
             coalesce(s.content, s.story, '')
        into winning_submission, winning_character, winning_title, winning_story
      from public.submissions s
      left join public.characters c on c.id = s.character_id
      where s.match_id = p_match_id and s.status = 'published'
      order by random() limit 1;
      method := 'coin_flip';
    else
      select s.id, s.character_id, coalesce(nullif(s.title, ''), c.name || ' wins'),
             coalesce(s.content, s.story, ''), count(v.id)::integer
        into winning_submission, winning_character, winning_title, winning_story, winning_votes
      from public.submissions s
      left join public.characters c on c.id = s.character_id
      left join public.votes v on v.submission_id = s.id
      where s.match_id = p_match_id and s.status = 'published'
      group by s.id, s.character_id, s.title, c.name, s.content, s.story, s.created_at
      order by count(v.id) desc, s.created_at asc
      limit 1;
      method := 'votes';
    end if;
  end if;

  if winning_submission is null or winning_character is null then
    raise exception 'Could not determine a valid winning submission.';
  end if;
  if winning_character not in (m.character_a_id, m.character_b_id) then
    raise exception 'The winning submission does not belong to either character in this match.';
  end if;

  losing_character := case when winning_character = m.character_a_id
                           then m.character_b_id else m.character_a_id end;

  -- Archive columns include both the newer required names and legacy compatibility names.
  insert into public.canon_archive(
    match_id, winning_submission_id, winning_character_id, story_title, story_text,
    submission_id, character_id, title, created_at
  ) values (
    p_match_id, winning_submission, winning_character, winning_title, winning_story,
    winning_submission, winning_character, winning_title, now()
  ) on conflict do nothing;

  update public.matches
  set status = 'closed',
      winner_submission_id = winning_submission,
      winner_character_id = winning_character,
      result_method = method,
      result_note = case method
        when 'single_submission' then 'Won by submitting when the opponent did not submit.'
        when 'coin_flip' then 'Both writers submitted; no votes were cast, so the winner was chosen by a 50/50 coin flip.'
        else 'Won by public vote.' end
  where id = p_match_id;

  update public.characters
  set losses = coalesce(losses, 0) + 1,
      status = case when coalesce(losses, 0) + 1 >= 2 then 'eliminated' else 'active' end
  where id = losing_character;

  update public.tournament_rounds r
  set status = 'completed', ends_at = coalesce(r.ends_at, now())
  where r.id = m.round_id
    and not exists (
      select 1 from public.matches pending
      where pending.round_id = r.id and pending.status <> 'closed'
    );
end;
$$;

-- Admin-facing closure wrapper. It retains the existing RPC name used by the website.
create or replace function public.admin_close_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Administrator access required.';
  end if;
  perform public.finish_match_internal(p_match_id);
end;
$$;

revoke all on function public.finish_match_internal(uuid) from public, anon, authenticated;
revoke all on function public.admin_close_match(uuid) from public, anon;
grant execute on function public.admin_close_match(uuid) to authenticated;

-- Create a round using only selected entrants. The first round is created by an admin;
-- subsequent rounds are created by the clock after the previous round is complete.
create or replace function public.admin_generate_round(p_bracket_stage text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_round uuid;
  next_num integer;
  eligible uuid[];
  total integer;
  i integer := 1;
  first_character uuid;
  second_character uuid;
  current_tournament uuid;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Administrator access required.';
  end if;
  if p_bracket_stage not in ('winners', 'elimination', 'grand_final') then
    raise exception 'Invalid bracket stage.';
  end if;
  select current_tournament_id into current_tournament from public.tournament_state where singleton = true;
  if exists (select 1 from public.matches where tournament_id = current_tournament and status <> 'closed') then
    raise exception 'Close or resolve every current match before creating another round.';
  end if;
  if exists (select 1 from public.tournament_rounds where tournament_id = current_tournament) then
    raise exception 'This tournament has already started. Later rounds are created by the tournament clock.';
  end if;

  if p_bracket_stage = 'winners' then
    select array_agg(id order by random()) into eligible from public.characters
    where status = 'active' and coalesce(losses, 0) = 0 and selected_for_tournament = true;
  elsif p_bracket_stage = 'elimination' then
    select array_agg(id order by random()) into eligible from public.characters
    where status = 'active' and coalesce(losses, 0) = 1 and selected_for_tournament = true;
  else
    select array_agg(id order by random()) into eligible from public.characters
    where status = 'active' and coalesce(losses, 0) <= 1 and selected_for_tournament = true;
  end if;
  total := coalesce(array_length(eligible, 1), 0);
  if total < 2 then
    raise exception 'At least two eligible selected characters are required to create a bracket.';
  end if;

  select coalesce(max(round_number), 0) + 1 into next_num from public.tournament_rounds;
  insert into public.tournament_rounds(round_number, bracket_stage, status, starts_at, tournament_id)
  values (next_num, p_bracket_stage, 'open', now(), current_tournament) returning id into new_round;

  while i < total loop
    first_character := eligible[i];
    second_character := eligible[i + 1];
    insert into public.matches(round_id, character_a_id, character_b_id, status, bracket_stage, closes_at, tournament_id)
    values (new_round, first_character, second_character, 'open', p_bracket_stage, now() + interval '3 days', current_tournament);
    i := i + 2;
  end loop;
  update public.tournament_state set started_at = now(), updated_at = now() where singleton = true;
  return new_round;
end;
$$;

grant execute on function public.admin_generate_round(text) to authenticated;

-- Decide which bracket stage comes next and create its matchups.
create or replace function public.auto_generate_round()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_round uuid;
  next_num integer;
  stage text;
  eligible uuid[];
  total integer;
  i integer := 1;
  first_character uuid;
  second_character uuid;
  final_a uuid;
  final_b uuid;
  last_start timestamptz;
  current_tournament uuid;
begin
  select current_tournament_id into current_tournament from public.tournament_state where singleton = true;
  if exists (select 1 from public.matches where tournament_id = current_tournament and status <> 'closed') then return null; end if;
  select starts_at into last_start from public.tournament_rounds
  where tournament_id = current_tournament
  order by round_number desc nulls last, created_at desc limit 1;
  if last_start is null or last_start > now() - interval '3 days' then return null; end if;

  -- If the undefeated finalist lost the first Grand Final, the same two finalists play
  -- the required double-elimination reset match.
  select m.character_a_id, m.character_b_id into final_a, final_b
  from public.matches m
  where m.tournament_id = current_tournament and m.round_id = (select r.id from public.tournament_rounds r where r.tournament_id = current_tournament order by r.round_number desc nulls last, r.created_at desc limit 1)
    and m.bracket_stage = 'grand_final' and m.status = 'closed'
    and exists (select 1 from public.characters c where c.id = m.character_a_id and c.status = 'active' and c.losses = 1)
    and exists (select 1 from public.characters c where c.id = m.character_b_id and c.status = 'active' and c.losses = 1)
  order by m.created_at desc limit 1;

  if final_a is not null and final_b is not null then
    stage := 'grand_final';
    eligible := array[final_a, final_b];
  else
    select count(*) into total from public.characters
    where status = 'active' and coalesce(losses, 0) = 0 and selected_for_tournament = true;
    if total >= 2 then
      stage := 'winners';
      select array_agg(id order by random()) into eligible from public.characters
      where status = 'active' and coalesce(losses, 0) = 0 and selected_for_tournament = true;
    else
      select count(*) into total from public.characters
      where status = 'active' and coalesce(losses, 0) = 1 and selected_for_tournament = true;
      if total >= 2 then
        stage := 'elimination';
        select array_agg(id order by random()) into eligible from public.characters
        where status = 'active' and coalesce(losses, 0) = 1 and selected_for_tournament = true;
      else
        select count(*) into total from public.characters
        where status = 'active' and coalesce(losses, 0) = 0 and selected_for_tournament = true;
        if total = 1 and exists (
          select 1 from public.characters where status = 'active' and coalesce(losses, 0) = 1 and selected_for_tournament = true
        ) then
          stage := 'grand_final';
          select array_agg(id order by losses desc, random()) into eligible from public.characters
          where status = 'active' and coalesce(losses, 0) <= 1 and selected_for_tournament = true;
        else
          return null;
        end if;
      end if;
    end if;
  end if;

  total := coalesce(array_length(eligible, 1), 0);
  if total < 2 then return null; end if;
  select coalesce(max(round_number), 0) + 1 into next_num from public.tournament_rounds;
  insert into public.tournament_rounds(round_number, bracket_stage, status, starts_at, tournament_id)
  values (next_num, stage, 'open', now(), current_tournament) returning id into new_round;

  while i < total loop
    first_character := eligible[i];
    second_character := eligible[i + 1];
    insert into public.matches(round_id, character_a_id, character_b_id, status, bracket_stage, closes_at, tournament_id)
    values (new_round, first_character, second_character, 'open', stage, now() + interval '3 days', current_tournament);
    i := i + 2;
  end loop;
  return new_round;
end;
$$;

revoke all on function public.auto_generate_round() from public, anon, authenticated;

-- Hourly server-side tick: close expired matches with a submitted story/result, then
-- create the next round only after the three-day round interval and all closures.
create or replace function public.tournament_clock_tick()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare expired record;
  current_tournament uuid;
begin
  select current_tournament_id into current_tournament from public.tournament_state where singleton = true;
  for expired in
    select id from public.matches
    where tournament_id = current_tournament and status <> 'closed' and closes_at is not null and closes_at <= now()
    order by closes_at
  loop
    begin
      perform public.finish_match_internal(expired.id);
    exception when others then
      -- A match with no submissions is intentionally left unresolved for an admin.
      -- Do not let one unresolved matchup prevent other expired matches being processed.
      null;
    end;
  end loop;

  if exists (select 1 from public.matches where tournament_id = current_tournament) then
    perform public.auto_generate_round();
  end if;
end;
$$;

revoke all on function public.tournament_clock_tick() from public, anon, authenticated;

-- Schedule the clock. If pg_cron is already enabled by the previous V7 migration,
-- this replaces that job; if not, enable pg_cron in Supabase and rerun this section.
create extension if not exists pg_cron with schema pg_catalog;
do $$
declare job record;
begin
  for job in select jobid from cron.job where jobname = 'infinite-tournament-auto-round' loop
    perform cron.unschedule(job.jobid);
  end loop;
  for job in select jobid from cron.job where jobname = 'infinite-tournament-clock' loop
    perform cron.unschedule(job.jobid);
  end loop;
  perform cron.schedule('infinite-tournament-clock', '0 * * * *', 'select public.tournament_clock_tick();');
end;
$$;

-- Verification:
-- select jobid, jobname, schedule, active from cron.job where jobname = 'infinite-tournament-clock';
-- select id, status, bracket_stage, closes_at, result_method, winner_character_id from public.matches order by created_at desc;

-- Safe reset: retain archived match rows (their FKs are permanent history),
-- but clear unarchived tournament activity so a fresh tournament can begin.
create or replace function public.admin_reset_tournament()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Administrator access required.';
  end if;

  delete from public.votes v
  where exists (
    select 1 from public.matches m
    where m.id = v.match_id
      and not exists (select 1 from public.canon_archive a where a.match_id = m.id)
  );

  delete from public.matches m
  where not exists (select 1 from public.canon_archive a where a.match_id = m.id);

  delete from public.tournament_rounds r
  where not exists (select 1 from public.matches m where m.round_id = r.id);

  update public.characters
  set losses = 0, status = 'active', selected_for_tournament = false
  where id is not null;

  update public.tournament_state
  set current_tournament_id = gen_random_uuid(), started_at = null, updated_at = now()
  where singleton = true;
end;
$$;

revoke all on function public.admin_reset_tournament() from public, anon;
grant execute on function public.admin_reset_tournament() to authenticated;
