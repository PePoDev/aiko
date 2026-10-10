import 'dart:async';

import '../core/offline/offline_user_context.dart';
import '../core/firebase/firebase_backend.dart';
import '../features/onboarding/application/complete_onboarding.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/settings/data/profile_repository.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../brick/repository.dart';
import '../core/config/app_config.dart';
import '../core/notifications/transaction_reminder_service.dart';
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
    await FirebaseBackend.initialize(config);
    await AikoBrickRepository.configure(config);
    // Resolve once before concurrent providers start, so a fresh installation
    // cannot create multiple anonymous owners for its initial records.
    await OfflineUserContext().resolveUserId();
    if (!FirebaseBackend.isConfigured) {
      await completeOnboarding(
        accountRepository: AccountRepository(),
        profileRepository: const ProfileRepository(),
      );
    }
    // Warm up the local-notification plugin + timezone DB so transaction
    // reminders can be scheduled. Best-effort; never blocks startup on failure.
    await TransactionReminderService.instance.init();
  }

  /// Surfaces Brick's offline-first sync activity (including silently-queued
  /// remote upsert/hydrate failures) in the debug console so sync problems are
  /// observable. No-op in release builds.
  void _enableBrickSyncLogging() {
    // Startup can be retried; keep a single listener.
    if (!kDebugMode || _brickLogSubscription != null) {
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
