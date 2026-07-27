# Per-User Default Category Clones

**Date:** 2026-07-26  
**Status:** Approved design

## Goal

Make built-in categories valid foreign-key targets while keeping their budgets
and group budgets private to each user. Eliminate the fixed-ID collision that
currently makes a user's Coffee budget attempt to overwrite the global Coffee
row and retry forever in Brick's offline queue.

## Root Cause

The app currently treats a user-owned row with a built-in category's fixed ID as
a budget overlay. PostgreSQL permits only one row for that primary key. Once the
fixed ID belongs to a global category (`user_id = NULL`), a user overlay cannot
be inserted or updated. The reported payload first fails because it explicitly
sends `created_at = NULL`; supplying a timestamp then exposes the underlying RLS
failure because users cannot update global rows.

Category groups use the same fixed-ID overlay pattern and have the same
multi-user collision. The clone design must therefore cover categories and
groups together.

## Data Model

Keep the 81 categories and 13 groups with their existing fixed IDs as immutable
global templates. Global templates have `user_id = NULL`.

Add `template_id` to both tables:

- A global template has `template_id = NULL`.
- A per-user clone has `user_id = <owner>` and `template_id` pointing to its
  global template.
- A custom category or group has a user ID and no template ID.

Each user receives one clone of every global template. Enforce this with unique
constraints on `(user_id, template_id)` where `template_id IS NOT NULL`.
Category clones reference that user's group clones through `group_id`.

Clone IDs are UUIDv5 values generated from namespace
`ee336da0-4337-4fa0-b100-ec0dddcb5b95` and one of these exact names:

- `group:<user-id>:<group-template-id>`
- `category:<user-id>:<category-template-id>`

Postgres and Dart use the same namespace and names so online account setup,
offline references, retries, and multi-device creation converge on one row.

## Account Setup And Backfill

Creating a profile creates all 13 group clones first, followed by all 81
category clones. Existing profiles are backfilled by the migration.

The migration preserves existing per-user category and group budget values. It
turns rows that currently occupy fixed template IDs into global templates,
copies their user-owned budget data to the corresponding clone, and then clears
user-specific budget values from the templates.

Existing transactions whose `category_id` is a template ID are remapped to the
owning user's deterministic category clone. Custom-category references do not
change.

## Application Behavior

Brick models and domain models expose `templateId` for categories and groups.
A row is built-in/read-only when it has a template ID; in-memory anonymous
templates are also recognized by their fixed IDs. Custom rows remain editable.

Authenticated category and group providers load the user's clones and custom
rows. Missing clones are derived in memory with deterministic IDs so the app can
remain useful before a remote refresh completes. Budget saves update the clone
directly; no overlay merge is needed.

A legacy local row that combines a fixed template ID with a user ID is
normalized to the deterministic clone identity when read. Once the real clone
has been fetched, the provider ignores the legacy row. It is not deleted through
Brick because that would enqueue a delete against the global template.

Before authentication, in-memory defaults continue to use template IDs. During
anonymous-data claiming, transactions that reference a template ID are remapped
to the authenticated user's deterministic clone ID before they are queued for
Supabase. This keeps signed-out capture compatible with the clone model.

## Legacy Queue Recovery

Database compatibility triggers handle writes from the current app version and
already-persisted Brick jobs:

- A category or group insert that combines a global template ID with a user ID
  is rewritten to the deterministic clone ID, receives the matching
  `template_id`, and fills a missing `created_at`.
- A transaction write that references a global category template is rewritten
  to the authenticated user's clone ID.

The triggers run with invoker permissions. Existing RLS ownership checks remain
in force; they must not provide a path to write another user's clone or mutate a
global template. This compatibility behavior allows queued category job `14` to
complete without clearing app data.

## RLS And Integrity

- Authenticated users may select global templates and their own rows.
- Only service-side account setup may create or change global templates.
- Users may insert, update, and delete only rows whose `user_id = auth.uid()`.
- Clone `template_id` values reference global rows of the same table.
- Category clone `group_id` values reference group clones owned by the same
  user; migration and account setup enforce this invariant.
- Transactions continue to reference `categories(id)` and therefore resolve to
  user-owned clone rows after remapping.

## Error Handling

Clone creation and backfill are idempotent. Re-running account setup uses the
deterministic ID and `(user_id, template_id)` uniqueness to avoid duplicates.
Compatibility rewrites run only when the submitted ID identifies an existing
global template. Other IDs follow normal custom-row semantics, including RLS
and foreign-key validation.

The app continues to save locally first. A failed remote write remains queued,
but valid cloned-default writes no longer fail because of null timestamps,
global primary-key conflicts, or global-row RLS.

## Testing

- Assert exactly 13 group clones and 81 category clones per profile.
- Assert two users receive different clone IDs for every shared template.
- Assert clone IDs match between PostgreSQL UUIDv5 and Dart UUIDv5 generation.
- Assert every category clone points to the same user's cloned group.
- Assert global templates remain ownerless and budget-free.
- Assert RLS prevents cross-user clone access and global template mutation.
- Replay the reported Coffee payload and assert it updates the user's clone.
- Assert legacy transaction template IDs are remapped to clone IDs.
- Assert existing transaction and budget data survives the backfill.
- Test authenticated provider/repository behavior and anonymous-data claiming.
- Run pgTAP tests, targeted Flutter tests, the full Flutter suite, formatting,
  `flutter analyze`, and an original queued-request replay.

## Considered Alternatives

- **Dedicated budget override table:** normalized and smaller, but rejected in
  favor of complete per-user category ownership.
- **Create clones on first use:** fewer rows, but adds offline and multi-device
  races. Creating all clones during account setup was selected.
- **Profile JSON:** fewer tables, but weak referential integrity and poor
  conflict behavior.
