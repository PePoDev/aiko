import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/exchange_rate_repository.dart';
import 'package:aiko/core/money/exchange_rates.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/storage/device_values.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/travel_mode/application/travel_mode_provider.dart';
import 'package:aiko/features/travel_mode/domain/trip.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/money/fake_rate_service.dart';

class _CountingStorage extends MemorySecureStorageService {
  var writes = 0;
  bool fail = false;

  @override
  Future<void> write(String key, String value) {
    writes++;
    if (fail) throw StateError('storage unavailable');
    return super.write(key, value);
  }
}

Trip _trip({String home = 'THB', String local = 'JPY'}) => Trip(
  name: 'Tokyo',
  homeCurrency: home,
  localCurrency: local,
  budget: Money.parse('50000', home),
);

/// THB→JPY is 4.55 live; [offline] makes every fetch fail.
FakeRateService _service({bool offline = false}) => FakeRateService({
  'THB': {'JPY': Decimal.parse('4.55'), 'USD': Decimal.parse('0.0275')},
})..offline = offline;

ProviderContainer _container(
  FakeRateService service, {
  SecureStorageService? storage,
  MemoryDeviceValues? device,
}) {
  final container = ProviderContainer(
    overrides: [
      exchangeRateRepositoryProvider.overrideWithValue(
        ExchangeRateRepository(
          service: service,
          cache: ExchangeRateCache(device ?? MemoryDeviceValues()),
        ),
      ),
      travelStorageProvider.overrideWithValue(
        storage ?? MemorySecureStorageService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('trip and decimal budget survive a new client session', () async {
    final storage = MemorySecureStorageService();
    final first = ProviderContainer(
      overrides: [
        exchangeRateRepositoryProvider.overrideWithValue(
          ExchangeRateRepository(
            service: _service(offline: true),
            cache: ExchangeRateCache(MemoryDeviceValues()),
          ),
        ),
        travelStorageProvider.overrideWithValue(storage),
      ],
    );
    await first.read(travelModeProvider.notifier).createTrip(_trip());
    first.dispose();

    final second = _container(_service(offline: true), storage: storage);
    final restored = await second.read(storedTravelProvider.future);
    expect(restored.activeTrip!.name, 'Tokyo');
    expect(restored.activeTrip!.budget, Money.parse('50000', 'THB'));
    expect(restored.exchangeRate, 4.30);
  });

  test('createTrip uses the live rate when available', () async {
    final container = _container(_service());
    final start = await container
        .read(travelModeProvider.notifier)
        .createTrip(_trip());
    expect(start.source, TripRateSource.live);
    expect(container.read(travelModeProvider).exchangeRate, 4.55);
  });

  test('offline, the rates saved on the device come first', () async {
    final device = MemoryDeviceValues();
    await ExchangeRateCache(device).save(
      ExchangeRates(
        base: 'THB',
        rates: {'JPY': Decimal.parse('4.40')},
        fetchedAt: DateTime(2026, 10, 15, 8),
      ),
    );
    final container = _container(_service(offline: true), device: device);

    final start = await container
        .read(travelModeProvider.notifier)
        .createTrip(_trip());

    expect(start.source, TripRateSource.saved);
    expect(start.savedAt, DateTime(2026, 10, 15, 8));
    expect(container.read(travelModeProvider).exchangeRate, 4.40);
  });

  test('offline with nothing saved, the reference table is used', () async {
    final container = _container(_service(offline: true));
    final start = await container
        .read(travelModeProvider.notifier)
        .createTrip(_trip());
    expect(start.source, TripRateSource.reference);
    expect(container.read(travelModeProvider).exchangeRate, 4.30);
  });

  test('with no rate anywhere, nothing is saved and a rate is asked', () async {
    final storage = _CountingStorage();
    final container = _container(_service(offline: true), storage: storage);
    final notifier = container.read(travelModeProvider.notifier);

    final start = await notifier.createTrip(_trip(home: 'EUR', local: 'SGD'));

    expect(start.started, isFalse);
    expect(storage.writes, 0);
    expect(container.read(travelModeProvider).activeTrip, isNull);

    // The user types the rate.
    final typed = await notifier.createTrip(
      _trip(home: 'EUR', local: 'SGD'),
      rate: 1.45,
    );
    expect(typed.source, TripRateSource.manual);
    expect(container.read(travelModeProvider).exchangeRate, 1.45);
    expect(storage.writes, 1);
  });

  test('createTrip saves once, after the rate is known', () async {
    final storage = _CountingStorage();
    final container = _container(_service(), storage: storage);
    await container.read(travelModeProvider.notifier).createTrip(_trip());
    expect(storage.writes, 1);
    container.invalidate(storedTravelProvider);
    final restored = await container.read(storedTravelProvider.future);
    expect(restored.exchangeRate, 4.55);
  });

  test('a failed save is reported and starts no trip', () async {
    final storage = _CountingStorage()..fail = true;
    final container = _container(_service(), storage: storage);
    await expectLater(
      container.read(travelModeProvider.notifier).createTrip(_trip()),
      throwsStateError,
    );
    expect(container.read(travelModeProvider).activeTrip, isNull);
  });

  test('createTrip refuses the same home and local currency', () async {
    final container = _container(_service());
    final sameCurrency = _trip().copyWith(localCurrency: 'THB');
    await expectLater(
      container.read(travelModeProvider.notifier).createTrip(sameCurrency),
      throwsArgumentError,
    );
    expect(container.read(travelModeProvider).activeTrip, isNull);
  });

  test('a typed rate updates state and is saved only when committed', () async {
    final storage = _CountingStorage();
    final container = _container(_service(offline: true), storage: storage);
    final notifier = container.read(travelModeProvider.notifier);
    await notifier.createTrip(_trip());
    final writesAfterCreate = storage.writes;

    notifier.updateExchangeRate(0.5, persist: false);
    notifier.updateExchangeRate(0.02, persist: false);
    expect(container.read(travelModeProvider).exchangeRate, 0.02);
    expect(storage.writes, writesAfterCreate);

    notifier.updateExchangeRate(0.021);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(travelModeProvider).exchangeRate, 0.021);
    expect(storage.writes, writesAfterCreate + 1);

    // Zero or negative rates are ignored.
    notifier.updateExchangeRate(0);
    expect(container.read(travelModeProvider).exchangeRate, 0.021);
  });

  test('a logged fee keeps its merchant across sessions', () async {
    final storage = MemorySecureStorageService();
    final first = _container(_service(offline: true), storage: storage);
    final notifier = first.read(travelModeProvider.notifier);
    await notifier.createTrip(_trip());
    notifier.addForeignFee(
      TravelFee(amount: Money.parse('1200', 'JPY'), merchant: 'Ramen bar'),
    );
    await Future<void>.delayed(Duration.zero);

    final second = _container(_service(offline: true), storage: storage);
    final restored = await second.read(storedTravelProvider.future);
    final fee = restored.activeTrip!.foreignFees.single;
    expect(fee.amount, Money.parse('1200', 'JPY'));
    expect(fee.merchant, 'Ramen bar');
  });

  group('refreshRate', () {
    test('returns false with no active trip', () async {
      final container = _container(_service());
      expect(
        await container.read(travelModeProvider.notifier).refreshRate(),
        false,
      );
    });

    test('offline it keeps the last rate', () async {
      final service = _service(offline: true);
      final container = _container(service);
      final notifier = container.read(travelModeProvider.notifier);
      await notifier.createTrip(_trip());
      expect(await notifier.refreshRate(), isFalse);
      expect(container.read(travelModeProvider).exchangeRate, 4.30);

      service.offline = false;
      expect(await notifier.refreshRate(), isTrue);
      expect(container.read(travelModeProvider).exchangeRate, 4.55);
    });
  });

  group('travelReferenceRate', () {
    test('covers listed pairs in both directions', () {
      expect(travelReferenceRate('THB', 'JPY'), 4.30);
      expect(travelReferenceRate('usd', 'eur'), 0.92);
      expect(travelReferenceRate('JPY', 'THB'), closeTo(1 / 4.30, 1e-12));
    });

    test('has no rate for other pairs (never 1)', () {
      expect(travelReferenceRate('EUR', 'SGD'), isNull);
      expect(travelReferenceRate('GBP', 'AUD'), isNull);
    });
  });
}
