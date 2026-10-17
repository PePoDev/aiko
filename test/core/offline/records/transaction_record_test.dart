import 'package:aiko/core/offline/records/records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = RecordCodecs.transactions;

  OfflineTransaction transaction({
    String type = 'expense',
    String amount = '10',
    String? transferGroupId,
    List<String> tags = const [],
  }) => OfflineTransaction(
    id: '00000000-0000-0000-0000-000000000001',
    userId: '00000000-0000-0000-0000-000000000002',
    accountId: '00000000-0000-0000-0000-000000000003',
    type: type,
    amount: amount,
    currency: 'THB',
    date: DateTime(2026, 5, 24, 1),
    transferGroupId: transferGroupId,
    tags: tags,
  );

  test('serialization preserves the selected local time', () {
    final row = codec.toRow(transaction());

    expect(row['date'], '2026-05-24T01:00:00.000');
    expect(codec.fromRow(row).date, DateTime(2026, 5, 24, 1));
  });

  test('transfer group id round-trips; legacy rows have none', () {
    final row = codec.toRow(
      transaction(type: 'transferOut', transferGroupId: 'group-1'),
    );
    expect(row['transfer_group_id'], 'group-1');
    expect(codec.fromRow(row).transferGroupId, 'group-1');

    final legacy = Map<String, dynamic>.of(row)..remove('transfer_group_id');
    expect(codec.fromRow(legacy).transferGroupId, isNull);
  });

  test('a negative adjustment amount survives the codec', () {
    final back = codec.fromRow(
      codec.toRow(transaction(type: 'adjustment', amount: '-1500.5')),
    );
    expect(back.amount, '-1500.5');
    expect(back.type, 'adjustment');
  });

  test('tags are a list of strings in the row and back', () {
    final row = codec.toRow(transaction(tags: ['food', 'trip']));
    expect(row['tags'], ['food', 'trip']);
    // Rows decoded from JSON hold untyped lists.
    final decoded = {
      ...row,
      'tags': <dynamic>['food', 'trip'],
    };
    expect(codec.fromRow(decoded).tags, ['food', 'trip']);
  });
}
