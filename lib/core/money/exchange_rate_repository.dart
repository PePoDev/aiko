import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../storage/device_values.dart';
import 'exchange_rate_service.dart';
import 'exchange_rates.dart';

/// The last good rates per base currency, saved on this device (they are
/// public data, so they are not synced) so totals and forms still convert
/// offline. All bases live in one JSON value; the newest [maxBases] are kept.
class ExchangeRateCache {
  ExchangeRateCache(this._values);

  final DeviceValueStore _values;

  static const key = 'fx_rates_v1';
  static const maxBases = 8;

  Future<void> _writing = Future.value();

  /// Every saved base, keyed by its code.
  Future<Map<String, ExchangeRates>> readAll() async {
    final raw = await _values.read(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final saved = decoded.map(ExchangeRates.fromJson).nonNulls;
      return {for (final rates in saved) rates.base: rates};
    } on FormatException {
      return {};
    }
  }

  Future<ExchangeRates?> read(String base) async =>
      (await readAll())[base.trim().toUpperCase()];

  /// Saves [rates] (replacing the same base). Saves run one after another so
  /// two bases fetched at once both stay.
  Future<void> save(ExchangeRates rates) {
    if (rates.isEmpty || rates.fetchedAt == null) return Future.value();
    return _writing = _writing
        .then((_) => _write(rates))
        .onError<Object>((_, _) {});
  }

  Future<void> _write(ExchangeRates rates) async {
    final all = await readAll();
    all[rates.base] = rates;
    final newest = all.values.toList()
      ..sort((a, b) => b.fetchedAt!.compareTo(a.fetchedAt!));
    await _values.write(
      key,
      jsonEncode([for (final kept in newest.take(maxBases)) kept.toJson()]),
    );
  }
}

/// Exchange rates for the app: live from [ExchangeRateService] when the
/// network answers (each fetch also saved on the device), else the saved
/// copy. One instance per app session.
class ExchangeRateRepository {
  ExchangeRateRepository({
    required ExchangeRateService service,
    required ExchangeRateCache cache,
    DateTime Function()? clock,
  }) : _service = service,
       _cache = cache,
       _clock = clock ?? DateTime.now;

  final ExchangeRateService _service;
  final ExchangeRateCache _cache;
  final DateTime Function() _clock;

  /// A quote reuses rates fetched this session for this long instead of
  /// asking the network again (the source updates once a day).
  static const reuseLiveFor = Duration(hours: 1);

  final _live = <String, ExchangeRates>{};
  final _fetching = <String, Future<ExchangeRates>>{};

  static String _code(String currency) => currency.trim().toUpperCase();

  /// The repository's clock (injectable for tests).
  DateTime now() => _clock();

  /// Rates for [base] fetched in this session, or null.
  ExchangeRates? sessionRates(String base) => _live[_code(base)];

  /// Fetches live rates for [base] and saves them for offline use. Throws
  /// [ExchangeRateException]. Concurrent calls for one base share a request.
  Future<ExchangeRates> fetchLive(String base) {
    final code = _code(base);
    return _fetching[code] ??= _fetch(code).whenComplete(() {
      // A block: returning the removed future would wait on itself.
      _fetching.remove(code);
    });
  }

  Future<ExchangeRates> _fetch(String code) async {
    final rates = ExchangeRates(
      base: code,
      rates: await _service.latestRates(code),
      fetchedAt: _clock(),
      isLive: true,
    );
    _live[code] = rates;
    await _cache.save(rates);
    return rates;
  }

  /// The copy saved on the device for [base], or null.
  Future<ExchangeRates?> saved(String base) async =>
      (await _cache.read(base))?.asSaved();

  /// How many [to] one [from] buys. Rates fetched this session are reused
  /// (unless [forceLive]); otherwise one request for [from]'s rates, and when
  /// that fails, the newest saved copy that quotes both currencies (crossing
  /// through its base). [FxQuote.failure] says why the live rate is missing.
  Future<FxQuote> quote(
    String from,
    String to, {
    bool forceLive = false,
  }) async {
    final fromCode = _code(from);
    final toCode = _code(to);
    if (fromCode == toCode) return FxQuote.live(Decimal.one);
    if (!forceLive) {
      final now = _clock();
      for (final rates in _live.values) {
        final rate = rates.rate(fromCode, toCode);
        if (rate != null && now.difference(rates.fetchedAt!) < reuseLiveFor) {
          return FxQuote.live(rate);
        }
      }
    }
    FxRateFailure failure;
    try {
      final rate = (await fetchLive(fromCode)).rate(fromCode, toCode);
      if (rate != null) return FxQuote.live(rate);
      failure = FxRateFailure.unavailable;
    } on ExchangeRateException catch (error) {
      failure = error.isNetwork
          ? FxRateFailure.offline
          : FxRateFailure.unavailable;
    }
    return await savedQuote(fromCode, toCode, failure: failure) ??
        FxQuote.none(failure);
  }

  /// The pair from the newest saved copy that quotes both currencies, or
  /// null. [failure] is passed on to say why the live rate is missing.
  Future<FxQuote?> savedQuote(
    String from,
    String to, {
    FxRateFailure? failure,
  }) async {
    final saved = (await _cache.readAll()).values.toList()
      ..sort((a, b) => b.fetchedAt!.compareTo(a.fetchedAt!));
    for (final rates in saved) {
      final rate = rates.rate(from, to);
      if (rate != null) return FxQuote.saved(rate, rates.fetchedAt!, failure);
    }
    return null;
  }
}
