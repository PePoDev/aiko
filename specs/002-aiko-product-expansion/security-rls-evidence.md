# Security And RLS Evidence

Expansion persistence is covered by:

- `supabase/migrations/004_product_expansion_schema.sql`
- `supabase/migrations/005_product_expansion_rls.sql`
- `test/core/supabase/product_expansion_contract_test.dart`

The contract test verifies all roadmap tables are created and that the RLS migration enables row-level security with `auth.uid() = user_id` ownership policies.

Storage ownership for future receipt, document, backup, and export artifacts should follow the existing MVP storage pattern and receive feature-specific tests when binary storage is enabled.
