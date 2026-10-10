import 'package:aiko/brick/model_dictionary.dart';
import 'package:aiko/brick/models/transaction.model.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

/// A [DatabaseFactory] that throws on every call: the codec tests only
/// convert maps and never open the database.
class _NeverOpenDatabaseFactory implements DatabaseFactory {
  Never get _never =>
      throw UnsupportedError('This test must not open the SQLite database.');

  @override
  dynamic noSuchMethod(Invocation invocation) => _never;
}

void main() {
  test('transaction Firestore serialization preserves selected time', () async {
    final adapter = OfflineTransactionAdapter();
    final transaction = OfflineTransaction(
      id: '00000000-0000-0000-0000-000000000001',
      userId: '00000000-0000-0000-0000-000000000002',
      accountId: '00000000-0000-0000-0000-000000000003',
      type: 'expense',
      amount: '10',
      currency: 'THB',
      date: DateTime(2026, 5, 24, 1),
    );

    final row = await adapter.toFirestore(transaction, provider: null);

    expect(row['date'], '2026-05-24T01:00:00.000');
  });

  test('transfer group id round-trips through Firestore and SQLite', () async {
    final adapter = OfflineTransactionAdapter();
    final transaction = OfflineTransaction(
      id: '00000000-0000-0000-0000-000000000001',
      userId: '00000000-0000-0000-0000-000000000002',
      accountId: '00000000-0000-0000-0000-000000000003',
      type: 'transferOut',
      amount: '10',
      currency: 'THB',
      date: DateTime(2026, 5, 24, 1),
      transferGroupId: 'group-1',
    );

    final firestore = await adapter.toFirestore(transaction, provider: null);
    expect(firestore['transfer_group_id'], 'group-1');
    final fromFirestore = await adapter.fromFirestore(
      firestore,
      provider: null,
    );
    expect(fromFirestore.transferGroupId, 'group-1');

    final legacy = Map<String, dynamic>.of(firestore)
      ..remove('transfer_group_id');
    expect(
      (await adapter.fromFirestore(legacy, provider: null)).transferGroupId,
      isNull,
    );
  });

  test('a negative adjustment amount survives the Firestore codec', () async {
    final adapter = OfflineTransactionAdapter();
    final transaction = OfflineTransaction(
      id: '00000000-0000-0000-0000-000000000004',
      userId: '00000000-0000-0000-0000-000000000002',
      accountId: '00000000-0000-0000-0000-000000000003',
      type: 'adjustment',
      amount: '-1500.5',
      currency: 'THB',
      date: DateTime(2026, 5, 24),
    );

    final row = await adapter.toFirestore(transaction, provider: null);
    final back = await adapter.fromFirestore(row, provider: null);
    expect(back.amount, '-1500.5');
    expect(back.type, 'adjustment');
  });

  test('transfer group id round-trips through SQLite', () async {
    final adapter = OfflineTransactionAdapter();
    final provider = SqliteProvider(
      'never-opened.sqlite',
      databaseFactory: _NeverOpenDatabaseFactory(),
      modelDictionary: sqliteModelDictionary,
    );
    final transaction = OfflineTransaction(
      id: '00000000-0000-0000-0000-000000000001',
      userId: '00000000-0000-0000-0000-000000000002',
      accountId: '00000000-0000-0000-0000-000000000003',
      type: 'transferIn',
      amount: '10',
      currency: 'THB',
      date: DateTime(2026, 5, 24, 1),
      transferGroupId: 'group-1',
    );

    final row = await adapter.toSqlite(transaction, provider: provider);
    expect(row['transfer_group_id'], 'group-1');
    final back = await adapter.fromSqlite({
      ...row,
      '_brick_id': 1,
    }, provider: provider);
    expect(back.transferGroupId, 'group-1');
  });
}
