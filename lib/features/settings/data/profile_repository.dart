import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/profile.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<Profile> load() async {
    final session = AikoSupabase.requireSession();
    final row = await session.client
        .from('profiles')
        .select()
        .eq('id', session.userId)
        .maybeSingle();

    if (row == null) {
      final email = session.user.email ?? '';
      final profile = Profile(
        id: session.userId,
        displayName: email.contains('@') ? email.split('@').first : 'Aiko User',
        email: email,
        baseCurrency: 'USD',
        country: 'US',
        aiConsentEnabled: false,
        onboardingStatus: OnboardingStatus.notStarted,
        securityStatus: SecurityStatus.notConfigured,
      );
      return save(profile);
    }

    return _fromRow(Map<String, dynamic>.from(row));
  }

  Future<Profile> save(Profile profile) async {
    final session = AikoSupabase.requireSession();
    final profileWithUser = Profile(
      id: session.userId,
      displayName: profile.displayName,
      email: profile.email,
      baseCurrency: profile.baseCurrency,
      country: profile.country,
      aiConsentEnabled: profile.aiConsentEnabled,
      onboardingStatus: profile.onboardingStatus,
      securityStatus: profile.securityStatus,
      preferredTheme: profile.preferredTheme,
    );

    await session.client.from('profiles').upsert(_toRow(profileWithUser));
    return profileWithUser;
  }

  static Profile _fromRow(Map<String, dynamic> row) {
    final preferredTheme = PreferredTheme.values.firstWhere(
      (item) => item.name == (row['preferred_theme'] as String? ?? 'system'),
      orElse: () => PreferredTheme.system,
    );
    final onboardingStatus = OnboardingStatus.values.firstWhere(
      (item) =>
          item.name == (row['onboarding_status'] as String? ?? 'notStarted'),
      orElse: () => OnboardingStatus.notStarted,
    );
    final securityStatus = SecurityStatus.values.firstWhere(
      (item) =>
          item.name == (row['security_status'] as String? ?? 'notConfigured'),
      orElse: () => SecurityStatus.notConfigured,
    );

    return Profile(
      id: row['id'] as String,
      displayName: row['display_name'] as String? ?? 'Aiko User',
      email: row['email'] as String? ?? '',
      baseCurrency: row['base_currency'] as String? ?? 'USD',
      country: row['country'] as String? ?? 'US',
      aiConsentEnabled: row['ai_consent_enabled'] as bool? ?? false,
      onboardingStatus: onboardingStatus,
      securityStatus: securityStatus,
      preferredTheme: preferredTheme,
    );
  }

  static Map<String, dynamic> _toRow(Profile profile) {
    return {
      'id': profile.id,
      'display_name': profile.displayName,
      'email': profile.email,
      'base_currency': profile.baseCurrency,
      'country': profile.country,
      'ai_consent_enabled': profile.aiConsentEnabled,
      'onboarding_status': profile.onboardingStatus.name,
      'security_status': profile.securityStatus.name,
      'preferred_theme': profile.preferredTheme.name,
    };
  }
}
