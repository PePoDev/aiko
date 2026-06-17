import 'package:aiko/core/money/exchange_rate_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('returns 1 for identical currencies without a request', () async {
    final service = ExchangeRateService(
      client: MockClient((_) async => throw StateError('should not call')),
    );
    expect(await service.fetchRate('USD', 'usd'), Decimal.one);
  });

  test('parses the target rate from a successful response', () async {
    final service = ExchangeRateService(
      client: MockClient(
        (req) async => http.Response(
          '{"result":"success","base_code":"THB",'
          '"rates":{"USD":0.0277,"EUR":0.026}}',
          200,
        ),
      ),
    );
    expect(await service.fetchRate('THB', 'USD'), Decimal.parse('0.0277'));
  });

  test('returns null on non-200, error result, or missing currency', () async {
    final down = ExchangeRateService(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(await down.fetchRate('THB', 'USD'), isNull);

    final missing = ExchangeRateService(
      client: MockClient(
        (_) async => http.Response('{"result":"success","rates":{}}', 200),
      ),
    );
    expect(await missing.fetchRate('THB', 'XYZ'), isNull);
  });
}
