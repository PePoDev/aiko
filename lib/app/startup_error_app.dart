import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/l10n.dart';
import '../shared/widgets/screen_states.dart';
import '../theme/aiko_theme.dart';
import 'locale_controller.dart';
import 'page_reload.dart';

/// Shown instead of the app when startup fails (for example, the local
/// database can't be opened) or takes too long, so the user sees what
/// happened and can retry instead of a blank screen. Uses the device
/// language; the saved language preference isn't readable yet.
class StartupErrorApp extends StatefulWidget {
  const StartupErrorApp({required this.onRetry, this.stillStarting, super.key});

  /// Runs startup again; it replaces this app when it succeeds.
  final Future<void> Function() onRetry;

  /// Startup that timed out but is still running (see `StartupGuard`). When
  /// it finishes, the app continues on its own.
  final Future<void>? stillStarting;

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  var _retrying = false;
  var _stalled = false;

  @override
  void initState() {
    super.initState();
    _watchStartup();
  }

  @override
  void didUpdateWidget(StartupErrorApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.stillStarting, widget.stillStarting)) {
      _watchStartup();
    }
  }

  /// Continues once a slow startup finishes; a failure waits for Retry,
  /// which then starts over.
  void _watchStartup() {
    final starting = widget.stillStarting;
    _stalled = starting != null;
    starting?.then<void>(
      (_) {
        if (!mounted || !identical(widget.stillStarting, starting)) return;
        _stalled = false;
        if (!_retrying) _retry();
      },
      onError: (Object _) {
        if (identical(widget.stillStarting, starting)) _stalled = false;
      },
    );
  }

  Future<void> _retry() async {
    // A stalled web start (say, a download that failed and never returns)
    // can't be resumed in place; reloading the page starts it over.
    if (_stalled && reloadPage()) return;
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
    final slow = widget.stillStarting != null;
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
            title: slow ? l10n.webStartupSlowTitle : l10n.startupFailedTitle,
            message: slow
                ? l10n.webStartupSlowMessage
                : l10n.startupFailedMessage,
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
