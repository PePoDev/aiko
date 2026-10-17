import '../core/storage/synced_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/secure_storage_service.dart';
import '../l10n/app_localizations.dart';

/// Snapshot of the user's language preference exposed to the UI.
///
/// [locale] is the effective locale the app should render with right now.
/// [followsSystem] is `true` when the user has chosen "System default" (or
/// has never made a choice) and the [locale] mirrors the device. When
/// `false`, [locale] is the user's explicit pick.
class AppLocaleState {
  const AppLocaleState({required this.locale, required this.followsSystem});

  final Locale locale;
  final bool followsSystem;

  @override
  bool operator ==(Object other) {
    return other is AppLocaleState &&
        other.locale == locale &&
        other.followsSystem == followsSystem;
  }

  @override
  int get hashCode => Object.hash(locale, followsSystem);
}

final appLocaleControllerProvider =
    AsyncNotifierProvider<AppLocaleController, AppLocaleState>(() {
      return AppLocaleController();
    });

class AppLocaleController extends AsyncNotifier<AppLocaleState> {
  AppLocaleController({SecureStorageService? storage})
    : _storage = storage ?? SyncedPreferences();

  /// The synced preference holding an explicit language choice.
  static const languageKey = 'aiko_language_code';

  /// First entry of [AppLocalizations.supportedLocales] is the safe default
  /// when neither the user's saved preference nor the device locale match a
  /// supported code. Keeping the derivation in one place means a new
  /// translation can be added without also touching this controller.
  static Locale get fallbackLocale => AppLocalizations.supportedLocales.first;

  final SecureStorageService _storage;

  @override
  Future<AppLocaleState> build() async {
    try {
      final languageCode = await _storage.read(languageKey);
      if (languageCode != null) {
        return AppLocaleState(
          locale: localeFor(languageCode),
          followsSystem: false,
        );
      }
      // No explicit preference — follow the device. Do not persist so the app
      // continues to track the device locale on subsequent launches.
      return AppLocaleState(
        locale: localeFor(resolveDeviceLanguageCode()),
        followsSystem: true,
      );
    } catch (_) {
      // Storage unavailable: the device language is the best guess (most
      // people never pick one), not English.
      return AppLocaleState(
        locale: localeFor(resolveDeviceLanguageCode()),
        followsSystem: true,
      );
    }
  }

  Future<void> setLocale(Locale locale) async {
    final supportedLocale = localeFor(locale.languageCode);
    state = AsyncData(
      AppLocaleState(locale: supportedLocale, followsSystem: false),
    );
    try {
      await _storage.write(languageKey, supportedLocale.languageCode);
    } catch (_) {
      // Locale changes should still work for the current session if storage
      // is temporarily unavailable, such as during widget tests.
    }
  }

  /// Switches the controller to "System default" mode: removes the stored
  /// language code and renders the current device locale. The device locale
  /// is read every time [build] runs, so the app tracks the device across
  /// launches and (after the next [build] / app restart) language changes.
  Future<void> followSystemLocale() async {
    final deviceLocale = localeFor(resolveDeviceLanguageCode());
    state = AsyncData(
      AppLocaleState(locale: deviceLocale, followsSystem: true),
    );
    try {
      await _storage.delete(languageKey);
    } catch (_) {
      // Best-effort: the in-memory state still reflects the device locale
      // even if storage is unavailable.
    }
  }

  static Locale localeFor(String? languageCode) {
    return switch (languageCode) {
      'en' => const Locale('en'),
      'th' => const Locale('th'),
      _ => fallbackLocale,
    };
  }

  /// Returns a supported language code derived from the device locale, or
  /// `null` if the device locale is not in [AppLocalizations.supportedLocales].
  /// Exposed for first-launch seeding and tests. Reads through
  /// [WidgetsBinding.platformDispatcher] so the test binding's
  /// `localeTestValue` is honored in widget/unit tests.
  static String? resolveDeviceLanguageCode() {
    final supported = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    if (supported.contains(device.languageCode)) {
      return device.languageCode;
    }
    return null;
  }
}
