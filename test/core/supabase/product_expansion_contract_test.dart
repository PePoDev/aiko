import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const expansionTables = [
    'aiko_character_profiles',
    'credit_card_profiles',
    'debt_loan_plans',
    'assets',
    'investment_holdings',
    'tax_records',
    'accounting_records',
    'course_lessons',
    'device_sessions',
    'trips',
    'optimization_suggestions',
    'subscription_plans',
  ];

  test('product expansion schema creates roadmap tables', () {
    final schema = _migrationSql().toLowerCase();

    for (final table in expansionTables) {
      expect(schema, contains('create table public.$table'));
      expect(
        schema,
        contains(
          'add constraint ${table}_user_id_fkey foreign key (user_id) '
          'references public.profiles(id)',
        ),
      );
    }
  });

  test('product expansion RLS protects every user-owned table', () {
    final rls = _migrationSql().toLowerCase();

    for (final table in expansionTables) {
      expect(
        rls,
        contains('alter table public.$table enable row level security'),
      );
      expect(
        rls,
        contains('grant all on table public.$table to authenticated'),
      );
    }

    expect(rls, contains('( select auth.uid() as uid) = user_id'));
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
