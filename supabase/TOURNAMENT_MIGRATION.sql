-- Infinite Tournament v2 compatibility + secure RPCs
-- Run this in Supabase SQL Editor. It is designed to be re-runnable.
-- It preserves existing data and adds any columns expected by the website.

create extension if not exists pgcrypto;

-- Ensure core columns expected by the application exist.
alter table public.characters
  add column if not exists owner_id uuid references public.profiles(id) on delete cascade,
  add column if not exists name text,
  add column if not exists universe text,
  add column if not exists description text,
  add column if not exists abilities text,
  add column if not exists image_url text,
  add column if not exists status text default 'active',
  add column if not exists losses integer default 0,
  add column if not exists created_at timestamptz default now();

alter table public.tournament_rounds
  add column if not exists round_number integer,
  add column if not exists bracket_stage text default 'winners',
  add column if not exists status text default 'open',
  add column if not exists starts_at timestamptz default now(),
  add column if not exists ends_at timestamptz,
  add column if not exists created_at timestamptz default now();

alter table public.matches
  add column if not exists round_id uuid references public.tournament_rounds(id) on delete set null,
  add column if not exists character_a_id uuid references public.characters(id) on delete cascade,
  add column if not exists character_b_id uuid references public.characters(id) on delete cascade,
  add column if not exists status text default 'open',
  add column if not exists winner_submission_id uuid,
  add column if not exists winner_character_id uuid references public.characters(id) on delete set null,
  add column if not exists bracket_stage text default 'winners',
  add column if not exists created_at timestamptz default now(),
  add column if not exists closes_at timestamptz;

alter table public.submissions
  add column if not exists match_id uuid references public.matches(id) on delete cascade,
  add column if not exists character_id uuid references public.characters(id) on delete cascade,
  add column if not exists writer_id uuid references public.profiles(id) on delete cascade,
  add column if not exists content text,
  add column if not exists status text default 'published',
  add column if not exists created_at timestamptz default now();

alter table public.votes
  add column if not exists match_id uuid references public.matches(id) on delete cascade,
  add column if not exists submission_id uuid references public.submissions(id) on delete cascade,
  add column if not exists voter_hash text,
  add column if not exists created_at timestamptz default now();

alter table public.canon_archive
  add column if not exists match_id uuid references public.matches(id) on delete set null,
  add column if not exists submission_id uuid references public.submissions(id) on delete set null,
  add column if not exists character_id uuid references public.characters(id) on delete set null,
  add column if not exists title text,
  add column if not exists story_text text,
  add column if not exists created_at timestamptz default now();

create index if not exists characters_owner_idx on public.characters(owner_id);
create index if not exists matches_status_idx on public.matches(status);
create index if not exists matches_round_idx on public.matches(round_id);
create index if not exists submissions_match_idx on public.submissions(match_id);
create index if not exists votes_match_idx on public.votes(match_id);
create index if not exists canon_archive_date_idx on public.canon_archive(created_at desc);

-- RLS remains enabled. Public SELECT policies from the initial setup are retained.
-- These SECURITY DEFINER functions perform writes only after checking the caller.

create or replace function public.register_character(
  p_name text, p_universe text, p_description text, p_abilities text, p_image_url text default null
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'Please sign in first.'; end if;
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'Character name must be at least 2 characters.'; end if;
  if length(trim(coalesce(p_description,''))) < 10 then raise exception 'Please provide a longer character description.'; end if;
  insert into public.characters(owner_id,name,universe,description,abilities,image_url,status,losses)
  values(auth.uid(),trim(p_name),nullif(trim(coalesce(p_universe,'')),''),trim(p_description),nullif(trim(coalesce(p_abilities,'')),''),p_image_url,'active',0)
  returning id into new_id;
  return new_id;
end; $$;

create or replace function public.submit_match_story(p_match_id uuid,p_character_id uuid,p_content text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare new_id uuid; match_row public.matches%rowtype;
begin
  if auth.uid() is null then raise exception 'Please sign in first.'; end if;
  select * into match_row from public.matches where id=p_match_id;
  if not found then raise exception 'Match not found.'; end if;
  if match_row.status not in ('open','writing') then raise exception 'This matchup is not accepting submissions.'; end if;
  if p_character_id not in (match_row.character_a_id,match_row.character_b_id) then raise exception 'Choose one of the characters in this matchup.'; end if;
  if not exists(select 1 from public.characters where id=p_character_id and owner_id=auth.uid()) then
    raise exception 'You can only submit a story for a character you own.';
  end if;
  if length(trim(coalesce(p_content,''))) < 100 then raise exception 'Your battle story must be at least 100 characters.'; end if;
  if exists(select 1 from public.submissions where match_id=p_match_id and character_id=p_character_id) then
    raise exception 'A story has already been submitted for this character.';
  end if;
  insert into public.submissions(match_id,character_id,writer_id,content,status)
  values(p_match_id,p_character_id,auth.uid(),trim(p_content),'published') returning id into new_id;
  if (select count(*) from public.submissions where match_id=p_match_id and status='published') >= 2 then
    update public.matches set status='voting' where id=p_match_id;
  end if;
  return new_id;
end; $$;

create or replace function public.cast_public_vote(p_match_id uuid,p_submission_id uuid,p_voter_hash text)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if length(coalesce(p_voter_hash,'')) < 16 then raise exception 'Invalid voter token.'; end if;
  if not exists(select 1 from public.submissions where id=p_submission_id and match_id=p_match_id and status='published') then
    raise exception 'That story is not available for this vote.';
  end if;
  if not exists(select 1 from public.matches where id=p_match_id and status='voting') then
    raise exception 'Voting is not open for this matchup.';
  end if;
  if exists(select 1 from public.votes where match_id=p_match_id and voter_hash=p_voter_hash) then
    raise exception 'You have already voted in this matchup.';
  end if;
  insert into public.votes(match_id,submission_id,voter_hash) values(p_match_id,p_submission_id,p_voter_hash);
end; $$;

create or replace function public.admin_generate_round(p_bracket_stage text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare new_round uuid; next_num integer; eligible uuid[]; i integer; total integer;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='admin') then raise exception 'Administrator access required.'; end if;
  if p_bracket_stage not in ('winners','elimination','grand_final') then raise exception 'Invalid bracket stage.'; end if;
  select coalesce(max(round_number),0)+1 into next_num from public.tournament_rounds;
  insert into public.tournament_rounds(round_number,bracket_stage,status,starts_at)
  values(next_num,p_bracket_stage,'open',now()) returning id into new_round;
  if p_bracket_stage='winners' then
    select array_agg(id order by random()) into eligible from public.characters where status='active' and coalesce(losses,0)=0;
  elsif p_bracket_stage='elimination' then
    select array_agg(id order by random()) into eligible from public.characters where status='active' and coalesce(losses,0)=1;
  else
    select array_agg(id order by random()) into eligible from public.characters where status='active' and coalesce(losses,0)<=1;
  end if;
  total:=coalesce(array_length(eligible,1),0);
  if total<2 then raise exception 'Not enough eligible characters to create this round.'; end if;
  i:=1;
  while i<total loop
    insert into public.matches(round_id,character_a_id,character_b_id,status,bracket_stage,closes_at)
    values(new_round,eligible[i],eligible[i+1],'open',p_bracket_stage,now()+interval '3 days');
    i:=i+2;
  end loop;
  return new_round;
end; $$;

create or replace function public.admin_close_match(p_match_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare m public.matches%rowtype; winning_submission uuid; winning_character uuid; winning_votes integer; losing_character uuid;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='admin') then raise exception 'Administrator access required.'; end if;
  select * into m from public.matches where id=p_match_id for update;
  if not found then raise exception 'Match not found.'; end if;
  select s.id,s.character_id,count(v.id) into winning_submission,winning_character,winning_votes
  from public.submissions s left join public.votes v on v.submission_id=s.id
  where s.match_id=p_match_id and s.status='published'
  group by s.id,s.character_id order by count(v.id) desc,s.created_at asc limit 1;
  if winning_submission is null then raise exception 'No published stories exist for this match.'; end if;
  losing_character:=case when winning_character=m.character_a_id then m.character_b_id else m.character_a_id end;
  update public.matches set status='closed',winner_submission_id=winning_submission,winner_character_id=winning_character where id=p_match_id;
  update public.characters set losses=coalesce(losses,0)+1,status=case when coalesce(losses,0)+1>=2 then 'eliminated' else 'active' end where id=losing_character;
  insert into public.canon_archive(match_id,submission_id,character_id,title,story_text)
  select p_match_id,winning_submission,winning_character,
    (select name from public.characters where id=winning_character)||' wins',
    content from public.submissions where id=winning_submission;
end; $$;

grant execute on function public.register_character(text,text,text,text,text) to authenticated;
grant execute on function public.submit_match_story(uuid,uuid,text) to authenticated;
grant execute on function public.cast_public_vote(uuid,uuid,text) to anon, authenticated;
grant execute on function public.admin_generate_round(text) to authenticated;
grant execute on function public.admin_close_match(uuid) to authenticated;

-- IMPORTANT: After creating your own account, promote your profile once:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='YOUR_EMAIL_ADDRESS');
