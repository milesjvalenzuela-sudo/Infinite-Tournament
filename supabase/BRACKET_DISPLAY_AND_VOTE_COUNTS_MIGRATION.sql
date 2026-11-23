-- V11: expose aggregate vote counts without exposing voter identities or hashes.
-- Run once in Supabase SQL Editor after the V10 migrations.
create or replace function public.get_match_vote_counts(p_match_id uuid)
returns table(submission_id uuid, vote_count bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select v.submission_id, count(*)::bigint
  from public.votes v
  join public.submissions s on s.id = v.submission_id
  join public.matches m on m.id = v.match_id
  where v.match_id = p_match_id
    and s.match_id = p_match_id
    and s.status = 'published'
    and m.status in ('scheduled','open','writing','voting','closed')
  group by v.submission_id;
$$;
revoke all on function public.get_match_vote_counts(uuid) from public;
grant execute on function public.get_match_vote_counts(uuid) to anon, authenticated;
