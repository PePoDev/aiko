import 'package:flutter/widgets.dart';

import '../../../core/config/app_config.dart';
import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/profile.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../l10n/l10n.dart';
import '../domain/profile.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<Profile> load() async {
    final userId = await OfflineUserContext().resolveUserId();
    final store = OfflineStore();
    final profiles = await store.get<OfflineProfile>(
      query: Query.where('id', userId, limit1: true),
      policy: store.canSyncRemote
          ? OfflineReadPolicy.awaitRemoteWhenNoneExist
          : OfflineReadPolicy.localOnly,
    );

    if (profiles.isEmpty) {
      final email = FirebaseBackend.auth?.currentUser?.email ?? '';
      final profile = Profile(
        id: userId,
        displayName: email.contains('@')
            ? email.split('@').first
            : currentL10n().profileDefaultDisplayName,
        email: email,
        baseCurrency: kDefaultBaseCurrency,
        country: kDefaultCountry,
        securityStatus: SecurityStatus.notConfigured,
        preferredTheme: resolveInitialTheme(),
      );
      // Signed in, the profile document is created once, at sign-in
      // (AuthRepository.ensureProfileAndDefaultsExist). Writing one here
      // would re-create the document of an account that is being deleted;
      // the user's first Save stores it if it's still missing.
      if (store.canSyncRemote) return profile;
      return save(profile);
    }

    return profiles.first.toDomain();
  }

  Future<Profile> save(Profile profile) async {
    final userId = await OfflineUserContext().resolveUserId();
    final profileWithUser = profile.copyWith(id: userId);
    final saved = await OfflineStore().upsert(profileWithUser.toOffline());
    return saved.toDomain();
  }

  /// Resolves the device's current platform brightness to an explicit
  /// [PreferredTheme] (light or dark) used to seed a first-launch profile.
  /// `system` is intentionally avoided so the user's first-launch intent is
  /// preserved even if the device theme later changes; they can still switch
  /// back to "System" from the Appearance settings at any time. Reads through
  /// [WidgetsBinding.platformDispatcher] so the test binding's
  /// `platformBrightnessTestValue` is honored in tests.
  static PreferredTheme resolveInitialTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark
        ? PreferredTheme.dark
        : PreferredTheme.light;
  }
}
