import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';

@ConnectOfflineFirstWithSupabase(
  supabaseConfig: SupabaseSerializable(tableName: 'profiles'),
)
class OfflineProfile extends OfflineFirstWithSupabaseModel {
  OfflineProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.baseCurrency,
    required this.country,
    this.timezone = 'UTC',
    this.preferredTheme = 'system',
    this.aikoCharacterVisibility = 'full',
    this.aikoPersonalitySetting = 'supportive',
    this.onboardingStatus = 'notStarted',
    this.securityStatus = 'notConfigured',
    this.fullName,
    this.gender = 'preferNotToSay',
    this.dateOfBirth,
    this.phoneNumber,
    this.avatarPath,
    this.avatarUrl,
    DateTime? updatedAt,
    this.version = 1,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  @Sqlite(unique: true)
  @Supabase(unique: true)
  final String id;

  final String displayName;
  final String email;
  final String baseCurrency;
  final String country;
  final String timezone;
  final String preferredTheme;
  final String aikoCharacterVisibility;
  final String aikoPersonalitySetting;
  final String onboardingStatus;
  final String securityStatus;

  final String? fullName;

  // Tolerates legacy NULL rows: `gender` was added after profiles already
  // existed, so an upgraded local row has it NULL. A null coalesces to the
  // default instead of throwing on the non-null cast.
  @Sqlite(fromGenerator: 'genderFromColumn(%DATA_PROPERTY%)')
  @Supabase(fromGenerator: 'genderFromColumn(%DATA_PROPERTY%)')
  final String gender;

  @Sqlite(name: 'date_of_birth')
  @Supabase(name: 'date_of_birth')
  final DateTime? dateOfBirth;

  final String? phoneNumber;

  @Sqlite(name: 'avatar_path')
  @Supabase(name: 'avatar_path')
  final String? avatarPath;

  @Sqlite(name: 'avatar_url')
  @Supabase(name: 'avatar_url')
  final String? avatarUrl;

  @Sqlite(name: 'updated_at')
  @Supabase(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'version')
  @Supabase(name: 'version', defaultValue: '1')
  final int version;
}

/// Reads `gender`, defaulting legacy NULL rows to 'preferNotToSay'.
String genderFromColumn(Object? raw) => raw is String ? raw : 'preferNotToSay';
