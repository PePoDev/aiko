# US5 Insights And Reports Performance

Validation date: 2026-05-18

Scope: deterministic Aiko insights, monthly report aggregation, chart placeholders, Aiko Review, report screen, and CSV export.

Evidence:

- Unit tests cover report aggregation, insight source summaries, consent gating, and CSV export.
- Widget tests cover Insights and Aiko Review entry.
- `flutter test` passed.

Result: Aiko Review generation is deterministic and fast at fixture scale. The under-10-second profile target still requires emulator/device measurement.
