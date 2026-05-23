import 'package:flutter/widgets.dart';

import '../brick/repository.dart';
import '../core/config/app_config.dart';
import 'aiko_app.dart';

class AppBootstrap {
  AppBootstrap(this.config);

  factory AppBootstrap.fromEnvironment() {
    return AppBootstrap(AppConfig.fromEnvironment());
  }

  final AppConfig config;

  Future<void> initialize() async {
    await AikoBrickRepository.configure(config);
  }

  Widget buildApp() => AikoApp(config: config);
}
