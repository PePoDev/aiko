import 'package:aiko/brick/model_dictionary.dart';
import 'package:aiko/brick/models/account.model.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

/// A [DatabaseFactory] that throws on every call. Used to construct a real
/// [SqliteProvider] for tests that never open the database (e.g. when the
/// adapter's fromSqlite method only converts a Map).
class _NeverOpenDatabaseFactory implements DatabaseFactory {
  Never get _never =>
      throw UnsupportedError('This test must not open the SQLite database.');

  @override
  dynamic noSuchMethod(Invocation invocation) => _never;
}

void main() {
  group('accountDetailsFromFirestore', () {
    test('null returns empty json object string', () {
      expect(accountDetailsFromFirestore(null), '{}');
    });

    test('empty string returns empty json object string', () {
      expect(accountDetailsFromFirestore(''), '{}');
    });

    test('plain string is preserved as-is', () {
      expect(accountDetailsFromFirestore('{"foo":1}'), '{"foo":1}');
    });

    test('Map is encoded as a json string', () {
      expect(
        accountDetailsFromFirestore(<String, dynamic>{'foo': 1}),
        '{"foo":1}',
      );
    });

    test('non-string/non-Map falls back to empty', () {
      expect(accountDetailsFromFirestore(42), '{}');
    });
  });

  group('accountDetailsToFirestore', () {
    test('empty string returns empty Map', () {
      expect(accountDetailsToFirestore(''), <String, dynamic>{});
    });

    test('valid json string is decoded to Map', () {
      expect(accountDetailsToFirestore('{"foo":1}'), <String, dynamic>{
        'foo': 1,
      });
    });

    test('invalid json falls back to empty Map', () {
      expect(accountDetailsToFirestore('not json'), <String, dynamic>{});
    });
  });

  group('accountDetailsFromSqlite', () {
    test('null returns empty json object string (legacy row regression)', () {
      expect(accountDetailsFromSqlite(null), '{}');
    });

    test('non-String value returns empty json object string', () {
      expect(accountDetailsFromSqlite(42), '{}');
    });

    test('String value is preserved as-is', () {
      expect(accountDetailsFromSqlite('{"foo":1}'), '{"foo":1}');
    });
  });

  group('OfflineAccountAdapter round-trip', () {
    final sqliteProvider = SqliteProvider(
      'unused',
      databaseFactory: _NeverOpenDatabaseFactory(),
      modelDictionary: sqliteModelDictionary,
    );
    final adapter = OfflineAccountAdapter();

    test('SQLite read tolerates details_json = NULL (legacy row)', () async {
      final account = await adapter.fromSqlite(<String, dynamic>{
        '_brick_id': 1,
        'id': '11111111-1111-1111-1111-111111111111',
        'user_id': '22222222-2222-2222-2222-222222222222',
        'name': 'Legacy Cash',
        'type': 'cash',
        'currency': 'USD',
        'current_balance': '0',
        'institution': null,
        'include_in_net_worth': 1,
        'is_active': 1,
        'details_json': null,
        'goal_target_amount': null,
        'goal_target_date': null,
        'goal_priority': 'medium',
        'updated_at': '1970-01-01T00:00:00.000Z',
        'deleted_at': null,
        'version': 1,
      }, provider: sqliteProvider);
      expect(account.detailsJson, '{}');
    });

    test('Firestore read tolerates details = NULL (legacy row)', () async {
      final account = await adapter.fromFirestore(<String, dynamic>{
        'id': '11111111-1111-1111-1111-111111111111',
        'user_id': '22222222-2222-2222-2222-222222222222',
        'name': 'Legacy Cash',
        'type': 'cash',
        'currency': 'USD',
        'current_balance': '0',
        'institution': null,
        'include_in_net_worth': true,
        'is_active': true,
        'details': null,
        'goal_target_amount': null,
        'goal_target_date': null,
        'goal_priority': 'medium',
        'updated_at': null,
        'deleted_at': null,
        'version': 1,
      }, provider: null);
      expect(account.detailsJson, '{}');
    });

    test('Firestore write encodes detailsJson Map as jsonb', () async {
      final row = await adapter.toFirestore(
        OfflineAccount(
          id: '11111111-1111-1111-1111-111111111111',
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'Card',
          type: 'card',
          currency: 'USD',
          currentBalance: '0',
          detailsJson: '{"limit":5000}',
        ),
        provider: null,
      );
      expect(row['details'], <String, dynamic>{'limit': 5000});
    });

    test('Firestore write tolerates default detailsJson', () async {
      final row = await adapter.toFirestore(
        OfflineAccount(
          id: '11111111-1111-1111-1111-111111111111',
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'Card',
          type: 'card',
          currency: 'USD',
          currentBalance: '0',
        ),
        provider: null,
      );
      expect(row['details'], <String, dynamic>{});
    });
  });
}
