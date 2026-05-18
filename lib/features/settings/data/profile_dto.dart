import '../domain/profile.dart';

class ProfileDto {
  const ProfileDto(this.json);

  final Map<String, dynamic> json;

  Profile toDomain() {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Aiko user',
      email: json['email'] as String? ?? '',
      baseCurrency: json['base_currency'] as String? ?? 'USD',
      country: json['country'] as String? ?? 'US',
      aiConsentEnabled: json['ai_consent_enabled'] as bool? ?? false,
      onboardingStatus: OnboardingStatus.values.byName(
        json['onboarding_status'] as String? ?? 'notStarted',
      ),
      securityStatus: SecurityStatus.values.byName(
        json['security_status'] as String? ?? 'notConfigured',
      ),
    );
  }

  static Map<String, dynamic> fromDomain(Profile profile) => {
    'id': profile.id,
    'display_name': profile.displayName,
    'email': profile.email,
    'base_currency': profile.baseCurrency,
    'country': profile.country,
    'ai_consent_enabled': profile.aiConsentEnabled,
    'onboarding_status': profile.onboardingStatus.name,
    'security_status': profile.securityStatus.name,
  };
}
