import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/l10n.dart';
import '../shared/widgets/screen_states.dart';
import '../theme/aiko_theme.dart';
import 'locale_controller.dart';

/// Shown instead of the app when startup fails (for example, the local
/// database can't be opened) or takes too long, so the user sees what
/// happened and can retry instead of a blank screen. Uses the device
/// language; the saved language preference isn't readable yet.
class StartupErrorApp extends StatefulWidget {
  const StartupErrorApp({required this.onRetry, this.stillStarting, super.key});

  /// Runs startup again (on the web by reloading the page), or waits for
  /// [stillStarting] while it is only slow (see
  /// `StartupGuard.waitUnlessStuck`); the app replaces this one once startup
  /// has finished.
  final Future<void> Function() onRetry;

  /// Startup that timed out but is still running (see `StartupGuard`). When
  /// it finishes, the app continues on its own.
  final Future<void>? stillStarting;

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  var _retrying = false;

  /// Whether [StartupErrorApp.stillStarting] failed after all.
  var _failed = false;

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

  /// Continues once a slow startup finishes. If it fails instead, the screen
  /// says so (`StartupGuard` logs the error) and Retry starts over.
  void _watchStartup() {
    final starting = widget.stillStarting;
    _failed = false;
    starting?.then<void>(
      (_) {
        if (!mounted || !identical(widget.stillStarting, starting)) return;
        if (!_retrying) _retry();
      },
      onError: (Object _) {
        if (!mounted || !identical(widget.stillStarting, starting)) return;
        setState(() => _failed = true);
      },
    );
  }

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
    final slow = widget.stillStarting != null && !_failed;
    final retry = FilledButton.icon(
      onPressed: _retrying ? null : _retry,
      icon: _retrying
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: Text(l10n.retry),
    );
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
          child: slow
              ? AikoScreenState(
                  icon: Icons.hourglass_empty,
                  title: l10n.webStartupSlowTitle,
                  // Only the web downloads anything while starting.
                  message: kIsWeb
                      ? l10n.webStartupSlowMessage
                      : l10n.webStartupSlowNativeMessage,
                  action: retry,
                )
              : AikoScreenState.error(
                  title: l10n.startupFailedTitle,
                  message: l10n.startupFailedMessage,
                  action: retry,
                ),
        ),
      ),
    );
  }
}
