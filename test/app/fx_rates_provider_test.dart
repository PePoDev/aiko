import 'dart:async';

import 'package:aiko/app/providers.dart';
import 'package:aiko/core/connectivity/network_status.dart';
import 'package:aiko/core/money/exchange_rate_repository.dart';
import 'package:aiko/core/money/exchange_rates.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/storage/device_values.dart';
import 'package:aiko/features/dashboard/application/dashboard_summary_builder.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/money/fake_rate_service.dart';

/// A connection that tests switch on and off.
class _FakeNetwork implements NetworkMonitor {
  _FakeNetwork(this.online);

  bool online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;
}

void main() {
  late FakeRateService service;
  late MemoryDeviceValues values;
  late DateTime now;
  late _FakeNetwork network;

  setUp(() {
    now = DateTime(2026, 10, 17, 9);
    values = MemoryDeviceValues();
    service = FakeRateService({
      'THB': {'USD': Decimal.parse('0.025')},
    });
    network = _FakeNetwork(true);
  });

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        networkMonitorProvider.overrideWithValue(network),
        exchangeRateRepositoryProvider.overrideWithValue(
          ExchangeRateRepository(
            service: service,
            cache: ExchangeRateCache(values),
            clock: () => now,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Lets background fetches (scheduled after build) run.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  Future<void> saveRatesFrom(DateTime fetchedAt) async {
    await ExchangeRateCache(values).save(
      ExchangeRates(
        base: 'THB',
        rates: {'USD': Decimal.parse('0.030')},
        fetchedAt: fetchedAt,
      ),
    );
  }

  test('online: live rates, no "as of" note', () async {
    final rates = await container().read(fxRatesProvider('thb').future);
    expect(rates.isLive, isTrue);
    expect(rates.rates['USD'], Decimal.parse('0.025'));
    expect(CurrencyConverter.from(rates).ratesAsOf, isNull);
  });

  test('offline cold start uses the saved rates with their date', () async {
    await saveRatesFrom(DateTime(2026, 10, 15, 8));
    service.offline = true;

    final rates = await container().read(fxRatesProvider('THB').future);

    expect(rates.isLive, isFalse);
    expect(rates.rates['USD'], Decimal.parse('0.030'));
    expect(CurrencyConverter.from(rates).ratesAsOf, DateTime(2026, 10, 15, 8));
  });

  test(
    'the saved copy shows at once, then the live rates replace it',
    () async {
      await saveRatesFrom(DateTime(2026, 10, 15, 8));
      final c = container();
      final sub = c.listen(fxRatesProvider('THB'), (_, _) {});
      addTearDown(sub.close);

      final first = await c.read(fxRatesProvider('THB').future);
      expect(first.isLive, isFalse);

      await settle();
      final second = c.read(fxRatesProvider('THB')).requireValue;
      expect(second.isLive, isTrue);
      expect(second.rates['USD'], Decimal.parse('0.025'));
    },
  );

  test('a failed fetch does not stick: the next read retries', () async {
    service.offline = true;
    final c = container();
    final sub = c.listen(fxRatesProvider('THB'), (_, _) {});
    addTearDown(sub.close);

    final failed = await c.read(fxRatesProvider('THB').future);
    expect(failed.isEmpty, isTrue);

    // Back online. A read right away is throttled...
    service.offline = false;
    final notifier = c.read(fxRatesProvider('THB').notifier);
    notifier.retryIfStale();
    await settle();
    expect(c.read(fxRatesProvider('THB')).requireValue.isEmpty, isTrue);
    expect(service.requests, hasLength(1));

    // ...a later one fetches again, and the new rates arrive as state.
    now = now.add(FxRatesNotifier.retryOnReadAfter);
    notifier.retryIfStale();
    await settle();
    final rates = c.read(fxRatesProvider('THB')).requireValue;
    expect(rates.isLive, isTrue);
    expect(rates.rates['USD'], Decimal.parse('0.025'));
  });

  test('coming back online fetches the rates at once', () async {
    await saveRatesFrom(DateTime(2026, 10, 15, 8));
    service.offline = true;
    network.online = false;
    final c = container();
    final sub = c.listen(fxRatesProvider('THB'), (_, _) {});
    addTearDown(sub.close);
    await c.read(fxRatesProvider('THB').future);
    await settle();
    expect(c.read(fxRatesProvider('THB')).requireValue.isLive, isFalse);
    final requests = service.requests.length;

    service.offline = false;
    network.set(true);
    await settle();

    final rates = c.read(fxRatesProvider('THB')).requireValue;
    expect(rates.isLive, isTrue);
    expect(rates.rates['USD'], Decimal.parse('0.025'));
    expect(service.requests, hasLength(requests + 1));
  });

  test('pull-to-refresh fetches again at once', () async {
    service.offline = true;
    final c = container();
    final sub = c.listen(fxRatesProvider('THB'), (_, _) {});
    addTearDown(sub.close);
    await c.read(fxRatesProvider('THB').future);

    expect(await c.read(fxRatesProvider('THB').notifier).refresh(), isFalse);
    service.offline = false;
    expect(await c.read(fxRatesProvider('THB').notifier).refresh(), isTrue);
    expect(c.read(fxRatesProvider('THB')).requireValue.isLive, isTrue);
  });

  test('a kept consumer recomputes when rates come back', () async {
    service.offline = true;
    final c = container();
    // Like the kept-alive Overview summary: converts with whatever is there.
    final converted = FutureProvider<Decimal?>((ref) async {
      final rates = await ref.watch(fxRatesProvider('THB').future);
      return CurrencyConverter.from(rates).toBase(Money.parse('10', 'USD'));
    });
    final sub = c.listen(converted, (_, _) {});
    addTearDown(sub.close);

    expect(await c.read(converted.future), isNull);

    service.offline = false;
    await c.read(fxRatesProvider('THB').notifier).refresh();
    expect(await c.read(converted.future), Decimal.parse('400'));
  });
}
