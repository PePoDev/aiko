import 'package:aiko/app/aiko_app.dart';
import 'package:aiko/core/config/app_config.dart';
import 'package:flutter/widgets.dart';

Widget buildTestApp() {
  return const AikoApp(
    config: AppConfig(
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: '',
      environment: 'test',
      enableSupabase: false,
    ),
  );
}
