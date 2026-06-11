## Project

Building a **personal finance app in Flutter**.

Backend decision:

```text
Supabase Cloud for Auth + Postgres only
No Supabase Storage
No Cloudflare R2
Use Riverpod
Use offline-first/local-first architecture
```

Main goals:

```text
Low backend cost
Good offline support
Fast app UX
Reduced Supabase vendor lock-in
Easy future migration/self-hosting
```

---

# Recommended Architecture

```text
Flutter UI
  ↓
Riverpod Providers / Notifiers
  ↓
Repository Interfaces
  ↓
Brick Repository
  ↓
SQLite local cache     Supabase Postgres
  ↓                    ↓
Offline-first app      Remote source of truth
```

For receipt/file handling:

```text
Receipt images
  ↓
Local device filesystem only
  ↓
Metadata stored in SQLite/Postgres
  ↓
No remote file upload in MVP
```

---

# Recommended Stack

| Purpose                  | Recommended Tool          |
| ------------------------ | ------------------------- |
| State management         | **Riverpod**              |
| Offline-first sync/cache | **Brick**                 |
| Local database           | **SQLite via Brick**      |
| Remote database          | **Supabase Postgres**     |
| Auth                     | **Supabase Auth**         |
| File storage             | **Local filesystem only** |
| Local path access        | `path_provider`           |
| Secret/key storage       | `flutter_secure_storage`  |
| Remote file storage      | **None for MVP**          |

---

# Why Brick

Brick is recommended because it gives a middle ground between custom sync and a managed sync service.

It can handle:

```text
Model mapping
Local SQLite cache
Supabase provider
Offline-first repository
Sync queue behavior
Local query subscriptions
```

This avoids writing a lot of custom code such as:

```text
manual sync_outbox table
manual retry queue
manual Supabase-to-SQLite mapper
manual repository cache logic
manual offline write handling
```

Brick should be used for structured app data:

```text
accounts
transactions
categories
budgets
goals
monthly_summary
category_monthly_summary
attachment metadata
```

Do **not** rely on Brick for actual receipt image upload because remote file storage is not being used.

---

# Supabase Usage

Use Supabase only for:

```text
Auth
Postgres
RLS
structured finance data
```

Do not use:

```text
Supabase Storage
Supabase Realtime by default
Edge Functions unless necessary
large file blobs in Postgres
```

Supabase Postgres is the remote source of truth.
SQLite is the app’s local-first read/write layer.

---

# Riverpod Usage

Riverpod should own dependency injection and app state.

Recommended flow:

```text
Screen
  ↓
Riverpod Notifier / AsyncNotifier
  ↓
Repository interface
  ↓
Brick implementation
```

Do not call Supabase directly from UI screens.

Bad:

```dart
final data = await Supabase.instance.client
  .from('transactions')
  .select();
```

Better:

```dart
final transactions =
    await ref.watch(transactionRepositoryProvider)
      .getTransactionsForMonth(month);
```

---

# Suggested Folder Structure

```text
lib/
  app/
    app.dart
    providers.dart

  core/
    result.dart
    errors.dart
    clock.dart

  features/
    auth/
      domain/
      data/
      presentation/

    transactions/
      domain/
        transaction_model.dart
        transaction_repository.dart
      data/
        brick_transaction_repository.dart
      presentation/
        transaction_list_screen.dart
        transaction_notifier.dart

    accounts/
      domain/
      data/
      presentation/

    categories/
      domain/
      data/
      presentation/

    budgets/
      domain/
      data/
      presentation/

    attachments/
      domain/
        attachment_model.dart
        attachment_repository.dart
      data/
        local_attachment_repository.dart
        noop_remote_attachment_storage.dart
      presentation/
        attachment_notifier.dart

    sync/
      sync_service.dart
      sync_notifier.dart
```

---

# Repository Interfaces

## Transaction Repository

```dart
abstract class TransactionRepository {
  Future<List<Transaction>> getTransactionsForMonth(DateTime month);

  Stream<List<Transaction>> watchTransactionsForMonth(DateTime month);

  Future<void> createTransaction(Transaction transaction);

  Future<void> updateTransaction(Transaction transaction);

  Future<void> deleteTransaction(String id);
}
```

## Attachment Repository

```dart
abstract class AttachmentRepository {
  Future<LocalAttachment> saveReceiptImage({
    required String transactionId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  });

  Future<void> deleteLocalFile(String localPath);

  Future<List<LocalAttachment>> getAttachments(String transactionId);
}
```

## Future Remote Storage Interface

Even though remote storage is not used now, define an interface so it can be added later without changing the UI.

```dart
abstract class RemoteAttachmentStorage {
  Future<String> upload({
    required String localPath,
    required String remotePath,
    required String contentType,
  });

  Future<void> delete(String remotePath);

  Future<String> getDownloadUrl(String remotePath);
}
```

For MVP:

```dart
class NoopRemoteAttachmentStorage implements RemoteAttachmentStorage {
  @override
  Future<String> upload({
    required String localPath,
    required String remotePath,
    required String contentType,
  }) {
    throw UnsupportedError('Remote attachment storage is disabled.');
  }

  @override
  Future<void> delete(String remotePath) async {}

  @override
  Future<String> getDownloadUrl(String remotePath) {
    throw UnsupportedError('Remote attachment storage is disabled.');
  }
}
```

---

# Riverpod Provider Example

```dart
final brickRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository();
});

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) {
  final brick = ref.watch(brickRepositoryProvider);
  return BrickTransactionRepository(brick);
});

final attachmentRepositoryProvider =
    Provider<AttachmentRepository>((ref) {
  return LocalAttachmentRepository();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final transactions = ref.watch(transactionRepositoryProvider);
  final attachments = ref.watch(attachmentRepositoryProvider);

  return SyncService(
    transactions: transactions,
    attachments: attachments,
  );
});
```

---

# Local-First Data Flow

## Reading Data

```text
App opens
  ↓
Read from local SQLite immediately
  ↓
Show UI quickly
  ↓
Sync with Supabase in background
  ↓
Update local SQLite
  ↓
UI updates through Riverpod/Brick stream
```

## Writing Data

```text
User adds transaction
  ↓
Save locally first
  ↓
UI updates immediately
  ↓
Brick syncs to Supabase Postgres
  ↓
Remote source of truth is updated
```

---

# Receipt / Attachment Strategy

No Supabase Storage.
No Cloudflare R2.

For MVP:

```text
Receipt image stays on device
Only metadata syncs to Supabase Postgres
```

Suggested table:

```sql
create table transaction_attachments (
  id uuid primary key,
  user_id uuid not null,
  transaction_id uuid not null,
  local_path text,
  remote_path text,
  file_name text,
  mime_type text,
  file_size_bytes bigint,
  checksum text,
  sync_status text not null default 'local_only',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
```

For MVP:

```text
remote_path = null
sync_status = local_only
```

Important limitation:

```text
Receipt images will not sync across devices yet.
Only receipt metadata syncs.
```

This is acceptable for MVP if the priority is low cost and avoiding file storage services.

---

# Do Not Store Images in Postgres

Avoid this:

```text
receipt image bytes → Postgres bytea
```

Reason:

```text
Increases database size
Makes backups heavier
Increases bandwidth
Makes database harder to maintain
Not ideal for large binary files
```

Postgres should store only:

```text
file metadata
local path
remote path if added later
checksum
file size
upload status
transaction relationship
```

---

# Suggested Database Design

Core tables:

```text
profiles
accounts
transactions
categories
budgets
goals
transaction_attachments
```

Summary/report tables:

```text
daily_summary
monthly_summary
category_monthly_summary
budget_progress
account_balance_snapshot
net_worth_snapshot
```

Use summary tables for dashboard/report screens instead of repeatedly querying raw transactions.

---

# Sync Fields

Every syncable table should include:

```sql
id uuid primary key,
user_id uuid not null,
created_at timestamptz not null default now(),
updated_at timestamptz not null default now(),
deleted_at timestamptz,
version integer not null default 1
```

Use soft delete:

```sql
deleted_at timestamptz
```

This makes offline delete sync much safer.

---

# Conflict Strategy

For MVP:

```text
latest updated_at wins
```

For important records:

```text
compare version number
```

Recommended conflict rules:

```text
Transactions: latest updated_at wins
Budgets: latest updated_at wins
Categories: latest updated_at wins
Summaries: recalculated from transactions
Account balances: calculated or snapshot-based
Attachments: local file wins locally, metadata syncs remotely
```

---

# Security

Use Supabase RLS for all user-owned tables.

Example:

```sql
alter table transactions enable row level security;

create policy "Users can access own transactions"
on transactions
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

Never expose the Supabase service role key inside Flutter.

Flutter should only use:

```text
Supabase anon key
user session token
```

Use `flutter_secure_storage` for:

```text
Supabase session token if needed
local encryption key
biometric unlock flag
sensitive app settings
```

Do not use `flutter_secure_storage` for all finance records.

---

# Cost Strategy

This architecture reduces Supabase cost because:

```text
Most reads happen from local SQLite
Dashboard reads local summary tables
Writes are batched/synced
No Supabase Storage cost
No Cloudflare R2 cost
No Realtime by default
Less database egress
Less repeated querying
```

Avoid expensive patterns:

```text
Loading all transactions from Supabase every time
Using Realtime for every user/session
Uploading receipt images to database
Using Edge Functions for simple CRUD
Calling Supabase directly from every screen
```

---

# Vendor Lock-in Strategy

Supabase is not hard lock-in because the main database is Postgres.

To reduce soft lock-in:

```text
Keep schema standard Postgres
Use repository interfaces
Do not call Supabase directly from UI
Avoid Supabase Storage
Avoid Supabase Realtime unless necessary
Keep business logic in Dart/domain layer where possible
Make file storage replaceable through an interface
```

Future migration path:

```text
Supabase Cloud
  ↓
Self-hosted Supabase
  ↓
Custom Postgres backend if needed
```

---

# Final Recommendation

Use:

```text
Flutter
+ Riverpod
+ Brick
+ SQLite local cache
+ Supabase Auth
+ Supabase Postgres
+ RLS
+ local-only receipt storage
```

Do not use:

```text
Supabase Storage
Cloudflare R2
Realtime by default
Postgres bytea for receipt images
direct Supabase calls inside UI screens
```

Best final design:

```text
Flutter UI
  ↓
Riverpod
  ↓
Repository interfaces
  ↓
Brick
  ↓
SQLite local-first cache
  ↓
Supabase Postgres sync

Receipts:
local filesystem only
metadata synced through Postgres
actual image remains on device
```

This gives the app:

```text
Low cost
Offline support
Fast UI
Good Supabase compatibility
Reduced vendor lock-in
A clean path to add remote file storage later
```
