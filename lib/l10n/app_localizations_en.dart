// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aiko';

  @override
  String get homeTab => 'Overview';

  @override
  String get transactionsTab => 'Transactions';

  @override
  String get budgetTab => 'Budget';

  @override
  String get insightsTab => 'Insights';

  @override
  String get aikoTab => 'Aiko';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get learningHubTitle => 'Learning Hub';

  @override
  String get exportTitle => 'Export';

  @override
  String get privacyTitle => 'Profile and privacy';

  @override
  String get aiDisclaimer =>
      'Aiko provides estimates, not certified financial advice.';
}
