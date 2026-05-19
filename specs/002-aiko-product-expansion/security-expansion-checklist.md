# Security Expansion Checklist

- [x] Expansion tables are user-owned with `user_id` references.
- [x] Expansion RLS migration enables row-level security on every new roadmap table.
- [x] Policies use `auth.uid() = user_id` for user-owned access.
- [x] Import/export flows expose sensitivity acknowledgement for broad or tax data exports.
- [x] Tax, investment, optimization, and prediction features use estimate/disclaimer-oriented copy.
- [x] Device sessions include trusted/revoked states for remote sign-out flows.
- [x] Backup snapshots include checksum-ready state before restore.
- [x] Cloud setup uses Supabase anon keys only in the mobile app; service-role keys remain server-side only.

Provider integrations, OCR, bank feeds, investment prices, and tax software exports must receive separate credential and storage reviews before production enablement.
