# Accessibility Evidence

Validation date: 2026-05-18

Implemented coverage:

- Shared loading, empty, error, offline, permission, locked, and disclaimer states use explicit titles/messages.
- Auth/onboarding flows include direct labels and non-judgmental recovery copy.
- Finance cards keep readable title/body structure and dynamic text wrapping through Material widgets.
- Home, transactions, budget, insights, Aiko, and calculator screens use standard Material controls with labels/tooltips for primary actions.
- Status copy does not rely only on color.

Local checks:

- Widget tests cover critical screen states and main user paths.
- `flutter analyze` and `flutter test` passed.

Pending release checks:

- Screen reader pass on TalkBack and VoiceOver.
- Large text pass on Android and iOS.
- Keyboard/focus traversal pass for transaction and calculator forms.
