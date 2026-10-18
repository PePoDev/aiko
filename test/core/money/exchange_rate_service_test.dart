import 'package:aiko/core/money/exchange_rate_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('throws on non-200 or when there are no rates', () async {
    final down = ExchangeRateService(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(
      down.latestRates('THB'),
      throwsA(isA<ExchangeRateException>()),
    );

    final empty = ExchangeRateService(
      client: MockClient(
        (_) async => http.Response('{"result":"success","rates":{}}', 200),
      ),
    );
    await expectLater(
      empty.latestRates('THB'),
      throwsA(isA<ExchangeRateException>()),
    );
  });

  test('fetches every rate for a base in one request', () async {
    var requests = 0;
    final service = ExchangeRateService(
      client: MockClient((req) async {
        requests++;
        expect(req.url.path, endsWith('/THB'));
        return http.Response(
          '{"result":"success","rates":{"usd":0.0277,"EUR":0.026,"BAD":"x"}}',
          200,
        );
      }),
    );
    expect(await service.latestRates('thb'), {
      'USD': Decimal.parse('0.0277'),
      'EUR': Decimal.parse('0.026'),
    });
    expect(requests, 1);
  });
}
