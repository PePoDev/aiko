import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const expansionTables = [
    'aiko_character_profiles',
    'import_jobs',
    'export_packages',
    'backup_snapshots',
    'bill_subscriptions',
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
    final schema = File(
      'supabase/migrations/004_product_expansion_schema.sql',
    ).readAsStringSync();

    for (final table in expansionTables) {
      expect(schema, contains('create table if not exists public.$table'));
      expect(
        schema,
        contains('user_id uuid not null references public.profiles'),
      );
    }
  });

  test('product expansion RLS protects every user-owned table', () {
    final rls = File(
      'supabase/migrations/005_product_expansion_rls.sql',
    ).readAsStringSync();

    for (final table in expansionTables) {
      expect(
        rls,
        contains('alter table public.$table enable row level security'),
      );
    }

    expect(rls, contains('auth.uid() = user_id'));
  });
}
