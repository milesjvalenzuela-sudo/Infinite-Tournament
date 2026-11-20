-- Infinite Tournament: automatic round generation every 3 days
-- Run AFTER TOURNAMENT_MIGRATION.sql in Supabase SQL Editor.
-- The job checks hourly, but only creates a round when the previous round's
-- matches are all closed and at least 3 days have passed.

create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.auto_generate_round()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_round uuid;
  next_num integer;
  last_round_at timestamptz;
  stage text;
  eligible uuid[];
  first_character uuid;
  second_character uuid;
  total integer;
begin
  -- Never create a new round while any previous match still needs attention.
  if exists (
    select 1 from public.matches
    where status in ('open', 'writing', 'voting')
  ) then
    return null;
  end if;

  select created_at into last_round_at
  from public.tournament_rounds
  order by round_number desc nulls last, created_at desc
  limit 1;

  if last_round_at is not null and last_round_at > now() - interval '3 days' then
    return null;
  end if;

  -- Prefer the Winners Bracket while at least two undefeated characters remain.
  select count(*) into total from public.characters
  where status = 'active' and coalesce(losses, 0) = 0;
  if total >= 2 then
    stage := 'winners';
    select array_agg(id order by random()) into eligible
    from public.characters where status = 'active' and coalesce(losses, 0) = 0;
  else
    -- Once fewer than two undefeated characters remain, pair one-loss characters.
    select count(*) into total from public.characters
    where status = 'active' and coalesce(losses, 0) = 1;
    if total < 2 then
      return null;
    end if;
    stage := 'elimination';
    select array_agg(id order by random()) into eligible
    from public.characters where status = 'active' and coalesce(losses, 0) = 1;
  end if;

  if coalesce(array_length(eligible, 1), 0) < 2 then
    return null;
  end if;

  select coalesce(max(round_number), 0) + 1 into next_num
  from public.tournament_rounds;

  insert into public.tournament_rounds(round_number, bracket_stage, status, starts_at)
  values (next_num, stage, 'open', now())
  returning id into new_round;

  -- Pair randomly, preferring opponents these characters have not faced before.
  while coalesce(array_length(eligible, 1), 0) >= 2 loop
    first_character := eligible[1];

    select c.character_id into second_character
    from unnest(eligible) as c(character_id)
    where c.character_id <> first_character
      and not exists (
        select 1 from public.matches m
        where m.bracket_stage = stage
          and ((m.character_a_id = first_character and m.character_b_id = c.character_id)
            or (m.character_a_id = c.character_id and m.character_b_id = first_character))
      )
    order by random()
    limit 1;

    -- If every possible opponent is a rematch, choose a random available opponent.
    if second_character is null then
      select c.character_id into second_character
      from unnest(eligible) as c(character_id)
      where c.character_id <> first_character
      order by random()
      limit 1;
    end if;

    insert into public.matches(round_id, character_a_id, character_b_id, status, bracket_stage, closes_at)
    values (new_round, first_character, second_character, 'open', stage, now() + interval '3 days');

    eligible := array_remove(array_remove(eligible, first_character), second_character);
    second_character := null;
  end loop;

  -- If there is an odd number of eligible characters, the final character sits out.
  return new_round;
end;
$$;

revoke all on function public.auto_generate_round() from public, anon, authenticated;

-- Replace an earlier copy of this scheduled job, if one exists.
do $$
declare job record;
begin
  for job in select jobid from cron.job where jobname = 'infinite-tournament-auto-round' loop
    perform cron.unschedule(job.jobid);
  end loop;
  perform cron.schedule(
    'infinite-tournament-auto-round',
    '0 * * * *',
    'select public.auto_generate_round();'
  );
end;
$$;

-- Verify the scheduled job with:
-- select jobid, jobname, schedule, active from cron.job
-- where jobname = 'infinite-tournament-auto-round';
