import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/supabase/supabase_client_provider.dart';
import 'aiko_app.dart';

class AppBootstrap {
  AppBootstrap(this.config);

  factory AppBootstrap.fromEnvironment() {
    return AppBootstrap(AppConfig.fromEnvironment());
  }

  final AppConfig config;

  Future<void> initialize() async {
    await AikoSupabase.initialize(config);
  }

  Widget buildApp() => AikoApp(config: config);
}
