import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AikoL10n on BuildContext {
  /// Strings for the active language (English or Thai). Every user-facing
  /// string goes through here; see docs/localization.md.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Strings for the app's current language outside the widget tree (for
/// example notifications scheduled in the background, or data seeded at
/// sign-up). `AikoApp` keeps [Intl.defaultLocale] in sync with the selected
/// language; before the app has started, the device language is used.
AppLocalizations currentL10n() {
  final tag =
      Intl.defaultLocale ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final code = tag.split(RegExp('[_-]')).first;
  final supported = AppLocalizations.supportedLocales.any(
    (locale) => locale.languageCode == code,
  );
  return lookupAppLocalizations(Locale(supported ? code : 'en'));
}
