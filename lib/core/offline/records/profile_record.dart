import 'package:timezone/timezone.dart' as tz;

import 'record_codec.dart';

/// The timezone a new profile is saved with: this device's (an IANA name,
/// known once the reminder service has loaded the timezone database), else
/// Thailand's, the app's default country. Profiles made with and without an
/// account get the same one.
String defaultProfileTimezone() {
  String? local;
  try {
    local = tz.local.name;
  } catch (_) {
    // The timezone database isn't loaded (web, or before startup).
  }
  // Before (or without) loading, the package reports UTC for every device.
  if (local != null &&
      local.isNotEmpty &&
      (local != 'UTC' || DateTime.now().timeZoneOffset == Duration.zero)) {
    return local;
  }
  return 'Asia/Bangkok';
}

class OfflineProfile implements OfflineRecord {
  OfflineProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.baseCurrency,
    required this.country,
    String? timezone,
    this.preferredTheme = 'system',
    this.aikoCharacterVisibility = 'full',
    this.aikoPersonalitySetting = 'supportive',
    this.securityStatus = 'notConfigured',
    this.fullName,
    this.gender = 'preferNotToSay',
    this.dateOfBirth,
    this.phoneNumber,
    this.avatarPath,
    this.avatarUrl,
    DateTime? updatedAt,
    this.version = 1,
  }) : timezone = timezone ?? defaultProfileTimezone(),
       updatedAt = updatedAt ?? DateTime.now().toUtc();

  /// The user's id: a profile belongs to the user it describes.
  @override
  final String id;

  final String displayName;
  final String email;
  final String baseCurrency;
  final String country;
  final String timezone;
  final String preferredTheme;
  final String aikoCharacterVisibility;
  final String aikoPersonalitySetting;
  final String securityStatus;

  final String? fullName;

  final String gender;

  final DateTime? dateOfBirth;

  final String? phoneNumber;

  final String? avatarPath;

  final String? avatarUrl;

  final DateTime updatedAt;

  final int version;

  @override
  String? get ownerId => id;
}

/// Reads `gender`, defaulting missing values to 'preferNotToSay'.
String genderFromColumn(Object? raw) => raw is String ? raw : 'preferNotToSay';

class ProfileCodec extends RecordCodec<OfflineProfile> {
  const ProfileCodec();

  @override
  String get collection => 'profiles';

  @override
  OfflineProfile fromRow(Map<String, dynamic> row) => OfflineProfile(
    id: row['id'] as String,
    displayName: row['display_name'] as String,
    email: row['email'] as String,
    baseCurrency: row['base_currency'] as String,
    country: row['country'] as String,
    timezone: row['timezone'] as String?,
    preferredTheme: row['preferred_theme'] as String,
    aikoCharacterVisibility: row['aiko_character_visibility'] as String,
    aikoPersonalitySetting: row['aiko_personality_setting'] as String,
    securityStatus: row['security_status'] as String,
    fullName: row['full_name'] as String?,
    gender: genderFromColumn(row['gender']),
    dateOfBirth: dateFromRow(row['date_of_birth']),
    phoneNumber: row['phone_number'] as String?,
    avatarPath: row['avatar_path'] as String?,
    avatarUrl: row['avatar_url'] as String?,
    updatedAt: dateFromRow(row['updated_at']),
    version: row['version'] as int? ?? 1,
  );

  @override
  Map<String, dynamic> toRow(OfflineProfile record) => {
    'id': record.id,
    'display_name': record.displayName,
    'email': record.email,
    'base_currency': record.baseCurrency,
    'country': record.country,
    'timezone': record.timezone,
    'preferred_theme': record.preferredTheme,
    'aiko_character_visibility': record.aikoCharacterVisibility,
    'aiko_personality_setting': record.aikoPersonalitySetting,
    'security_status': record.securityStatus,
    'full_name': record.fullName,
    'gender': record.gender,
    'date_of_birth': record.dateOfBirth?.toIso8601String(),
    'phone_number': record.phoneNumber,
    'avatar_path': record.avatarPath,
    'avatar_url': record.avatarUrl,
    'updated_at': record.updatedAt.toIso8601String(),
    'version': record.version,
  };
}
