import 'package:flutter/foundation.dart';

import '../offline/offline_data_migrator.dart';

/// Prepares local offline data after a user signs in.
///
/// Current responsibility: reassign rows created while signed out
/// (`local:<uuid>` user ids) to the real Supabase user id so they can sync.
class PostSigninDataPreparer {
  const PostSigninDataPreparer();

  Future<void> prepareForSync(String userId) async {
    try {
      await OfflineDataMigrator().claimAnonymousData(userId);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-sync] offline data prepare skipped: $error');
      }
    }
  }
}
