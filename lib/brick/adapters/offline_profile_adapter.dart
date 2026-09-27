// SQLite schema compatibility and Firestore document codec. Keep field round-trip tests in sync.
part of '../model_dictionary.dart';

Future<OfflineProfile> _$OfflineProfileFromFirestore(
  Map<String, dynamic> data, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
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
    version: data['version'] as int? ?? 1,
  );
}

Future<Map<String, dynamic>> _$OfflineProfileToFirestore(
  OfflineProfile instance, {
  Object? provider,
  ModelRepository<SqliteModel>? repository,
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
  ModelRepository<SqliteModel>? repository,
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
  ModelRepository<SqliteModel>? repository,
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
class OfflineProfileAdapter extends FirestoreAdapter<OfflineProfile> {
  OfflineProfileAdapter();

  @override
  final collectionName = 'profiles';
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
  Future<OfflineProfile> fromFirestore(
    Map<String, dynamic> input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineProfileFromFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toFirestore(
    OfflineProfile input, {
    provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineProfileToFirestore(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<OfflineProfile> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineProfileFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    OfflineProfile input, {
    required provider,
    covariant ModelRepository<SqliteModel>? repository,
  }) async => await _$OfflineProfileToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
