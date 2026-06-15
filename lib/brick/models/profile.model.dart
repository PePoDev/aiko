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
    DateTime? updatedAt,
    this.deletedAt,
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

  @Sqlite(name: 'updated_at')
  @Supabase(name: 'updated_at')
  final DateTime updatedAt;

  @Sqlite(name: 'deleted_at', index: true)
  @Supabase(name: 'deleted_at')
  final DateTime? deletedAt;

  @Sqlite(name: 'version')
  @Supabase(name: 'version', defaultValue: '1')
  final int version;
}
