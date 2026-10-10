enum PreferredTheme { system, light, dark }

enum SecurityStatus { notConfigured, pinEnabled, biometricEnabled, lockedOut }

enum Gender { preferNotToSay, female, male, nonBinary, other }

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.baseCurrency,
    required this.country,
    required this.securityStatus,
    this.preferredTheme = PreferredTheme.system,
    this.fullName,
    this.gender = Gender.preferNotToSay,
    this.dateOfBirth,
    this.phoneNumber,
    this.avatarPath,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final String baseCurrency;
  final String country;
  final SecurityStatus securityStatus;
  final PreferredTheme preferredTheme;

  final String? fullName;
  final Gender gender;
  final DateTime? dateOfBirth;
  final String? phoneNumber;

  /// Absolute path to the avatar file cached on the device. Always populated
  /// for users who have picked a photo, so the UI can render it instantly
  /// without re-downloading from storage.
  final String? avatarPath;

  /// Public URL of the avatar in Firebase Storage (`avatars/{userId}/...`).
  /// `null` when the user has never picked a photo, or when the upload has
  /// not yet succeeded. Other devices rely on this URL to render the avatar.
  final String? avatarUrl;

  bool get hasAvatar =>
      (avatarPath != null && avatarPath!.isNotEmpty) ||
      (avatarUrl != null && avatarUrl!.isNotEmpty);

  /// Copies with the given fields replaced. The optional fields take a
  /// function so they can be cleared: `copyWith(fullName: () => null)`.
  Profile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? baseCurrency,
    String? country,
    SecurityStatus? securityStatus,
    PreferredTheme? preferredTheme,
    String? Function()? fullName,
    Gender? gender,
    DateTime? Function()? dateOfBirth,
    String? Function()? phoneNumber,
    String? Function()? avatarPath,
    String? Function()? avatarUrl,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      country: country ?? this.country,
      securityStatus: securityStatus ?? this.securityStatus,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      fullName: fullName != null ? fullName() : this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth != null ? dateOfBirth() : this.dateOfBirth,
      phoneNumber: phoneNumber != null ? phoneNumber() : this.phoneNumber,
      avatarPath: avatarPath != null ? avatarPath() : this.avatarPath,
      avatarUrl: avatarUrl != null ? avatarUrl() : this.avatarUrl,
    );
  }
}
