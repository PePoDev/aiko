import 'package:decimal/decimal.dart';

/// Exchange rates quoted against one [base] currency: how many units of each
/// currency one [base] unit buys, as `ExchangeRateService.latestRates`
/// returns them.
class ExchangeRates {
  ExchangeRates({
    required String base,
    Map<String, Decimal> rates = const {},
    this.fetchedAt,
    this.isLive = false,
  }) : base = base.trim().toUpperCase(),
       rates = Map.unmodifiable({
         for (final entry in rates.entries)
           if (entry.value > Decimal.zero) entry.key.toUpperCase(): entry.value,
       });

  /// No rates at all (offline with nothing saved).
  ExchangeRates.none(String base) : this(base: base);

  final String base;
  final Map<String, Decimal> rates;

  /// When the rates were fetched; null when there are none.
  final DateTime? fetchedAt;

  /// Fetched in this session, as opposed to the copy saved on the device.
  final bool isLive;

  bool get isEmpty => rates.isEmpty;

  /// When the totals use the device's saved copy, the time it was fetched
  /// (screens say "Rates as of …"); null for live rates or none at all.
  DateTime? get savedAsOf => isLive || isEmpty ? null : fetchedAt;

  /// How many [to] units one [from] unit buys, crossing through [base] when
  /// neither is the base; null when either rate is missing.
  Decimal? rate(String from, String to) {
    final fromCode = from.trim().toUpperCase();
    final toCode = to.trim().toUpperCase();
    if (fromCode == toCode) return Decimal.one;
    final fromRate = fromCode == base ? Decimal.one : rates[fromCode];
    final toRate = toCode == base ? Decimal.one : rates[toCode];
    if (fromRate == null || toRate == null) return null;
    return (toRate / fromRate).toDecimal(scaleOnInfinitePrecision: 10);
  }

  ExchangeRates asSaved() =>
      ExchangeRates(base: base, rates: rates, fetchedAt: fetchedAt);

  Map<String, Object?> toJson() => {
    'base': base,
    'fetched_at': fetchedAt?.toUtc().toIso8601String(),
    'rates': {for (final entry in rates.entries) entry.key: '${entry.value}'},
  };

  /// The saved copy written by [toJson]; null when it can't be read.
  static ExchangeRates? fromJson(Object? json) {
    if (json is! Map) return null;
    final base = json['base'];
    final rates = json['rates'];
    final fetchedAt = DateTime.tryParse('${json['fetched_at']}');
    if (base is! String || rates is! Map || fetchedAt == null) return null;
    return ExchangeRates(
      base: base,
      fetchedAt: fetchedAt.toLocal(),
      rates: {
        for (final entry in rates.entries)
          '${entry.key}': ?Decimal.tryParse('${entry.value}'),
      },
    );
  }
}

/// Why no rate could be found for a pair.
enum FxRateFailure {
  /// No connection (or no answer in time) and nothing saved on the device.
  offline,

  /// The rate service answered but has no rate for the pair.
  unavailable,
}

/// A rate for one currency pair, for the transaction form and Travel Mode.
class FxQuote {
  const FxQuote.live(Decimal this.rate) : savedAt = null, failure = null;

  /// From the rates saved on the device, fetched at [savedAt]; [failure]
  /// says why there was no live rate.
  const FxQuote.saved(Decimal this.rate, DateTime this.savedAt, [this.failure]);

  const FxQuote.none(FxRateFailure this.failure) : rate = null, savedAt = null;

  final Decimal? rate;
  final DateTime? savedAt;
  final FxRateFailure? failure;

  bool get isLive => rate != null && savedAt == null;
}
