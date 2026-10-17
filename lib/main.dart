import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'app/startup_error_app.dart';
import 'app/startup_guard.dart';
import 'features/aiko_character/application/aiko_rive_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional animation runtime; never blocks startup (see AikoRiveRuntime).
  unawaited(AikoRiveRuntime.initialize());
  final bootstrap = AppBootstrap.fromEnvironment();
  await _start(bootstrap, StartupGuard(bootstrap.initialize));
}

/// Starts the app, or shows [StartupErrorApp] (with Retry) when startup
/// fails or stalls, instead of leaving a blank screen.
Future<void> _start(AppBootstrap bootstrap, StartupGuard startup) async {
  try {
    await startup.run();
  } catch (error, stackTrace) {
    debugPrint('[aiko] startup failed: $error\n$stackTrace');
    runApp(
      StartupErrorApp(
        onRetry: () => _start(bootstrap, startup),
        stillStarting: startup.running,
      ),
    );
    return;
  }
  runApp(bootstrap.buildApp());
}
