# Firebase cost

How Aiko keeps its Firebase bill small, what each user action costs, and the guardrails to set up. Review this page whenever you change how data is read, listened to, written, deployed or served.

## Where the cost comes from

| Product | Billed for | Free tier (Spark, also included in Blaze) |
| --- | --- | --- |
| Firestore | Document reads, writes and deletes; stored data and indexes | 50,000 reads, 20,000 writes and 20,000 deletes per day; 1 GiB stored |
| Hosting | Stored release files; data sent to browsers | 10 GB stored; 360 MB/day transferred |
| Cloud Functions (Blaze) | Invocations, compute time, outbound data; container images in Artifact Registry | 2 million invocations per month plus a compute allowance |
| Storage (Blaze) | Stored bytes, downloads, operations | Plan-dependent; see the pricing page |
| Authentication | Email/password and Google sign-in are free | — |
| AI provider | Tokens, billed by your provider, not Firebase | — |

Firestore reads are the meter most likely to grow with usage. Check current prices on the [Firebase pricing page](https://firebase.google.com/pricing).

## Firestore reads: cache first

All signed-in data lives under `users/{uid}`. `firebaseSyncProvider` (`lib/app/firebase_sync.dart`) keeps **one listener per collection**, and the SDK's local cache stays current while it runs. `FirestoreSyncState` (`lib/core/offline/firestore_sync_state.dart`) then routes repository reads:

| Situation | Read source | Billed |
| --- | --- | --- |
| Listener has synced with the server | Local cache | No |
| Listener attached but not synced yet | Waits up to 3 s for it, then the cache | No |
| Cache empty before the first sync (new device) | Server | Yes, once |
| No listener for the collection (attachments, `integrations`) | Server | Yes |

The listener's initial snapshot and metadata-only events (write acknowledgements, cache→server confirmation) don't trigger provider reloads, because readers already loaded that data from the cache.

Firestore bills a listener for every document it returns. A listener that resumes within 30 minutes of the last one is billed only for documents that changed; after a longer gap, it is billed for every document in the collection again.

### What common actions cost

N = the user's transaction count. "Before" is the previous code, "after" is now.

| Action | Before | After |
| --- | --- | --- |
| Save or edit a transaction | ~2N + 2 × accounts reads, plus 1–2 writes | 1–2 writes plus ~2 listener reads |
| Delete a transaction | ~N + 2 × accounts reads, plus 1 delete and 1 write | 1 delete and 1 write, ~2 listener reads |
| Open the app within 30 minutes of last use | 95 (defaults check) + every document twice | Changed documents only (plus ~1 profile read) |
| Open the app after a longer gap | 95 + every document up to 3 times | Every document once |
| Sign in on a new device | 95 + every document up to 3 times | 95 (defaults, once per device) + every document once |
| Ask Aiko, one tool call | All transactions + accounts + categories, per call | Only the documents that tool needs, read once per message |

Example: a user with 2,000 transactions who logs 10 a day used ~40,000 reads a day before, close to the whole free daily quota for one person. Now it's about 20 writes and 20 reads.

### Other read and write rules in the code

- **Defaults once per device.** `ensureProfileAndDefaultsExist` reads all 95 profile, category and group documents. `DefaultsSeedMarker` (`lib/features/auth/data/defaults_seed_marker.dart`) records per device and user that it ran, and re-runs only when new defaults ship.
- **Balance reconciliation** writes only accounts whose balance changed. It runs only when both accounts and transactions are server-synced, so stale caches never cause corrective write churn.
- **Saves** write one document. Transaction saves also update only the affected accounts.
- **Preferences** (`SyncedPreferences`) read through the same cache-first path.
- **Attachments** query only the opened transaction's metadata. Files download once and then come from the on-device cache.

## Cloud Functions

- `setGlobalOptions({maxInstances: 10})` in `firebase/functions/src/index.ts` caps scale-out; each instance handles up to 80 concurrent requests. Raise it deliberately if real traffic needs it.
- No minimum instances, so idle cost is zero.
- Ask Aiko tools (`FinanceReader` in `firebase/functions/src/finance_tools.ts`) read only what each tool needs. Date-ranged tools query only that range; recent transactions read only the newest rows; category names come from the referenced categories via `getAll`; account tools never read transactions. Everything is memoized for the length of one message. `firebase/test/finance_reads.test.cjs` asserts the document counts.
- Per-user rate limits stop runaway loops ([Backend](backend.md#functions)).
- CI deploys Functions with `--force`, which sets an Artifact Registry cleanup policy so old container images don't pile up ([Deployment](deployment.md#storage-and-functions)).

## Hosting

- `canvaskit/` (37 MB) is excluded from deploys (`firebase.json` → `hosting.ignore`). The app always loads CanvasKit from Google's CDN, so the files were never served. If you build with `--no-web-resources-cdn`, remove that ignore entry.
- `pubspec.yaml` bundles only the SVG marks from `assets/icons/`, plus Noto Sans Thai (five weights, about 240 KB) so Thai renders offline. The launcher-icon sources (`app_icon.png`, `app_icon_padded.png`, 3.3 MB) stay out of every web, Android and iOS build.
- The Latin fonts and the renderer come from Google's CDN, so that transfer doesn't count toward Hosting. Hosting serves compressed files; `main.dart.js` is about 1.5 MB gzipped.
- `Cache-Control: no-cache` makes browsers revalidate. Unchanged files return small `304` responses rather than full downloads.
- Preview channels expire after 7 days. Live releases are kept until you limit them, so set a retention limit (below).

## One-time guardrails

1. **Budget alert.** In Google Cloud Console → Billing → Budgets & alerts, create a budget for the project (for example $10/month) with email alerts at 50%, 90% and 100%. Do this before switching to Blaze.
2. **Release retention.** Firebase console → Hosting → your site's ⋮ menu → Release storage settings → keep about 10 releases.
3. **Co-locate.** Create Firestore in, or near, the Functions region (`us-central1` by default, for example `nam5`), or move both closer to your users. Functions reading Firestore across regions add latency and egress.
4. **Watch usage.** The Firebase console → Usage and billing shows reads, writes, Hosting transfer and function invocations per day.

## What still grows with data

- **Cold listener starts.** After 30 minutes away, each collection's listener re-reads every document. For very large ledgers, the next step is delta sync: listen for documents changed since the last sync (`updated_at`) and replace hard deletes with tombstones, so deletions still reach other devices. That changes the sync model; plan it with [Architecture](architecture.md#data-flow-and-sync).
- **Ask Aiko all-time questions.** A date range covering every month still reads every transaction in it.
- **Storage and Firestore data** grow with records and attachments. Account deletion removes all of a user's data.

## Cost checklist for changes

- Read signed-in data through repositories and `OfflineStore`. Don't add listeners per widget or one-off `get()` calls.
- Adding a synced collection? Add it to `firebaseSyncProvider` so its reads become cache-first.
- Cloud Functions must query exactly what they need (filters, `limit`, `getAll`). Never read a whole user collection per call.
- Write only when a value changed, and batch related writes.
- Keep large binaries out of Firestore (use Storage) and out of bundled assets unless the app shows them.
- Update this page when you change any of the above.
