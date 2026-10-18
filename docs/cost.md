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
| Listener has delivered a snapshot (from the cache or the server) | Local cache | No |
| Listener attached, no snapshot yet | Waits until 2 s after the listeners started (one deadline for all collections; no wait offline), then the cache | No |
| Cache empty and not confirmed by a listener (new device) | Waits for a listener that is still downloading, else the server for at most 3 s | Only when the listener hasn't answered, once |
| No shared listener (`attachments`, `integrations`) | Server; the cache offline | Yes |

The listener's initial snapshot and metadata-only events (write acknowledgements, cache→server confirmation) don't trigger provider reloads, because readers already loaded that data from the cache. Metadata-only events return no documents, so they aren't billed; they are how the sync banner knows changes are waiting ([Architecture → Sync status](architecture.md#sync-status)). An empty read never sends a second query for a collection its listener is still downloading, which would bill every document again, and after a server read times out, reads stay on the cache for a minute.

Firestore bills a listener for every document it returns. A listener that resumes within 30 minutes of the last one is billed only for documents that changed; after a longer gap, it is billed for every document in the collection again.

### What common actions cost

N = the user's transaction count. "Before" is the previous code, "after" is now.

| Action | Before | After |
| --- | --- | --- |
| Save or edit a transaction | ~2N + 2 × accounts reads, plus 1–2 writes | 1–2 writes plus ~2 listener reads |
| Delete a transaction | ~N + 2 × accounts reads, plus 1 delete and 1 write | 1 delete and 1 write, ~2 listener reads |
| Open the app within 30 minutes of last use | 95 (defaults check) + every document twice | Changed documents only (plus ~1 profile read) |
| Open the app after a longer gap | 95 + every document up to 3 times | Every document once |
| Sign in on a new device | 95 + every document up to 3 times | Up to 95 (defaults not cached yet, once per device) + every document once |
| Ask Aiko, one tool call | All transactions + accounts + categories, per call | Only the documents that tool needs, read once per message |

Example: a user with 2,000 transactions who logs 10 a day used ~40,000 reads a day before, close to the whole free daily quota for one person. Now it's about 20 writes and 20 reads.

### Other read and write rules in the code

- **Defaults once per device.** `ensureProfileAndDefaultsExist` looks up the 95 profile, category and group documents in the cache and asks the server only about cache misses (about 95 reads on a fresh device, none when cached); a brand-new account writes them without reading. `DefaultsSeedMarker` (`lib/features/auth/data/defaults_seed_marker.dart`) records per device and user that every default exists, and re-runs only when new defaults ship or a run couldn't tell (offline).
- **Balance reconciliation** writes only accounts whose balance changed. It runs only when both accounts and transactions are server-synced, so stale caches never cause corrective write churn.
- **Saves** write one document, or one batch for an operation that changes several (a transaction with its balances, an account with its adjustment, cascading deletes). Transaction saves update only the affected accounts. Nothing is read back after a write; lists update in memory.
- **Preferences** (`SyncedPreferences`) read the cache, then the device's copy, before the server. Itemized lists write only the items that changed.
- **Attachments.** A signed-in transaction detail screen keeps one listener on that transaction's attachments while it is open: 1 read when there are none, otherwise 1 per attachment. Editing a transaction runs one attachments query. Each attachment costs one Firestore write, after its upload. Files download once and then come from the on-device cache; copies of cloud files beyond 100 MB (30 MB on the web) are dropped oldest first and downloaded again when opened. Deleting transactions or an account queues one server query per 30 transactions (at least 1 read, plus 1 per attachment found) and one batched delete, so no files are left behind.
- **Account deletion** reads the profile once from the server to tell offline apart from other failures before calling the function.

## Cloud Functions

- `setGlobalOptions({maxInstances: 10})` in `firebase/functions/src/index.ts` caps scale-out; each instance handles up to 80 concurrent requests. Raise it deliberately if real traffic needs it.
- No minimum instances, so idle cost is zero.
- Ask Aiko tools (`FinanceReader` in `firebase/functions/src/finance_tools.ts`) read only what each tool needs. Date-ranged tools query only that range; recent transactions read only the newest rows; category names come from the referenced categories via `getAll`; account tools never read transactions. Everything is memoized for the length of one message. `firebase/test/finance_reads.test.cjs` asserts the document counts.
- Per-user rate limits stop runaway loops ([Backend](backend.md#functions)).
- Ask Aiko asks the AI provider once for a message that needs no tool; the tool round's reply is the answer. Each provider request times out after 60 s, the whole answer after 240 s, and a client that disconnects cancels the provider requests ([Backend → aikoChat](backend.md#aikochat)). The 15 s keep-alive comments cost no provider tokens. The app calls nothing for a guest (Ask Aiko, OCR, prices), and a price refresh stops at the first connection failure.
- `ocrScanner` receives receipts as base64 rather than an integer array (3–4 times smaller) and runs with 512 MiB, serving 4 requests per instance. `deleteAccount` deletes Firestore and Storage data in parallel within a 300 s timeout.
- CI deploys Functions with `--force`, which sets an Artifact Registry cleanup policy so old container images don't pile up ([Deployment](deployment.md#storage-and-functions)).

## Hosting

- `canvaskit/` (37 MB) is excluded from deploys (`firebase.json` → `hosting.ignore`). The app always loads CanvasKit from Google's CDN, so the files were never served; the service worker caches the variant the browser loads. If you build with `--no-web-resources-cdn`, remove that ignore entry.
- `pubspec.yaml` bundles only the SVG marks from `assets/icons/`, plus Noto Sans Thai (five weights, about 240 KB) and the Hanken Grotesk and Manrope weights the theme uses (four files, about 340 KB), so text renders offline. The launcher-icon sources (`app_icon.png`, `app_icon_padded.png`, 3.3 MB) stay out of every web, Android and iOS build.
- The renderer and the Firebase JS SDK come from Google's CDN, so that transfer doesn't count toward Hosting. Hosting serves compressed files; `main.dart.js` is about 1.5 MB gzipped.
- `Cache-Control: no-cache` makes browsers revalidate. Unchanged files return small `304` responses rather than full downloads. Bundled assets under `/assets/assets/` are cached for an hour (`max-age=3600`, `stale-while-revalidate=86400`), so repeat visits don't revalidate each font and image ([Deployment → Hosting configuration](deployment.md#hosting-configuration)).
- The service worker ([Architecture → Web offline loading](architecture.md#web-offline-loading)) registers after the first frame, so it never delays a start. On a first visit it also downloads the build files the page didn't load, about 15 MB uncompressed, mostly `pdfium.wasm` (5.2 MB) and the oversized `web/icons/Icon-192.png` (1.8 MB, worth shrinking). Later deploys download only files whose hash changed, and an online start of an unchanged build fetches no app files from Hosting.
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

- Read signed-in data through repositories and `OfflineStore`. Don't add listeners per widget or one-off `get()` calls; a screen-scoped listener (like the attachments one) must end with the screen.
- Adding a synced collection? Add it to `firebaseSyncProvider` so its reads become cache-first.
- Cloud Functions must query exactly what they need (filters, `limit`, `getAll`). Never read a whole user collection per call.
- Write only when a value changed, and batch related writes.
- Keep large binaries out of Firestore (use Storage) and out of bundled assets unless the app shows them.
- Update this page when you change any of the above.
