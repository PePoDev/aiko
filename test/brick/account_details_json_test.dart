import 'package:aiko/brick/brick.g.dart';
import 'package:aiko/brick/models/account.model.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  group('accountDetailsFromSupabase', () {
    test('null returns empty json object string', () {
      expect(accountDetailsFromSupabase(null), '{}');
    });

    test('empty string returns empty json object string', () {
      expect(accountDetailsFromSupabase(''), '{}');
    });

    test('plain string is preserved as-is', () {
      expect(accountDetailsFromSupabase('{"foo":1}'), '{"foo":1}');
    });

    test('Map is encoded as a json string', () {
      expect(
        accountDetailsFromSupabase(<String, dynamic>{'foo': 1}),
        '{"foo":1}',
      );
    });

    test('non-string/non-Map falls back to empty', () {
      expect(accountDetailsFromSupabase(42), '{}');
    });
  });

  group('accountDetailsToSupabase', () {
    test('empty string returns empty Map', () {
      expect(accountDetailsToSupabase(''), <String, dynamic>{});
    });

    test('valid json string is decoded to Map', () {
      expect(accountDetailsToSupabase('{"foo":1}'), <String, dynamic>{
        'foo': 1,
      });
    });

    test('invalid json falls back to empty Map', () {
      expect(accountDetailsToSupabase('not json'), <String, dynamic>{});
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
    final supabaseProvider = SupabaseProvider(
      SupabaseClient('https://offline.aiko.local', 'offline-anon-key'),
      modelDictionary: supabaseModelDictionary,
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
      }, provider: sqliteProvider);
      expect(account.detailsJson, '{}');
    });

    test('Supabase read tolerates details = NULL (legacy row)', () async {
      final account = await adapter.fromSupabase(<String, dynamic>{
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
      }, provider: supabaseProvider);
      expect(account.detailsJson, '{}');
    });

    test('Supabase write encodes detailsJson Map as jsonb', () async {
      final row = await adapter.toSupabase(
        OfflineAccount(
          id: '11111111-1111-1111-1111-111111111111',
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'Card',
          type: 'card',
          currency: 'USD',
          currentBalance: '0',
          detailsJson: '{"limit":5000}',
        ),
        provider: supabaseProvider,
      );
      expect(row['details'], <String, dynamic>{'limit': 5000});
    });

    test('Supabase write tolerates default detailsJson', () async {
      final row = await adapter.toSupabase(
        OfflineAccount(
          id: '11111111-1111-1111-1111-111111111111',
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'Card',
          type: 'card',
          currency: 'USD',
          currentBalance: '0',
        ),
        provider: supabaseProvider,
      );
      expect(row['details'], <String, dynamic>{});
    });
  });
}
