import 'package:aiko/brick/brick.g.dart';
import 'package:aiko/brick/models/transaction.model.dart';
import 'package:brick_supabase/brick_supabase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('transaction Supabase serialization preserves selected time', () async {
    final adapter = OfflineTransactionAdapter();
    final provider = SupabaseProvider(
      SupabaseClient('https://offline.aiko.local', 'offline-anon-key'),
      modelDictionary: supabaseModelDictionary,
    );
    final transaction = OfflineTransaction(
      id: '00000000-0000-0000-0000-000000000001',
      userId: '00000000-0000-0000-0000-000000000002',
      accountId: '00000000-0000-0000-0000-000000000003',
      type: 'expense',
      amount: '10',
      currency: 'THB',
      date: DateTime(2026, 5, 24, 1),
    );

    final row = await adapter.toSupabase(transaction, provider: provider);

    expect(row['date'], '2026-05-24T01:00:00.000');
  });
}
