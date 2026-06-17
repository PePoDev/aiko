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
    onboardingStatus: data['onboarding_status'] as String,
    securityStatus: data['security_status'] as String,
    fullName: data['full_name'] == null ? null : data['full_name'] as String?,
    gender: genderFromColumn(data['gender']),
    dateOfBirth: data['date_of_birth'] == null
        ? null
        : data['date_of_birth'] == null
        ? null
        : DateTime.tryParse(data['date_of_birth'] as String),
    phoneNumber: data['phone_number'] == null
        ? null
        : data['phone_number'] as String?,
    avatarPath: data['avatar_path'] == null
        ? null
        : data['avatar_path'] as String?,
    avatarUrl: data['avatar_url'] == null
        ? null
        : data['avatar_url'] as String?,
    updatedAt: data['updated_at'] == null
        ? null
        : DateTime.tryParse(data['updated_at'] as String),
    version: data['version'] as int ?? 1,
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
    'onboarding_status': instance.onboardingStatus,
    'security_status': instance.securityStatus,
    'full_name': instance.fullName,
    'gender': instance.gender,
    'date_of_birth': instance.dateOfBirth?.toIso8601String(),
    'phone_number': instance.phoneNumber,
    'avatar_path': instance.avatarPath,
    'avatar_url': instance.avatarUrl,
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
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
    onboardingStatus: data['onboarding_status'] as String,
    securityStatus: data['security_status'] as String,
    fullName: data['full_name'] == null ? null : data['full_name'] as String?,
    gender: genderFromColumn(data['gender']),
    dateOfBirth: data['date_of_birth'] == null
        ? null
        : data['date_of_birth'] == null
        ? null
        : DateTime.tryParse(data['date_of_birth'] as String),
    phoneNumber: data['phone_number'] == null
        ? null
        : data['phone_number'] as String?,
    avatarPath: data['avatar_path'] == null
        ? null
        : data['avatar_path'] as String?,
    avatarUrl: data['avatar_url'] == null
        ? null
        : data['avatar_url'] as String?,
    updatedAt: DateTime.parse(data['updated_at'] as String),
    version: data['version'] as int,
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
    'onboarding_status': instance.onboardingStatus,
    'security_status': instance.securityStatus,
    'full_name': instance.fullName,
    'gender': instance.gender,
    'date_of_birth': instance.dateOfBirth?.toIso8601String(),
    'phone_number': instance.phoneNumber,
    'avatar_path': instance.avatarPath,
    'avatar_url': instance.avatarUrl,
    'updated_at': instance.updatedAt.toIso8601String(),
    'version': instance.version,
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
    'onboardingStatus': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'onboarding_status',
    ),
    'securityStatus': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'security_status',
    ),
    'fullName': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'full_name',
    ),
    'gender': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'gender',
    ),
    'dateOfBirth': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'date_of_birth',
    ),
    'phoneNumber': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'phone_number',
    ),
    'avatarPath': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'avatar_path',
    ),
    'avatarUrl': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'avatar_url',
    ),
    'updatedAt': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'updated_at',
    ),
    'version': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'version',
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
    'fullName': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'full_name',
      iterable: false,
      type: String,
    ),
    'gender': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'gender',
      iterable: false,
      type: String,
    ),
    'dateOfBirth': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'date_of_birth',
      iterable: false,
      type: DateTime,
    ),
    'phoneNumber': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'phone_number',
      iterable: false,
      type: String,
    ),
    'avatarPath': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'avatar_path',
      iterable: false,
      type: String,
    ),
    'avatarUrl': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'avatar_url',
      iterable: false,
      type: String,
    ),
    'updatedAt': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'updated_at',
      iterable: false,
      type: DateTime,
    ),
    'version': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'version',
      iterable: false,
      type: int,
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
