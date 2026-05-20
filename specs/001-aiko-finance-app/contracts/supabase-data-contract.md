# Contract: Supabase Data And Security

## Purpose

Define the backend contract the Flutter app expects from Supabase Cloud.

## Environments

- **Local development**: Supabase CLI stack for development and automated contract checks.
- **Supabase Cloud project**: Managed Supabase deployment with HTTPS, stable public API URL, managed secrets, backups, logs, and monitoring.

The local CLI stack must not be treated as production hosting.

## Authentication Contract

- Mobile app authenticates through Supabase Auth.
- Authenticated user identity is the ownership boundary for user-owned data.
- The mobile app may use the public anon key.
- The mobile app must never include service-role credentials.
- Password reset, email confirmation, and deep-link redirects must be configured for both Android and iOS.
- App lock is a client-side protection layer and does not replace backend authentication.

## Row-Level Security Contract

Every user-owned table must enforce:

- Users can select only records where the record owner matches the authenticated user.
- Users can insert only records owned by themselves.
- Users can update only records owned by themselves.
- Users can delete, archive, or soft-delete only records owned by themselves.

Shared family/business access is not part of MVP. Future sharing requires explicit membership and role tables.

## Table Groups

### MVP Required Tables

- `profiles`
- `accounts`
- `categories`
- `transactions`
- `transaction_splits`
- `transaction_rules`
- `budgets`
- `goals`
- `saving_plans`
- `dashboard_widget_preferences`
- `aiko_insights`
- `saved_calculator_scenarios`
- `reports`
- `attachments`
- `notification_preferences`

### Roadmap Tables

- `bills_subscriptions`
- `credit_card_details`
- `assets`
- `liabilities`
- `investment_holdings`
- `tax_records`

## Storage Contract

Storage buckets:

- `receipts`: transaction receipt images and PDFs.
- `documents`: tax, account, and report documents.
- `exports`: generated user exports, if exports are stored before sharing.

Storage rules:

- Object paths must include the authenticated user identity or another policy-enforceable owner segment.
- Users can read, write, and delete only their own files.
- File metadata must be represented in `attachments`.
- Maximum file size and allowed content types must be enforced before upload and in storage policy where possible.

## Realtime Contract

Realtime is optional for MVP screens. If enabled:

- Subscribe only to user-owned tables.
- Use subscriptions to refresh dashboard summaries, transactions, insights, and notifications.
- Always handle disconnected, reconnecting, and stale-data states.

## Data Access Contract

Repository methods in Flutter should expose feature-specific operations rather than raw table access:

- Auth: sign up, sign in, sign out, current session, reset password.
- Profile: load/update profile, onboarding status, theme and AI consent.
- Accounts: create/update/archive/list accounts and calculate balance summaries.
- Transactions: create/update/archive/search/filter/split/duplicate/list transactions.
- Categories: create/update/archive/merge/list categories.
- Rules: preview/apply/create/update/archive transaction rules.
- Budgets: create/update/archive/list budgets and budget progress.
- Goals: create/update/pause/complete/archive/list goals and saving plans.
- Insights: list/view/dismiss/rate/apply Aiko insights.
- Reports: generate monthly summary, generate Aiko Review, export selected data.
- Calculators: save/list/delete scenarios and convert scenario to draft plan.

## Error Contract

Backend and repository errors must map to user-facing states:

- Not authenticated.
- Permission denied.
- Network unavailable.
- Server unavailable.
- Validation failed.
- Conflict or stale update.
- File too large or unsupported.
- Unknown error with retry option.

Raw backend messages should not expose secrets, SQL details, tokens, or service topology.

## Migration Contract

- Schema changes are represented as ordered migrations under `supabase/migrations/`.
- Seed data under `supabase/seed.sql` supports local development and tests.
- Every new user-owned table includes RLS enablement and policies in the same migration.
- Destructive migrations require a backup/restore note and test data migration plan.
