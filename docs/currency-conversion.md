# Currency Conversion (Add / Edit Transaction)

How the transaction form converts an amount when the chosen account tracks a
different currency than the amount you typed.

## When it appears

The form has two currencies:

- **Amount currency** — the `Currency` dropdown next to the amount (defaults to
  `THB`).
- **Account currency** — the currency of the account you selected.

When these differ, a compact conversion notice appears under the account
picker. When they match, there is no conversion and nothing is shown.

## The rate

- `1 <amount currency> = <rate> <account currency>` — e.g. `1 THB = 0.0277 USD`.
- The rate is **auto-filled** with a live quote the moment you pick a
  different-currency account (or change the amount currency).
- The rate number is **highlighted and tappable** — tap it to enter a rate
  manually. A manually entered rate sticks and won't be overwritten by an
  auto-fetch.
- The **refresh** icon re-fetches the latest live rate (and discards a manual
  override).
- "Saves as ≈ X" previews the converted amount as you change the amount or rate.

## Live rates

Rates come from [`ExchangeRateService`](../lib/core/money/exchange_rate_service.dart),
which calls the free, no-key endpoint **`open.er-api.com`** (ECB-derived daily
rates, 160+ currencies). It is wired in via `exchangeRateServiceProvider`
([lib/app/providers.dart](../lib/app/providers.dart)) so tests can override it.

The lookup is best-effort: on any failure (offline, unknown currency, bad
response) it returns `null`, the rate field is left as-is, and you enter the
rate yourself. The form never blocks or errors on a failed lookup.

> Rates are indicative daily reference rates, not a dealing/transactional rate.
> Adjust manually if your bank or card used a different rate.

## When conversion happens

There is **no convert button**. The amount stays in the amount currency while
you edit. The conversion runs once, at **Save Transaction**:

```
stored amount   = entered amount × rate
stored currency = account currency
```

So a 100 THB expense on a USD account with rate `0.0277` is stored as
`2.77 USD`. If the rate field is empty or non-positive at save time, the form
asks you to enter a positive rate before saving.

This applies to single transactions and to both legs of a transfer (the source
account's currency drives the conversion).

## Code map

| Piece | Location |
| --- | --- |
| Rate fetch | `lib/core/money/exchange_rate_service.dart` |
| Provider (test-overridable) | `exchangeRateServiceProvider` in `lib/app/providers.dart` |
| Auto-fill / manual edit / save-time conversion | `_maybeAutofillRate`, `_editRateManually`, save logic in `lib/features/transactions/presentation/transaction_form_screen.dart` |
| Notice widget | `_CurrencyConversionPrompt` (same file) |
| Tests | `test/core/money/exchange_rate_service_test.dart`, `test/features/transactions/transaction_form_widget_test.dart` |
