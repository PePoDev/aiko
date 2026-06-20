-- Adds an optional reminder timestamp to transactions. The client schedules a
-- local notification at this time; storing it lets the reminder round-trip and
-- survive a reinstall / multi-device sync. Nullable, no default = no reminder.
alter table public.transactions
  add column if not exists reminder_at timestamptz;
