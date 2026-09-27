import 'package:aiko/brick/model_dictionary.dart';
import 'package:aiko/brick/models/transaction.model.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
