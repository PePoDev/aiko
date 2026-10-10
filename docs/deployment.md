# Deployment: Vercel + Firebase

GitHub Actions builds the Flutter web app and publishes it to Vercel. The deployed app uses a real Firebase project for Auth, Firestore, Storage and Functions. Vercel only hosts the static build; its own Git builds are disabled in `vercel.json` because its build image has no Flutter.

| Push to | `.github/workflows/ci.yml` does |
| --- | --- |
| Any branch except `main` | Quality gates, plus a **Vercel preview** in parallel. The URL appears as a `Vercel (preview)` check (Details link) on the commit, branch and any pull request, and in the run summary. |
| `main` | Quality gates. If they pass: deploy Firebase rules/indexes, then the **Vercel production** site. |

Quality gates: `dart format`, `flutter analyze`, `flutter test`, Functions unit tests, and the rules/storage/functions emulator tests. Re-run any branch from **Actions → CI → Run workflow**. Previews deploy even when a gate fails, so you can see the change; production never does.

## One-time setup

### 1. Firebase project

1. In the [Firebase console](https://console.firebase.google.com), create a project, for example `aiko-prod`.
2. **Authentication → Get started:** enable **Email/Password** and **Google**.
3. **Firestore Database → Create database** in production mode. CI deploys `firebase/firestore.rules` and indexes.
4. **Project settings → General → Your apps → Add app → Web.** Copy `apiKey`, `appId`, `messagingSenderId`, `storageBucket`, `authDomain` and `projectId` for step 4.
5. **Authentication → Settings → Authorized domains:** add the Vercel production domain (`<project>.vercel.app`) and any custom domain. Google sign-in only works on listed domains. Preview URLs change per deployment, so use email/password on previews.
6. Optional, Blaze plan only: **Storage → Get started** (receipts, avatars) and Cloud Functions (Ask Aiko chat, account deletion, LINE, OCR, prices). See [Storage and Functions](#storage-and-functions).

### 2. CI service account

In [Cloud Shell](https://console.cloud.google.com/?cloudshell=true), create a deploy-only service account and key:

```sh
PROJECT=aiko-prod
SA=github-deploy@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts create github-deploy --project "$PROJECT"
for role in roles/firebaserules.admin roles/datastore.indexAdmin roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:$SA" --role "$role" --condition None
done
gcloud iam service-accounts keys create key.json --iam-account "$SA"
cat key.json   # paste into the FIREBASE_SERVICE_ACCOUNT secret, then: rm key.json
```

This covers rules and indexes. A failed deploy log names any missing permission; grant the role that contains it.

### 3. Vercel project

```sh
npx vercel@63.1.2 login
npx vercel@63.1.2 link       # create a new project, e.g. "aiko"
cat .vercel/project.json     # orgId → VERCEL_ORG_ID, projectId → VERCEL_PROJECT_ID
```

Create a token at **vercel.com → Account Settings → Tokens**, scoped to the same team.

### 4. GitHub settings

Add these under **Settings → Secrets and variables → Actions**, or with `gh secret set NAME` / `gh variable set NAME --body VALUE`:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `VERCEL_TOKEN` | Vercel token |
| Secret | `VERCEL_ORG_ID` | `orgId` from `.vercel/project.json` |
| Secret | `VERCEL_PROJECT_ID` | `projectId` from `.vercel/project.json` |
| Secret | `FIREBASE_SERVICE_ACCOUNT` | Contents of `key.json` |
| Variable | `FIREBASE_PROJECT_ID` | `projectId` |
| Variable | `FIREBASE_API_KEY` | `apiKey` |
| Variable | `FIREBASE_APP_ID` | `appId` |
| Variable | `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` |
| Variable | `FIREBASE_STORAGE_BUCKET` | `storageBucket` |
| Variable | `FIREBASE_AUTH_DOMAIN` | `authDomain` |
| Variable (optional) | `FIREBASE_REGION` | Functions region; default `us-central1` |
| Variable (optional) | `FIREBASE_DEPLOY_ONLY` | `firebase deploy --only` targets; default `firestore` |

The Firebase web options are public client configuration, so they are variables, not secrets. Without `FIREBASE_PROJECT_ID`, deploys still succeed in local-only mode (browser storage, no sign-in) with a warning, and the Firebase deploy job is skipped. Then push `main`, or run the workflow, to deploy.

## Storage and Functions

Both require the Blaze plan. Then:

1. **Storage → Get started** to create the default bucket.
2. Create every Functions secret. Use `local-unconfigured` for providers you do not use; they report "unavailable" instead of failing:

   ```sh
   for name in AI_API_KEY AI_MODEL AI_BASE_URL LINE_CHANNEL_SECRET LINE_CHANNEL_ACCESS_TOKEN \
       OCR_API_URL OCR_API_KEY MARKET_API_URL MARKET_API_KEY; do
     npx firebase functions:secrets:set "$name" --project aiko-prod
   done
   ```

3. Grant the service account `roles/firebasestorage.admin` for Storage rules. For Functions also grant `roles/cloudfunctions.admin`, `roles/iam.serviceAccountUser`, `roles/secretmanager.admin` and `roles/artifactregistry.admin`, then add more if the deploy log asks for them.
4. Set `FIREBASE_DEPLOY_ONLY` to `firestore,storage,functions`. Functions deploy in a separate `--force` call so CI can set the Artifact Registry cleanup policy and remove functions deleted from the `aiko` codebase. Rules and indexes deploy without `--force`, so indexes created in the console are kept.

## Notes

- Previews and production use the same Firebase project, so preview builds read and write real accounts. Use a test account on previews.
- Vercel protects preview URLs with Vercel Authentication by default; sign in to Vercel to open them, or change **Project → Settings → Deployment Protection**.
- Only pushes trigger CI, so pull requests from forks get no preview and never receive secrets.
- Mobile builds use the same `FIREBASE_*` defines (see [README](../README.md#getting-started)); this pipeline only ships the web app.
