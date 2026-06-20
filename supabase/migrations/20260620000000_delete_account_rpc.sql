-- Immediate account deletion via a single SECURITY DEFINER RPC.
-- Replaces the old 3-day grace-period scheme (delete-account /
-- purge-deleted-accounts Edge Functions + hourly pg_cron). The app calls
-- `select delete_account()` under the user's JWT, then signs out.
--
-- Deleting the auth.users login needs RLS-bypassing privileges, so the
-- function runs as its definer (the migration role) rather than the caller.
-- It deletes the caller's profile row (cascades all finance data via
-- `on delete cascade`) and their auth.users login. `profiles.id` is NOT FK'd
-- to auth.users, so the profile must be deleted explicitly.

-- 1) Tear down the old grace-period machinery.
select cron.unschedule('purge-deleted-accounts')
where exists (select 1 from cron.job where jobname = 'purge-deleted-accounts');

drop index if exists public.profiles_deletion_scheduled_at_idx;
alter table public.profiles drop column if exists deletion_scheduled_at;

-- 2) The one function that does the job.
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  delete from public.profiles where id = uid;  -- cascades finance data
  delete from auth.users where id = uid;       -- removes the login
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
