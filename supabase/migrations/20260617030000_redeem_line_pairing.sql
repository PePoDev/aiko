-- Harden LINE pairing redemption.
--
-- Previously the app read `line_pairings` directly (an RLS policy let any
-- authenticated user SELECT live rows), which meant codes could be *enumerated*,
-- not just guessed. Replace that with a SECURITY DEFINER function so the table
-- is never client-readable: the app hands the function a code + its own refresh
-- token, and the function (running as owner) resolves the code, writes the link,
-- and consumes the pairing — all server-side under the caller's auth.uid().

create or replace function public.redeem_line_pairing(
  p_code text,
  p_refresh_token text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_line_user_id text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select line_user_id into v_line_user_id
  from public.line_pairings
  where code = p_code
    and expires_at > now();

  if v_line_user_id is null then
    return false; -- invalid or expired
  end if;

  insert into public.line_links (user_id, line_user_id, refresh_token, updated_at)
  values (auth.uid(), v_line_user_id, p_refresh_token, now())
  on conflict (line_user_id) do update
    set user_id = excluded.user_id,
        refresh_token = excluded.refresh_token,
        updated_at = now();

  -- Single-use: consume the code immediately.
  delete from public.line_pairings where line_user_id = v_line_user_id;

  return true;
end;
$$;

revoke all on function public.redeem_line_pairing(text, text) from public;
grant execute on function public.redeem_line_pairing(text, text) to authenticated;

-- The table is no longer client-readable; the webhook still uses the service
-- role (which bypasses RLS) to write codes.
drop policy if exists "line_pairings read pending" on public.line_pairings;
