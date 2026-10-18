# Aiko documentation

Start with the project [README](../README.md) for the product, brand, rules and design system. These pages document how the code works today.

| Page | Read it to… |
| --- | --- |
| [Getting started](getting-started.md) | Set up a machine, run the app in each mode, look up configuration, fix common problems |
| [Architecture](architecture.md) | Understand layers, startup, routes, providers, offline sync, guest mode, web offline loading and platform differences |
| [Features](features.md) | See what each module does, where it lives, and the known gaps |
| [Data model](data-model.md) | Look up every Firestore document, local record store table, preference key, device-only value and Storage path |
| [Calculations](calculations.md) | Check the exact formula behind a number on screen |
| [Backend](backend.md) | Use or change the Cloud Functions API, the AI chat pipeline and Security Rules |
| [Security and privacy](security.md) | Know the trust boundaries, secrets, on-device data and what leaves the device |
| [Testing](testing.md) | Run the suites, see what they cover, write new tests |
| [Deployment](deployment.md) | Set up Firebase Hosting and CI, configure secrets, enable Storage and Functions |
| [Cost](cost.md) | See what each action costs in Firebase, the optimizations in place, and the guardrails to set |
| [Design system implementation](design-system.md) | Find the theme token or shared widget for a design rule; how one UI adapts to web and mobile |
| [Localization](localization.md) | Add strings or languages |
| [Contributing](contributing.md) | Follow the workflow, conventions and step-by-step recipes |
| [Firebase development and migration](firebase.md) | Emulator details and importing a legacy data export |

`docs/superpowers/` holds dated design specs and implementation plans for past features. They are a historical record, not current instructions.

## Keeping docs current

Docs change in the **same commit** as the behavior they describe. Before you finish a change, find it in this table and update every page listed:

| If you change… | Update |
| --- | --- |
| A route, screen, tab, sidebar or Settings entry | [Architecture → Navigation](architecture.md#navigation), [Features](features.md) |
| Breakpoints, the sidebar, or how panels and pages open on wide screens | [Design system → Web and mobile](design-system.md#web-and-mobile) |
| A feature's behavior, or fix a known gap | [Features](features.md) (including [Known gaps](features.md#known-gaps)) |
| A persisted field, collection, preference key or Storage path | [Data model](data-model.md); [Backend → Security Rules](backend.md#security-rules) if rules change |
| A formula, threshold or derived figure | [Calculations](calculations.md) |
| A Cloud Function, its contract, secrets or rate limits | [Backend](backend.md), [Security](security.md) |
| Security Rules | [Backend](backend.md#security-rules), [Security](security.md) |
| What data leaves the device, or a new external service | [Security → What leaves the device](security.md#what-leaves-the-device) |
| A `--dart-define`, `.env` key, tool version or setup step | [Getting started](getting-started.md) |
| CI, deploy targets, Hosting config or required GitHub secrets/variables | [Deployment](deployment.md), [Testing → Continuous integration](testing.md#continuous-integration) |
| A test suite, command or testing convention | [Testing](testing.md) |
| How data is read, listened to or written; Functions queries or scaling; bundled or deployed web files | [Cost](cost.md) |
| Theme tokens, shared widgets or brand assets | [Design system implementation](design-system.md) |
| Strings or supported languages | [Localization](localization.md) |
| Startup, providers, sync or offline behavior | [Architecture](architecture.md) (including [Offline behavior](architecture.md#offline-behavior)), [Features → Known gaps](features.md#known-gaps) |
| The service worker, `tool/web_precache.mjs`, `web/index.html` or bundled fonts | [Architecture → Web offline loading](architecture.md#web-offline-loading), [Deployment](deployment.md#hosting-configuration), [Cost → Hosting](cost.md#hosting), [Testing](testing.md) |
| A convention or recipe | [Contributing](contributing.md) |
| A new page | This index |

Write docs to match the code as it is, not as planned. Name real files and symbols so readers can find them. `npm run docs:check` (also run in CI) fails on broken links, missing `#anchors` and file paths in `docs/` that no longer exist. Keep product rules and conventions in the README; keep how-it-works detail here.
