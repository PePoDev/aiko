import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrations include RLS and storage ownership policies', () {
    final migrations = _migrationSql().toLowerCase();

    expect(migrations, contains('enable row level security'));
    expect(migrations, contains('auth.uid()'));
    expect(migrations, contains('receipts'));
    expect(migrations, contains('storage.foldername'));
    expect(
      migrations,
      contains('grant all on table public.transactions to authenticated'),
    );
  });
}

String _migrationSql() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  return files.map((file) => file.readAsStringSync()).join('\n');
}
