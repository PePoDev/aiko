# Performance Evidence

The current expansion implementation is intentionally lightweight:

- Import preview performs one linear pass over preview rows.
- Portfolio allocation computes market value with simple in-memory folds.
- Prediction scenarios are deterministic arithmetic with freshness checks.
- Export package, backup, device, travel, entitlement, and optimization services are synchronous domain services.
- Screens are static Material lists and should render within MVP frame budgets.

Before enabling large imports, provider integrations, OCR, or portfolio price sync, add pagination, background jobs, progress states, and cancellation handling.
