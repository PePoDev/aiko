import 'package:aiko/core/money/exchange_rate_service.dart';
import 'package:decimal/decimal.dart';

/// Answers each base from [rates]; [offline] fails like no connection, and
/// a base not in [rates] fails like an unknown currency.
class FakeRateService extends ExchangeRateService {
  FakeRateService(this.rates);

  final Map<String, Map<String, Decimal>> rates;
  bool offline = false;
  final requests = <String>[];

  @override
  Future<Map<String, Decimal>> latestRates(String base) async {
    requests.add(base);
    if (offline) throw const ExchangeRateException(isNetwork: true);
    final found = rates[base.toUpperCase()];
    if (found == null) throw const ExchangeRateException(isNetwork: false);
    return found;
  }
}
