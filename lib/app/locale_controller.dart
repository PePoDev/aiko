import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/secure_storage_service.dart';

final appLocaleControllerProvider =
    AsyncNotifierProvider<AppLocaleController, Locale>(() {
      return AppLocaleController();
    });

class AppLocaleController extends AsyncNotifier<Locale> {
  AppLocaleController({SecureStorageService? storage})
    : _storage = storage ?? FlutterSecureStorageService();

  static const _languageKey = 'aiko_language_code';
  static const fallbackLocale = Locale('th');

  final SecureStorageService _storage;

  @override
  Future<Locale> build() async {
    try {
      final languageCode = await _storage.read(_languageKey);
      return localeFor(languageCode);
    } catch (_) {
      return fallbackLocale;
    }
  }

  Future<void> setLocale(Locale locale) async {
    final supportedLocale = localeFor(locale.languageCode);
    state = AsyncData(supportedLocale);
    try {
      await _storage.write(_languageKey, supportedLocale.languageCode);
    } catch (_) {
      // Locale changes should still work for the current session if storage is
      // temporarily unavailable, such as during widget tests.
    }
  }

  static Locale localeFor(String? languageCode) {
    return switch (languageCode) {
      'en' => const Locale('en'),
      'th' => const Locale('th'),
      _ => fallbackLocale,
    };
  }
}
