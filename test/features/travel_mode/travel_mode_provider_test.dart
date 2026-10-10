import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/exchange_rate_service.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/travel_mode/application/travel_mode_provider.dart';
import 'package:aiko/features/travel_mode/domain/trip.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubRateService extends ExchangeRateService {
  const _StubRateService(this._rate);

  final Decimal? _rate;

  @override
  Future<Decimal?> fetchRate(String from, String to) async => _rate;
}

class _CountingStorage extends MemorySecureStorageService {
  var writes = 0;

  @override
  Future<void> write(String key, String value) {
    writes++;
    return super.write(key, value);
  }
}

Trip _trip() => Trip(
  name: 'Tokyo',
  homeCurrency: 'THB',
  localCurrency: 'JPY',
  budget: Money.parse('50000', 'THB'),
);

ProviderContainer _container(ExchangeRateService service) {
  final container = ProviderContainer(
    overrides: [
      exchangeRateServiceProvider.overrideWithValue(service),
      travelStorageProvider.overrideWithValue(MemorySecureStorageService()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('trip and decimal budget survive a new client session', () async {
    final storage = MemorySecureStorageService();
    ProviderContainer client() => ProviderContainer(
      overrides: [
        travelStorageProvider.overrideWithValue(storage),
        exchangeRateServiceProvider.overrideWithValue(
          const _StubRateService(null),
        ),
      ],
    );
    final first = client();
    await first.read(travelModeProvider.notifier).createTrip(_trip());
    first.dispose();
    final second = client();
    addTearDown(second.dispose);
    final restored = await second.read(storedTravelProvider.future);
    expect(restored.activeTrip!.name, 'Tokyo');
    expect(restored.activeTrip!.budget, Money.parse('50000', 'THB'));
    expect(restored.exchangeRate, 4.30);
  });
  test('createTrip uses the live rate when available', () async {
    final container = _container(_StubRateService(Decimal.parse('4.55')));
    await container.read(travelModeProvider.notifier).createTrip(_trip());
    expect(container.read(travelModeProvider).exchangeRate, 4.55);
  });

  test(
    'createTrip falls back to the reference rate when lookup fails',
    () async {
      final container = _container(const _StubRateService(null));
      await container.read(travelModeProvider.notifier).createTrip(_trip());
      // THB -> JPY reference fallback.
      expect(container.read(travelModeProvider).exchangeRate, 4.30);
    },
  );

  test('createTrip saves once, after the live rate arrives', () async {
    final storage = _CountingStorage();
    final container = ProviderContainer(
      overrides: [
        exchangeRateServiceProvider.overrideWithValue(
          _StubRateService(Decimal.parse('4.55')),
        ),
        travelStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    await container.read(travelModeProvider.notifier).createTrip(_trip());
    expect(storage.writes, 1);
    container.invalidate(storedTravelProvider);
    final restored = await container.read(storedTravelProvider.future);
    expect(restored.exchangeRate, 4.55);
  });

  test('createTrip refuses the same home and local currency', () async {
    final container = _container(const _StubRateService(null));
    final sameCurrency = _trip().copyWith(localCurrency: 'THB');
    await expectLater(
      container.read(travelModeProvider.notifier).createTrip(sameCurrency),
      throwsArgumentError,
    );
    expect(container.read(travelModeProvider).activeTrip, isNull);
  });

  test('a typed rate updates state and is saved only when committed', () async {
    final storage = _CountingStorage();
    final container = ProviderContainer(
      overrides: [
        exchangeRateServiceProvider.overrideWithValue(
          const _StubRateService(null),
        ),
        travelStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
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
    ProviderContainer client() => ProviderContainer(
      overrides: [
        travelStorageProvider.overrideWithValue(storage),
        exchangeRateServiceProvider.overrideWithValue(
          const _StubRateService(null),
        ),
      ],
    );
    final first = client();
    final notifier = first.read(travelModeProvider.notifier);
    await notifier.createTrip(_trip());
    notifier.addForeignFee(
      TravelFee(amount: Money.parse('1200', 'JPY'), merchant: 'Ramen bar'),
    );
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    final second = client();
    addTearDown(second.dispose);
    final restored = await second.read(storedTravelProvider.future);
    final fee = restored.activeTrip!.foreignFees.single;
    expect(fee.amount, Money.parse('1200', 'JPY'));
    expect(fee.merchant, 'Ramen bar');
  });

  test(
    'refreshRate returns false and keeps the rate with no active trip',
    () async {
      final container = _container(_StubRateService(Decimal.parse('4.55')));
      expect(
        await container.read(travelModeProvider.notifier).refreshRate(),
        false,
      );
    },
  );
}
