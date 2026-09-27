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
