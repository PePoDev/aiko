import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/l10n.dart';
import '../shared/widgets/screen_states.dart';
import '../theme/aiko_theme.dart';
import 'locale_controller.dart';

/// Shown instead of the app when startup fails (for example, the local
/// database can't be opened), so the user sees what happened and can retry
/// instead of a blank screen. Uses the device language; the saved language
/// preference isn't readable yet.
class StartupErrorApp extends StatefulWidget {
  const StartupErrorApp({required this.onRetry, super.key});

  /// Runs startup again; it replaces this app when it succeeds.
  final Future<void> Function() onRetry;

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  var _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleController.localeFor(
      AppLocaleController.resolveDeviceLanguageCode(),
    );
    final l10n = lookupAppLocalizations(locale);
    return MaterialApp(
      title: 'Aiko', // l10n-ignore
      theme: AikoTheme.light(),
      darkTheme: AikoTheme.dark(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SafeArea(
          child: AikoScreenState.error(
            title: l10n.startupFailedTitle,
            message: l10n.startupFailedMessage,
            action: FilledButton.icon(
              onPressed: _retrying ? null : _retry,
              icon: _retrying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ),
        ),
      ),
    );
  }
}
