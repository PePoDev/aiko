import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

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
    _enableBrickSyncLogging();
    await AikoBrickRepository.configure(config);
  }

  /// Surfaces Brick's offline-first sync activity (including silently-queued
  /// remote upsert/hydrate failures) in the debug console so sync problems are
  /// observable. No-op in release builds.
  void _enableBrickSyncLogging() {
    if (!kDebugMode) {
      return;
    }
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '[brick] ${record.level.name} ${record.loggerName}: ${record.message}',
      );
    });
  }

  Widget buildApp() => AikoApp(config: config);
}
