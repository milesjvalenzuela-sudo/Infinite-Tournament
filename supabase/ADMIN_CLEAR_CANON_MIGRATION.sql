-- Infinite Tournament V10: Admin-only clear canon archive command
-- Run once in Supabase SQL Editor after the V8 tournament migration.
-- This deletes rows from canon_archive only. It deliberately preserves the
-- referenced matches, submissions, votes, characters, and writer accounts.

create or replace function public.admin_clear_canon()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  removed_count integer;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Administrator access required.';
  end if;

  delete from public.canon_archive;
  get diagnostics removed_count = row_count;
  return removed_count;
end;
$$;

revoke all on function public.admin_clear_canon() from public, anon;
grant execute on function public.admin_clear_canon() to authenticated;
