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
    this.aiConsentEnabled = false,
    this.onboardingStatus = 'notStarted',
    this.securityStatus = 'notConfigured',
  });

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
  final bool aiConsentEnabled;
  final String onboardingStatus;
  final String securityStatus;
}
