import 'package:aiko/app/aiko_app.dart';
import 'package:aiko/core/config/app_config.dart';
import 'package:flutter/widgets.dart';

Widget buildTestApp() {
  return const AikoApp(
    config: AppConfig(
      supabaseUrl: '',
      supabaseAnonKey: '',
      environment: 'test',
      enableSupabase: false,
    ),
  );
}
