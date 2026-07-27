import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'app/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rive.RiveNative.init();
  final bootstrap = AppBootstrap.fromEnvironment();
  await bootstrap.initialize();
  runApp(bootstrap.buildApp());
}
