import 'package:aiko/app/locale_controller.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const languageKey = 'aiko_language_code';
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.platformDispatcher.clearLocaleTestValue();
  });

  test('uses the persisted language when one is stored', () async {
    final storage = MemorySecureStorageService();
    await storage.write(languageKey, 'en');

    final container = ProviderContainer(
      overrides: [
        appLocaleControllerProvider.overrideWith(
          () => AppLocaleController(storage: storage),
        ),
      ],
    );

    final state = await container.read(appLocaleControllerProvider.future);

    expect(state.locale, const Locale('en'));
    expect(state.followsSystem, isFalse);
  });

  test(
    'follows the device locale on first launch without persisting it',
    () async {
      binding.platformDispatcher.localeTestValue = const Locale('en', 'US');
      final storage = MemorySecureStorageService();

      final container = ProviderContainer(
        overrides: [
          appLocaleControllerProvider.overrideWith(
            () => AppLocaleController(storage: storage),
          ),
        ],
      );

      final state = await container.read(appLocaleControllerProvider.future);

      expect(state.locale, const Locale('en'));
      expect(state.followsSystem, isTrue);
      expect(await storage.read(languageKey), isNull);
    },
  );

  test(
    'falls back to the fallback locale when the device locale is unsupported',
    () async {
      binding.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
      final storage = MemorySecureStorageService();

      final container = ProviderContainer(
        overrides: [
          appLocaleControllerProvider.overrideWith(
            () => AppLocaleController(storage: storage),
          ),
        ],
      );

      final state = await container.read(appLocaleControllerProvider.future);

      expect(state.locale, AppLocaleController.fallbackLocale);
      expect(state.followsSystem, isTrue);
      expect(await storage.read(languageKey), isNull);
    },
  );

  test('returns the fallback locale when storage read throws', () async {
    final storage = _ThrowingStorage();

    final container = ProviderContainer(
      overrides: [
        appLocaleControllerProvider.overrideWith(
          () => AppLocaleController(storage: storage),
        ),
      ],
    );

    final state = await container.read(appLocaleControllerProvider.future);

    expect(state.locale, AppLocaleController.fallbackLocale);
    expect(state.followsSystem, isFalse);
  });

  test(
    'setLocale persists the chosen language and clears followsSystem',
    () async {
      binding.platformDispatcher.localeTestValue = const Locale('en', 'US');
      final storage = MemorySecureStorageService();

      final container = ProviderContainer(
        overrides: [
          appLocaleControllerProvider.overrideWith(
            () => AppLocaleController(storage: storage),
          ),
        ],
      );
      // Touch the provider so it is constructed before setLocale.
      final initial = await container.read(appLocaleControllerProvider.future);
      expect(initial.followsSystem, isTrue);

      await container
          .read(appLocaleControllerProvider.notifier)
          .setLocale(const Locale('th'));

      final next = container.read(appLocaleControllerProvider).asData!.value;
      expect(next.locale, const Locale('th'));
      expect(next.followsSystem, isFalse);
      expect(await storage.read(languageKey), 'th');
    },
  );

  test(
    'followSystemLocale clears the stored language and adopts the device',
    () async {
      binding.platformDispatcher.localeTestValue = const Locale('th', 'TH');
      final storage = MemorySecureStorageService();
      await storage.write(languageKey, 'en');

      final container = ProviderContainer(
        overrides: [
          appLocaleControllerProvider.overrideWith(
            () => AppLocaleController(storage: storage),
          ),
        ],
      );
      // Sanity check: starts in the explicit "en" state.
      final initial = await container.read(appLocaleControllerProvider.future);
      expect(initial.locale, const Locale('en'));
      expect(initial.followsSystem, isFalse);

      await container
          .read(appLocaleControllerProvider.notifier)
          .followSystemLocale();

      final next = container.read(appLocaleControllerProvider).asData!.value;
      expect(next.locale, AppLocaleController.fallbackLocale);
      expect(next.followsSystem, isTrue);
      expect(await storage.read(languageKey), isNull);
    },
  );
}

class _ThrowingStorage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => throw StateError('storage down');

  @override
  Future<void> write(String key, String value) async {
    throw StateError('storage down');
  }

  @override
  Future<void> delete(String key) async => throw StateError('storage down');

  @override
  Future<void> deleteAll() async => throw StateError('storage down');
}
