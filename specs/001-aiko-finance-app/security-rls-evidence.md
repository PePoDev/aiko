# RLS And Storage Evidence

Validation date: 2026-05-18

Evidence reviewed:

- `supabase/migrations/001_initial_mvp_schema.sql` creates the MVP user-owned tables.
- `supabase/migrations/002_initial_mvp_rls.sql` enables RLS and user ownership policies.
- `supabase/migrations/003_storage_buckets_and_policies.sql` creates receipt, document, and export buckets with authenticated user path checks.
- `test/core/supabase/supabase_contract_test.dart` verifies migrations include RLS and storage ownership policy coverage.

Local result:

- `flutter test` passed the migration/RLS contract check.

Pending release evidence:

- Run `npx supabase db reset` against a local Supabase stack.
- Attempt cross-user table reads/writes and cross-user storage path reads/writes.
- Attach SQL/log evidence before production release.
