import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/profile.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/profile.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<Profile> load() async {
    final userId = await OfflineUserContext().resolveUserId();
    final store = OfflineStore();
    final profiles = await store.get<OfflineProfile>(
      query: Query.where('id', userId, limit1: true),
      policy: store.canSyncRemote
          ? OfflineFirstGetPolicy.awaitRemoteWhenNoneExist
          : OfflineFirstGetPolicy.localOnly,
    );

    if (profiles.isEmpty) {
      final email = AikoSupabase.tryClient()?.auth.currentUser?.email ?? '';
      final profile = Profile(
        id: userId,
        displayName: email.contains('@') ? email.split('@').first : 'Aiko User',
        email: email,
        baseCurrency: 'THB',
        country: 'TH',
        aiConsentEnabled: false,
        onboardingStatus: OnboardingStatus.notStarted,
        securityStatus: SecurityStatus.notConfigured,
      );
      return save(profile);
    }

    return profiles.first.toDomain();
  }

  Future<Profile> save(Profile profile) async {
    final userId = await OfflineUserContext().resolveUserId();
    final profileWithUser = Profile(
      id: userId,
      displayName: profile.displayName,
      email: profile.email,
      baseCurrency: profile.baseCurrency,
      country: profile.country,
      aiConsentEnabled: profile.aiConsentEnabled,
      onboardingStatus: profile.onboardingStatus,
      securityStatus: profile.securityStatus,
      preferredTheme: profile.preferredTheme,
    );
    final saved = await OfflineStore().upsert(profileWithUser.toOffline());
    return saved.toDomain();
  }
}
