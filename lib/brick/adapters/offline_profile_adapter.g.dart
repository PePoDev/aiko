// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<OfflineProfile> _$OfflineProfileFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineProfile(
    id: data['id'] as String,
    displayName: data['display_name'] as String,
    email: data['email'] as String,
    baseCurrency: data['base_currency'] as String,
    country: data['country'] as String,
    timezone: data['timezone'] as String,
    preferredTheme: data['preferred_theme'] as String,
    aikoCharacterVisibility: data['aiko_character_visibility'] as String,
    aikoPersonalitySetting: data['aiko_personality_setting'] as String,
    aiConsentEnabled: data['ai_consent_enabled'] as bool,
    onboardingStatus: data['onboarding_status'] as String,
    securityStatus: data['security_status'] as String,
  );
}

Future<Map<String, dynamic>> _$OfflineProfileToSupabase(
  OfflineProfile instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'display_name': instance.displayName,
    'email': instance.email,
    'base_currency': instance.baseCurrency,
    'country': instance.country,
    'timezone': instance.timezone,
    'preferred_theme': instance.preferredTheme,
    'aiko_character_visibility': instance.aikoCharacterVisibility,
    'aiko_personality_setting': instance.aikoPersonalitySetting,
    'ai_consent_enabled': instance.aiConsentEnabled,
    'onboarding_status': instance.onboardingStatus,
    'security_status': instance.securityStatus,
  };
}

Future<OfflineProfile> _$OfflineProfileFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return OfflineProfile(
    id: data['id'] as String,
    displayName: data['display_name'] as String,
    email: data['email'] as String,
    baseCurrency: data['base_currency'] as String,
    country: data['country'] as String,
    timezone: data['timezone'] as String,
    preferredTheme: data['preferred_theme'] as String,
    aikoCharacterVisibility: data['aiko_character_visibility'] as String,
    aikoPersonalitySetting: data['aiko_personality_setting'] as String,
    aiConsentEnabled: data['ai_consent_enabled'] == 1,
    onboardingStatus: data['onboarding_status'] as String,
    securityStatus: data['security_status'] as String,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$OfflineProfileToSqlite(
  OfflineProfile instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {
    'id': instance.id,
    'display_name': instance.displayName,
    'email': instance.email,
    'base_currency': instance.baseCurrency,
    'country': instance.country,
    'timezone': instance.timezone,
    'preferred_theme': instance.preferredTheme,
    'aiko_character_visibility': instance.aikoCharacterVisibility,
    'aiko_personality_setting': instance.aikoPersonalitySetting,
    'ai_consent_enabled': instance.aiConsentEnabled ? 1 : 0,
    'onboarding_status': instance.onboardingStatus,
    'security_status': instance.securityStatus,
  };
}

/// Construct a [OfflineProfile]
class OfflineProfileAdapter
    extends OfflineFirstWithSupabaseAdapter<OfflineProfile> {
  OfflineProfileAdapter();

  @override
  final supabaseTableName = 'profiles';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    ),
    'displayName': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'display_name',
    ),
    'email': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'email',
    ),
    'baseCurrency': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'base_currency',
    ),
    'country': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'country',
    ),
    'timezone': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'timezone',
    ),
    'preferredTheme': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'preferred_theme',
    ),
    'aikoCharacterVisibility': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'aiko_character_visibility',
    ),
    'aikoPersonalitySetting': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'aiko_personality_setting',
    ),
    'aiConsentEnabled': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'ai_consent_enabled',
    ),
    'onboardingStatus': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'onboarding_status',
    ),
    'securityStatus': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'security_status',
    ),
  };
  @override
  final ignoreDuplicates = false;
  @override
  final uniqueFields = {'id'};
  @override
  final Map<String, RuntimeSqliteColumnDefinition> fieldsToSqliteColumns = {
    'primaryKey': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: '_brick_id',
      iterable: false,
      type: int,
    ),
    'id': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'id',
      iterable: false,
      type: String,
    ),
    'displayName': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'display_name',
      iterable: false,
      type: String,
    ),
    'email': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'email',
      iterable: false,
      type: String,
    ),
    'baseCurrency': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'base_currency',
      iterable: false,
      type: String,
    ),
    'country': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'country',
      iterable: false,
      type: String,
    ),
    'timezone': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'timezone',
      iterable: false,
      type: String,
    ),
    'preferredTheme': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'preferred_theme',
      iterable: false,
      type: String,
    ),
    'aikoCharacterVisibility': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'aiko_character_visibility',
      iterable: false,
      type: String,
    ),
    'aikoPersonalitySetting': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'aiko_personality_setting',
      iterable: false,
      type: String,
    ),
    'aiConsentEnabled': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'ai_consent_enabled',
      iterable: false,
      type: bool,
    ),
    'onboardingStatus': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'onboarding_status',
      iterable: false,
      type: String,
    ),
    'securityStatus': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'security_status',
      iterable: false,
      type: String,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    OfflineProfile instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `OfflineProfile` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'OfflineProfile';

  @override
  Future<OfflineProfile> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineProfileFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    OfflineProfile input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineProfileToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineProfile> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineProfileFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineProfile input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$OfflineProfileToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
