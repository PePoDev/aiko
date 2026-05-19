import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = AppBootstrap.fromEnvironment();
  if (bootstrap.config.supabaseUrl.isEmpty) {
    debugPrint('Aiko startup: SUPABASE_URL is empty (env not loaded).');
  } else {
    debugPrint('Aiko startup: SUPABASE_URL=${bootstrap.config.supabaseUrl}');
  }
  await bootstrap.initialize();
  runApp(bootstrap.buildApp());
}
