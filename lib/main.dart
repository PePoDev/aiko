import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'features/aiko_character/application/aiko_rive_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional animation runtime; never blocks startup (see AikoRiveRuntime).
  unawaited(AikoRiveRuntime.initialize());
  final bootstrap = AppBootstrap.fromEnvironment();
  await bootstrap.initialize();
  runApp(bootstrap.buildApp());
}
