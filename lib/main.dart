import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = AppBootstrap.fromEnvironment();
  await bootstrap.initialize();
  runApp(bootstrap.buildApp());
}
