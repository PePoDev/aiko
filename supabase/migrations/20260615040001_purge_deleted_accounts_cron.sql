-- Schedules the hourly purge of accounts whose 3-day deletion grace period has
-- elapsed. pg_cron invokes the `purge-deleted-accounts` Edge Function over HTTP
-- (pg_net), which uses the secret key to delete the auth user + cascade data.
--
-- The function URL and the shared cron auth secret are read from Vault so no
-- project-specific URL or secret is committed to git. Create them once per
-- project BEFORE (or after) this migration — the job tolerates their absence
-- and simply errors on each run until they exist:
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1', 'edge_base_url');
--   select vault.create_secret('<random-long-string>', 'purge_cron_secret');
--
-- The same `purge_cron_secret` must be set as the function secret PURGE_CRON_SECRET:
--   supabase secrets set PURGE_CRON_SECRET=<random-long-string>

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Idempotent: drop a previously scheduled job of the same name before re-adding.
select cron.unschedule('purge-deleted-accounts')
where exists (
  select 1 from cron.job where jobname = 'purge-deleted-accounts'
);

select cron.schedule(
  'purge-deleted-accounts',
  '0 * * * *', -- top of every hour
  $$
  select net.http_post(
    url := (
      select decrypted_secret from vault.decrypted_secrets
      where name = 'edge_base_url'
    ) || '/purge-deleted-accounts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret from vault.decrypted_secrets
        where name = 'purge_cron_secret'
      )
    ),
    body := '{}'::jsonb
  );
  $$
);
