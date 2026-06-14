enum PreferredTheme { system, light, dark }

enum OnboardingStatus { notStarted, inProgress, completed }

enum SecurityStatus { notConfigured, pinEnabled, biometricEnabled, lockedOut }

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.baseCurrency,
    required this.country,
    required this.onboardingStatus,
    required this.securityStatus,
    this.preferredTheme = PreferredTheme.system,
  });

  final String id;
  final String displayName;
  final String email;
  final String baseCurrency;
  final String country;
  final OnboardingStatus onboardingStatus;
  final SecurityStatus securityStatus;
  final PreferredTheme preferredTheme;

  Profile copyWith({
    String? displayName,
    String? email,
    String? baseCurrency,
    String? country,
    OnboardingStatus? onboardingStatus,
    SecurityStatus? securityStatus,
    PreferredTheme? preferredTheme,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      country: country ?? this.country,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      securityStatus: securityStatus ?? this.securityStatus,
      preferredTheme: preferredTheme ?? this.preferredTheme,
    );
  }
}
