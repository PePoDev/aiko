import '../core/offline/legacy_store_import.dart';
import '../core/offline/offline_user_context.dart';
import '../core/firebase/firebase_backend.dart';
import '../core/storage/local_record_store.dart';
import '../features/onboarding/application/complete_onboarding.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/auth/data/guest_mode.dart';
import '../features/settings/data/profile_repository.dart';

import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/notifications/transaction_reminder_service.dart';
import 'aiko_app.dart';
import 'file_uploads.dart';

class AppBootstrap {
  AppBootstrap(this.config);

  factory AppBootstrap.fromEnvironment() {
    return AppBootstrap(AppConfig.fromEnvironment());
  }

  final AppConfig config;

  Future<void> initialize() async {
    // Independent: Firebase setup and the local record store (open, then
    // import an older app version's database once) run side by side to
    // shorten startup. Both finish before anything reads records.
    await Future.wait([FirebaseBackend.initialize(config), _openLocalStore()]);
    // Resolve once before concurrent providers start, so a fresh installation
    // cannot create multiple anonymous owners for its initial records.
    await OfflineUserContext().resolveUserId();
    // Uploads saved files in the background once signed in and online.
    startFileUploads();
    // Before the first frame: guests open on Home, not Welcome.
    if (FirebaseBackend.isConfigured) await GuestMode.restore();
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

  /// Opens the local record store (startup can be retried; it opens once)
  /// and imports the previous local database into it on first run.
  Future<void> _openLocalStore() async {
    final store = await LocalRecordStore.open();
    await LegacyStoreImport(target: store).run();
  }

  Widget buildApp() => AikoApp(config: config);
}
