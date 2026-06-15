/// Currency codes Aiko supports across its pickers and the offline
/// `profile.baseCurrency` validation path. The list is intentionally short
/// : adding more is fine, but it is a single source of truth so the
/// transaction form, settings, and onboarding stay in sync.
const List<String> kAikoSupportedCurrencies = [
  'THB',
  'USD',
  'EUR',
  'GBP',
  'JPY',
  'SGD',
  'AUD',
  'CAD',
  'CNY',
  'HKD',
];
