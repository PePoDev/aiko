import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'app/page_reload.dart';
import 'app/startup_error_app.dart';
import 'app/startup_guard.dart';
import 'features/aiko_character/application/aiko_rive_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional animation runtime; never blocks startup (see AikoRiveRuntime).
  unawaited(AikoRiveRuntime.initialize());
  final bootstrap = AppBootstrap.fromEnvironment();
  final startup = StartupGuard(
    bootstrap.initialize,
    onLateError: (error, stackTrace) => debugPrint(
      '[aiko] startup failed after the slow-start screen: $error\n$stackTrace',
    ),
  );
  await _start(bootstrap, startup);
}

/// Starts the app, or shows [StartupErrorApp] (with Retry) when startup
/// fails or stalls, instead of leaving a blank screen.
Future<void> _start(AppBootstrap bootstrap, StartupGuard startup) async {
  try {
    await startup.run();
  } catch (error, stackTrace) {
    final stillStarting = startup.running;
    if (stillStarting != null) {
      debugPrint('[aiko] startup is slow; still waiting for it ($error)');
    } else {
      debugPrint('[aiko] startup failed: $error\n$stackTrace');
    }
    runApp(
      StartupErrorApp(
        onRetry: () => _retry(bootstrap, startup),
        stillStarting: stillStarting,
      ),
    );
    return;
  }
  runApp(bootstrap.buildApp());
}

/// Retry: a start that is only slow is waited for, not thrown away. On the
/// web, one that failed or looks stuck starts over with a fresh page: what it
/// leaves behind (a failed SDK download that never returns, a database worker
/// that didn't load) can't be retried in place. The app runs it again, or
/// keeps waiting for one still running.
Future<void> _retry(AppBootstrap bootstrap, StartupGuard startup) async {
  await startup.waitUnlessStuck();
  if (!startup.done && reloadPage()) return;
  await _start(bootstrap, startup);
}
