import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

/// Fetches live foreign-exchange rates so the transaction form can auto-fill
/// the conversion rate when an account's currency differs from the amount's.
///
/// Uses the free, no-key open.er-api.com endpoint (ECB-derived daily rates,
/// 160+ currencies). Returns `null` on any failure (offline, unknown currency,
/// bad response) so callers fall back to a user-entered rate — never an error.
///
// ponytail: one free no-key endpoint, no caching. Add an in-memory daily cache
// if the form starts refetching the same pair often enough to matter.
class ExchangeRateService {
  const ExchangeRateService({this.client});

  /// Injectable for tests; defaults to a one-shot [http.Client].
  final http.Client? client;

  static const _base = 'https://open.er-api.com/v6/latest';

  /// Returns how many [to] units one [from] unit buys, or `null` on failure.
  Future<Decimal?> fetchRate(String from, String to) async {
    final fromCode = from.trim().toUpperCase();
    final toCode = to.trim().toUpperCase();
    if (fromCode == toCode) {
      return Decimal.one;
    }
    if (toCode.length != 3) {
      return null;
    }
    return (await fetchRates(fromCode))?[toCode];
  }

  /// Every rate quoted against [base] (how many units of each currency one
  /// [base] unit buys), from a single request; `null` on failure.
  Future<Map<String, Decimal>?> fetchRates(String base) async {
    final baseCode = base.trim().toUpperCase();
    if (baseCode.length != 3) {
      return null;
    }

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse('$_base/$baseCode'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['result'] != 'success') {
        return null;
      }
      final rates = body['rates'] as Map<String, dynamic>?;
      if (rates == null) {
        return null;
      }
      return {
        for (final entry in rates.entries)
          if (Decimal.tryParse(entry.value.toString()) case final rate?)
            if (rate > Decimal.zero) entry.key.toUpperCase(): rate,
      };
    } catch (_) {
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
