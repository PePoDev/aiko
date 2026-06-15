import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../brick/repository.dart';
import '../core/config/app_config.dart';
import '../core/sync/budget_goal_migration.dart';
import 'aiko_app.dart';

class AppBootstrap {
  AppBootstrap(this.config);

  factory AppBootstrap.fromEnvironment() {
    return AppBootstrap(AppConfig.fromEnvironment());
  }

  final AppConfig config;

  StreamSubscription<LogRecord>? _brickLogSubscription;

  Future<void> initialize() async {
    _enableBrickSyncLogging();
    await AikoBrickRepository.configure(config);
    // Budgets -> Categories and Goals -> Accounts one-time merge. Runs after
    // Brick is configured (so the SQLite store is open) and before any
    // providers read from the categories/accounts tables, so the new shape
    // is the only shape the rest of the app sees. No-op once the meta row is
    // set.
    await BudgetGoalMigrator().runIfNeeded();
  }

  /// Surfaces Brick's offline-first sync activity (including silently-queued
  /// remote upsert/hydrate failures) in the debug console so sync problems are
  /// observable. No-op in release builds.
  void _enableBrickSyncLogging() {
    if (!kDebugMode) {
      return;
    }
    Logger.root.level = Level.INFO;
    _brickLogSubscription = Logger.root.onRecord.listen((record) {
      debugPrint(
        '[brick] ${record.level.name} ${record.loggerName}: ${record.message}',
      );
    });
  }

  /// Detach the listener. Tests that re-create the bootstrap can call this to
  /// avoid the prior subscription keeping `Logger.root` alive.
  void dispose() {
    _brickLogSubscription?.cancel();
    _brickLogSubscription = null;
  }

  Widget buildApp() => AikoApp(config: config);
}
