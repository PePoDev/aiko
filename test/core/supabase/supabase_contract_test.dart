import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrations include RLS and storage ownership policies', () {
    final rls = File(
      'supabase/migrations/002_initial_product_rls.sql',
    ).readAsStringSync();
    final storage = File(
      'supabase/migrations/003_storage_buckets_and_policies.sql',
    ).readAsStringSync();

    expect(rls, contains('enable row level security'));
    expect(rls, contains('auth.uid()'));
    expect(storage, contains('receipts'));
    expect(storage, contains('storage.foldername'));
  });
}
