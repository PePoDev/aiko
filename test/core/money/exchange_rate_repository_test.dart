import 'package:aiko/core/money/exchange_rate_repository.dart';
import 'package:aiko/core/money/exchange_rates.dart';
import 'package:aiko/core/storage/device_values.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../offline/record_store_harness.dart';
import 'fake_rate_service.dart';

Decimal d(String value) => Decimal.parse(value);

void main() {
  group('ExchangeRates', () {
    final rates = ExchangeRates(
      base: 'thb',
      rates: {'usd': d('0.025'), 'JPY': d('4.0'), 'BAD': Decimal.zero},
      fetchedAt: DateTime(2026, 10, 15),
    );

    test('quotes from, to and across the base', () {
      expect(rates.base, 'THB');
      expect(rates.rate('THB', 'USD'), d('0.025'));
      expect(rates.rate('USD', 'THB'), d('40'));
      // 1 USD = 40 THB = 160 JPY.
      expect(rates.rate('usd', 'jpy'), d('160'));
      expect(rates.rate('EUR', 'THB'), isNull);
      expect(rates.rate('THB', 'BAD'), isNull);
      expect(rates.rate('EUR', 'EUR'), Decimal.one);
    });

    test('only the saved copy carries an "as of" time', () {
      expect(rates.savedAsOf, DateTime(2026, 10, 15));
      final live = ExchangeRates(
        base: 'THB',
        rates: rates.rates,
        fetchedAt: DateTime(2026, 10, 15),
        isLive: true,
      );
      expect(live.savedAsOf, isNull);
      expect(ExchangeRates.none('THB').savedAsOf, isNull);
    });

    test('round-trips through JSON as a saved copy', () {
      final restored = ExchangeRates.fromJson(rates.toJson())!;
      expect(restored.base, 'THB');
      expect(restored.rates, rates.rates);
      expect(restored.fetchedAt, DateTime(2026, 10, 15));
      expect(restored.isLive, isFalse);
      expect(ExchangeRates.fromJson({'base': 'THB'}), isNull);
    });
  });

  group('ExchangeRateCache', () {
    test('keeps every base and survives a new session', () async {
      final values = MemoryDeviceValues();
      final cache = ExchangeRateCache(values);
      await Future.wait([
        cache.save(
          ExchangeRates(
            base: 'THB',
            rates: {'USD': d('0.025')},
            fetchedAt: DateTime(2026, 10, 15),
          ),
        ),
        cache.save(
          ExchangeRates(
            base: 'USD',
            rates: {'THB': d('40')},
            fetchedAt: DateTime(2026, 10, 16),
          ),
        ),
      ]);

      final later = ExchangeRateCache(values);
      expect((await later.readAll()).keys, unorderedEquals(['THB', 'USD']));
      expect((await later.read('thb'))!.rates, {'USD': d('0.025')});
    });

    test('keeps only the newest bases', () async {
      final cache = ExchangeRateCache(MemoryDeviceValues());
      for (var i = 0; i < ExchangeRateCache.maxBases + 2; i++) {
        await cache.save(
          ExchangeRates(
            base: 'C${i.toString().padLeft(2, '0')}',
            rates: {'USD': Decimal.one},
            fetchedAt: DateTime(2026, 10, 1 + i),
          ),
        );
      }
      final all = await cache.readAll();
      expect(all, hasLength(ExchangeRateCache.maxBases));
      expect(all.containsKey('C00'), isFalse);
      expect(all.containsKey('C09'), isTrue);
    });

    test('a damaged value reads as nothing saved', () async {
      final values = MemoryDeviceValues()
        ..values[ExchangeRateCache.key] = '{not json';
      expect(await ExchangeRateCache(values).readAll(), isEmpty);
    });

    test('is kept in the local record store', () async {
      final store = await openMemoryRecordStore();
      addTearDown(store.close);
      final cache = ExchangeRateCache(LocalDeviceValues(store: store));
      await cache.save(
        ExchangeRates(
          base: 'THB',
          rates: {'USD': d('0.025')},
          fetchedAt: DateTime(2026, 10, 15),
        ),
      );
      final again = ExchangeRateCache(LocalDeviceValues(store: store));
      expect((await again.read('THB'))!.rates['USD'], d('0.025'));
    });
  });

  group('ExchangeRateRepository.quote', () {
    late FakeRateService service;
    late MemoryDeviceValues values;
    var now = DateTime(2026, 10, 17, 9);

    ExchangeRateRepository repository() => ExchangeRateRepository(
      service: service,
      cache: ExchangeRateCache(values),
      clock: () => now,
    );

    setUp(() {
      now = DateTime(2026, 10, 17, 9);
      values = MemoryDeviceValues();
      service = FakeRateService({
        'THB': {'USD': d('0.025'), 'JPY': d('4.0')},
        'USD': {'THB': d('40'), 'JPY': d('160')},
      });
    });

    test('a live quote is saved for offline use', () async {
      final quote = await repository().quote('THB', 'USD');
      expect(quote.isLive, isTrue);
      expect(quote.rate, d('0.025'));

      // Next session, offline: the saved copy answers, with its date.
      service.offline = true;
      final offline = await repository().quote('THB', 'USD');
      expect(offline.isLive, isFalse);
      expect(offline.rate, d('0.025'));
      expect(offline.savedAt, DateTime(2026, 10, 17, 9));
      expect(offline.failure, FxRateFailure.offline);
    });

    test('the saved copy crosses through another base', () async {
      await repository().fetchLive('THB');
      service.offline = true;
      // Only THB rates are saved: 1 USD = 40 THB = 160 JPY.
      final quote = await repository().quote('USD', 'JPY');
      expect(quote.rate, d('160'));
      expect(quote.savedAt, isNotNull);
    });

    test('offline with nothing saved has no rate (never 1)', () async {
      service.offline = true;
      final quote = await repository().quote('THB', 'USD');
      expect(quote.rate, isNull);
      expect(quote.failure, FxRateFailure.offline);
    });

    test('an unknown currency is not reported as offline', () async {
      final quote = await repository().quote('XYZ', 'USD');
      expect(quote.rate, isNull);
      expect(quote.failure, FxRateFailure.unavailable);
    });

    test('rates fetched this session are reused for an hour', () async {
      final repo = repository();
      await repo.quote('THB', 'USD');
      expect((await repo.quote('USD', 'JPY')).isLive, isTrue);
      expect(service.requests, ['THB']);

      now = now.add(const Duration(hours: 2));
      await repo.quote('THB', 'USD');
      expect(service.requests, ['THB', 'THB']);
    });

    test('forceLive always asks the network', () async {
      final repo = repository();
      await repo.quote('THB', 'USD');
      service.offline = true;
      final quote = await repo.quote('THB', 'USD', forceLive: true);
      expect(service.requests, ['THB', 'THB']);
      // Falls back to the saved copy, saying why.
      expect(quote.isLive, isFalse);
      expect(quote.failure, FxRateFailure.offline);
    });
  });
}
