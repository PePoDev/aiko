-- Aiko no longer gates AI behind a per-user consent flag. Acknowledgement now
-- happens once at signup/onboarding, so the column is dead. App code (domain,
-- DTO, Brick model, edge function) no longer reads or writes it.
alter table public.profiles
  drop column if exists ai_consent_enabled;
