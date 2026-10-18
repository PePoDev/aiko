# Security and privacy

How Aiko protects financial data, what leaves the device, and the known limits. Treat the client as untrusted: every guarantee below is enforced by Security Rules or Cloud Functions, not by app code.

## Trust boundaries

```mermaid
flowchart LR
  D["Device<br/>(app, local SQLite stores, Firestore cache,<br/>secure storage)"] -->|ID token| R{"Security Rules"}
  R --> FS[("Firestore / Storage<br/>users/{uid}/…")]
  D -->|ID token| F["Cloud Functions"]
  F -->|Admin SDK, verified uid| FS
  F -->|snapshot, last messages, tool results| AI["AI provider"]
  L["LINE"] -->|HMAC-signed webhook| F
  D -->|currency codes only| FX["open.er-api.com"]
```

## Authentication

- Firebase Auth with email/password and Google. Web sessions persist in IndexedDB (`Persistence.LOCAL`); mobile uses the platform default.
- Callable functions and `aikoChat` verify the Firebase ID token and use its uid; request bodies never choose the owner.
- Account deletion requires a sign-in within the last 5 minutes.
- When a session ends, by Log out or elsewhere (token revoked, account deleted on another device), the app cancels every scheduled reminder (they name merchants and amounts), stops using that user's id as the local data owner and clears guest preferences left on the device ([Architecture](architecture.md#signing-out-and-switching-users)).
- Guests (**Continue without an account**) have no session: their records stay on the device under an anonymous `local:` owner, and nothing of theirs is sent to Firebase or the Functions until they sign in, when it is claimed into their account ([Architecture](architecture.md#guest-mode-and-sign-in)).

## Authorization

Summarized from [Backend → Security Rules](backend.md#security-rules):

- A user can only read and write `users/{their uid}/…`. Every finance document's `id` and `user_id` must match its path.
- Money fields must be decimal strings, which stops float values from slipping in.
- Default category clones keep their identity; only budget fields can change, and an empty `created_at` can be set once.
- Preferences hold only a string `value` or an `items` map.
- `integrations`, `line_links`, `line_pairings`, `rate_limits` and any unlisted path are server-only or denied.
- Storage: owner-only, 10 MiB maximum, image/PDF/text/Word content types only.

Rules are tested against the emulator on every push ([Testing](testing.md)).

## Secrets

| Secret | Where it lives |
| --- | --- |
| AI, LINE, OCR and market provider keys | Firebase Secret Manager (production), `firebase/functions/.secret.local` (local, gitignored) |
| CI deploy credentials | GitHub secret `FIREBASE_SERVICE_ACCOUNT`, a deploy-only service account with the minimal roles in [Deployment](deployment.md#2-ci-service-account) |
| Firebase web options, Google client IDs | Not secrets. Compiled into the app and stored as GitHub variables |

Never put a provider key, service-account JSON or Admin credential in a `--dart-define`, `.env` committed to git, or client code. `.env`, `.env.*` (except `.env.example`) and `.secret.local` are gitignored.

## Data on the device

| Data | Storage | Protection |
| --- | --- | --- |
| Signed-in finance data, including changes not uploaded yet | Firestore offline cache (IndexedDB on the web) | OS sandbox / browser origin isolation; not encrypted by the app |
| Guest and local-only finance data | `aiko_local.sqlite` (IndexedDB on the web). A database from an earlier version, `aiko_offline.sqlite`, is imported once and then deleted | Same |
| Attachment and avatar bytes, device attachment metadata, the upload queue | `aiko_files.sqlite` | Same |
| Last exchange rates, last price-refresh time, last LINE status | `meta` table of `aiko_local.sqlite` | Same; nothing personal beyond that time and flag |
| Owner ID, known-account and guest flags, capture settings, device copies of synced preferences, guest preferences, profile changes made on a stand-in, last sync time | `flutter_secure_storage` (Keychain / Android Keystore). On the web, values are encrypted with a key kept in the same browser, so treat that as obfuscation | |
| Captured bank SMS/notifications (Android) | App-support `capture_inbox/` files (only messages read as payments) and `capture_ledger.json` (type, amount, time and text hashes of the last 200, to spot repeats) | Inbox files deleted after booking |

Signing out clears the session but not the local caches. The Firestore cache with any unsent writes, and the user's queued file uploads, stay on the device and upload when that user signs in there again. Clearing app or site data removes everything on the device. On the web the app asks the browser to keep its storage (`navigator.storage.persist()`), so IndexedDB isn't evicted under storage pressure. The service worker (`web/aiko_sw.js`) caches only this site's build files and Google CDN files; it never handles API traffic (other hosts and non-GET requests go straight to the network) and never reads IndexedDB. There is no app lock yet ([Known gaps](features.md#known-gaps)).

## What leaves the device

| Destination | Data | When |
| --- | --- | --- |
| Firebase | Your records, files and preferences | Signed in; changes made offline upload once the device is back online |
| AI provider (via `aikoChat`) | System prompt, an aggregate financial snapshot (≤ 6,000 characters), the last 10 messages (≤ 1,000 characters each), and tool results computed from your data | Each Ask Aiko message, signed in only |
| LINE | Chat replies to your linked LINE account | Only after you pair LINE |
| OCR provider (via `ocrScanner`) | The receipt image (sent to the function as base64, to the provider as bytes) | When a signed-in user scans a receipt |
| Market provider (via `marketFeed`) | Ticker symbol and currency | When a signed-in user refreshes prices |
| `open.er-api.com` | One base currency code | Currency conversion in the transaction form, foreign-currency totals (Overview, Investments, Asset Allocation) and Travel Mode, also for guests and local-only builds |
| Google (`www.gstatic.com`, `fonts.gstatic.com`) | Standard web requests for the Flutter renderer (CanvasKit), the Firebase JS SDK and, in CDN builds, the engine's fallback fonts (Roboto, emoji). The app's own fonts are bundled. The service worker caches these files, so later starts don't fetch them again | Web app load: the first visit and each new build |

The snapshot is designed to send aggregates and a short recent slice, not the full ledger. Aiko answers carry the disclaimer *"Aiko provides estimates, not certified financial advice."*

## Abuse protection

- Per-user, per-minute rate limits on chat (30), LINE chat (30), pairing (5), OCR (10) and market prices (30).
- The LINE webhook verifies the `x-line-signature` HMAC with a constant-time comparison. Pairing codes are 6 characters from an unambiguous alphabet, stored only as SHA-256 hashes, expire after 10 minutes, and are consumed in a transaction.
- Provider proxies validate inputs (receipt images ≤ 5 MiB after decoding, ticker and currency patterns) and time out after 30 s.
- `aikoChat` allows any origin (CORS): the ID token, not the origin, authorizes a request. Errors reach the client as stable codes (`PROVIDER_DOWN`, `STREAM_FAILED`); provider details stay in the function logs.

## Account deletion

`deleteAccount` removes the user's LINE mapping, the entire `users/{uid}` Firestore subtree, all Storage objects under `users/{uid}/`, and the Auth user. It is immediate and permanent, with no grace period.

## Deployment exposure

- Preview channels are public, unlisted URLs that use the production Firebase project. Data stays protected by sign-in and Rules, but test with a test account.
- CI runs only on pushes, so forks never receive secrets.
- Emulator builds refuse non-`demo-` projects, and deploy builds never include `FIREBASE_EMULATOR_HOST`.

## Dependencies

`npm audit` is clean in the root and in `firebase/functions`. The `overrides` in the root `package.json` force patched versions of packages that the Firebase tooling pulls in. Remove an override once its parent package ships the fix itself.

- `firebase-tools` → `chokidar` ^4: firebase-tools still asks for chokidar 3, which needs `braces`, and no fixed `braces` release exists ([GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm)). chokidar 4 doesn't use `braces`. The emulators use it to reload rules and functions when files change. chokidar 4 treats ignore entries as plain paths, not globs, so a glob pattern added to `functions.ignore` in `firebase.json` would no longer stop a reload. This repo sets none; dotfiles, logs and `node_modules` are still skipped.

## Android permissions

`INTERNET`, `CAMERA` (receipts), `RECEIVE_SMS` and `READ_SMS` (opt-in auto-capture), notification-listener access (opt-in, granted in system settings), `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` and `RECEIVE_BOOT_COMPLETED` (reminders). iOS asks for camera and photo-library access for receipts.

Notification access goes to Aiko's own `CaptureNotificationListener`, which only the system can bind (`BIND_NOTIFICATION_LISTENER_SERVICE`). It passes the posting app, key, title and text to Dart inside Aiko's process and broadcasts nothing, so other apps can neither read notifications through Aiko nor inject fake bank notifications (the former `notification_listener_service` plugin broadcast them). The SMS receiver (`CaptureSmsReceiver`, which only senders holding `BROADCAST_SMS`, the system, can reach) is disabled until capture is turned on, and disabled again when it is turned off.
