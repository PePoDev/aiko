import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import '../network/network_errors.dart';

/// Why [ExchangeRateService.latestRates] has no rates.
class ExchangeRateException implements Exception {
  const ExchangeRateException({required this.isNetwork});

  /// No connection or no answer in time, as opposed to a bad response or an
  /// unknown currency.
  final bool isNetwork;

  @override
  String toString() =>
      'ExchangeRateException(${isNetwork ? 'network' : 'unavailable'})';
}

/// Fetches live foreign-exchange rates from the free, no-key open.er-api.com
/// endpoint (ECB-derived daily rates, 160+ currencies).
///
/// It doesn't cache: `ExchangeRateRepository` keeps the last good rates on
/// the device so totals and forms still convert offline.
class ExchangeRateService {
  const ExchangeRateService({this.client});

  /// Injectable for tests; defaults to a one-shot [http.Client].
  final http.Client? client;

  static const _base = 'https://open.er-api.com/v6/latest';

  /// How long a request may take before it counts as no connection.
  static const timeout = Duration(seconds: 10);

  /// Every rate quoted against [base] (how many units of each currency one
  /// [base] unit buys), from a single request. Throws [ExchangeRateException]
  /// when there are none.
  Future<Map<String, Decimal>> latestRates(String base) async {
    final baseCode = base.trim().toUpperCase();
    if (baseCode.length != 3) {
      throw const ExchangeRateException(isNetwork: false);
    }

    final httpClient = client ?? http.Client();
    try {
      final http.Response response;
      try {
        response = await httpClient
            .get(Uri.parse('$_base/$baseCode'))
            .timeout(timeout);
      } catch (error) {
        throw ExchangeRateException(isNetwork: isNetworkError(error));
      }
      if (response.statusCode != 200) {
        throw const ExchangeRateException(isNetwork: false);
      }

      final Object? body;
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        // A captive portal answers with its own HTML page.
        throw const ExchangeRateException(isNetwork: true);
      }
      if (body is! Map<String, dynamic> || body['result'] != 'success') {
        throw const ExchangeRateException(isNetwork: false);
      }
      final rates = body['rates'];
      if (rates is! Map<String, dynamic>) {
        throw const ExchangeRateException(isNetwork: false);
      }
      final parsed = {
        for (final entry in rates.entries)
          if (Decimal.tryParse(entry.value.toString()) case final rate?)
            if (rate > Decimal.zero) entry.key.toUpperCase(): rate,
      };
      if (parsed.isEmpty) throw const ExchangeRateException(isNetwork: false);
      return parsed;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
