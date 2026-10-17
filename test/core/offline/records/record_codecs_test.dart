import 'package:aiko/core/offline/records/records.dart';
import 'package:flutter_test/flutter_test.dart';

/// Documents as the app has always written them to Firestore. Reading one and
/// writing it back must give the identical map, so existing cloud data and the
/// security rules keep working.
final _documents = <RecordCodec<OfflineRecord>, Map<String, dynamic>>{
  RecordCodecs.accounts: {
    'id': 'acc-1',
    'user_id': 'user-1',
    'name': 'Visa',
    'type': 'creditCard',
    'currency': 'THB',
    'current_balance': '-1250.5',
    'institution': 'KBank',
    'include_in_net_worth': true,
    'is_active': false,
    'details': {
      '_type': 'creditCard',
      'creditLimit': {'amount': '50000', 'currency': 'THB'},
      'statementDay': 25,
      'dueDay': 10,
    },
    'goal_target_amount': null,
    'goal_target_date': null,
    'goal_priority': 'medium',
    'updated_at': '2026-10-01T03:04:05.000Z',
    'version': 3,
  },
  RecordCodecs.categories: {
    'id': 'cat-1',
    'user_id': 'user-1',
    'template_id': 'template-1',
    'name': 'Coffee',
    'type': 'expense',
    'group': 'wants',
    'group_id': 'group-1',
    'parent_id': null,
    'icon': 'coffee',
    'color': '#AA5500',
    'budget_enabled': true,
    'is_active': true,
    'created_at': '2026-06-01T00:00:00.000Z',
    'budget_amount': '3000',
    'budget_currency': 'THB',
    'budget_period': 'weekly',
    'budget_rollover': true,
    'alert_thresholds': [80, 100],
    'updated_at': '2026-10-01T03:04:05.000Z',
    'version': 1,
  },
  RecordCodecs.categoryGroups: {
    'id': 'group-1',
    'user_id': 'user-1',
    'template_id': null,
    'name': 'Treats',
    'icon': 'cake',
    'color': '#123456',
    'sort_order': 4,
    'created_at': null,
    'budget_amount': '5000',
    'budget_currency': 'THB',
    'updated_at': '2026-10-01T03:04:05.000Z',
    'version': 1,
  },
  RecordCodecs.investmentHoldings: {
    'id': 'holding-1',
    'user_id': 'user-1',
    'symbol': 'VTI',
    'asset_class': 'etf',
    'quantity': '12.5',
    'average_cost': '210.10',
    'current_price': '250',
    'currency': 'USD',
    'market_value': '3125',
    'target_allocation_percent': 40.5,
    'created_at': '2026-06-01T00:00:00.000Z',
    'updated_at': '2026-10-01T03:04:05.000Z',
    'version': 2,
  },
  RecordCodecs.profiles: {
    'id': 'user-1',
    'display_name': 'Aiko',
    'email': 'aiko@example.com',
    'base_currency': 'THB',
    'country': 'TH',
    'timezone': 'Asia/Bangkok',
    'preferred_theme': 'dark',
    'aiko_character_visibility': 'full',
    'aiko_personality_setting': 'supportive',
    'security_status': 'notConfigured',
    'full_name': null,
    'gender': 'female',
    'date_of_birth': '1990-01-02T00:00:00.000',
    'phone_number': null,
    'avatar_path': 'avatars/user-1.jpg',
    'avatar_url': null,
    'updated_at': '2026-10-01T03:04:05.000Z',
    'version': 1,
  },
  RecordCodecs.transactions: {
    'id': 'tx-1',
    'user_id': 'user-1',
    'account_id': 'acc-1',
    'type': 'transferOut',
    'amount': '300.25',
    'currency': 'THB',
    'date': '2026-05-24T01:00:00.000',
    'category_id': null,
    'merchant': 'Transfer to Savings',
    'note': '',
    'tags': ['rent', 'monthly'],
    'status': 'posted',
    'is_recurring': true,
    'recurring_frequency': 'monthly',
    'recurring_end_date': '2027-05-24T00:00:00.000',
    'recurring_max_occurrences': 12,
    'recurring_day_of_week': null,
    'recurring_day_of_month': 24,
    'recurring_month_of_year': null,
    'reminder_at': '2026-05-24T09:00:00.000',
    'transfer_group_id': 'pair-1',
    'updated_at': '2026-10-01T03:04:05.000Z',
    'version': 1,
  },
};

void main() {
  group('existing documents read back unchanged', () {
    for (final entry in _documents.entries) {
      test(entry.key.collection, () {
        final codec = entry.key;
        final record = codec.fromRow(entry.value);
        expect(codec.toRow(record), entry.value);
        expect(codec.idOf(record), entry.value['id']);
        expect(
          codec.ownerOf(record),
          entry.value['user_id'] ?? entry.value['id'],
        );
      });
    }
  });

  test('every record type has its codec and collection', () {
    expect(RecordCodecs.all.map((codec) => codec.collection), [
      'accounts',
      'categories',
      'category_groups',
      'investment_holdings',
      'profiles',
      'transactions',
    ]);
    expect(RecordCodecs.of<OfflineTransaction>(), RecordCodecs.transactions);
    final account = RecordCodecs.accounts.fromRow(
      _documents[RecordCodecs.accounts]!,
    );
    expect(RecordCodecs.forRecord(account), RecordCodecs.accounts);
  });

  test('numbers written by other clients come back as decimal strings', () {
    final row = {
      ..._documents[RecordCodecs.accounts]!,
      'current_balance': 1250,
      'goal_target_amount': 5000.5,
    };
    final account = RecordCodecs.accounts.fromRow(row);
    expect(account.currentBalance, '1250');
    expect(account.goalTargetAmount, '5000.5');
  });

  test('a missing version or updated_at falls back to defaults', () {
    final row = Map<String, dynamic>.of(_documents[RecordCodecs.categories]!)
      ..remove('version')
      ..['updated_at'] = null;
    final category = RecordCodecs.categories.fromRow(row);
    expect(category.version, 1);
    expect(category.updatedAt.difference(DateTime.now().toUtc()).inMinutes, 0);
  });

  test('a system group without an owner is owned by nobody', () {
    final group = RecordCodecs.categoryGroups.fromRow({
      ..._documents[RecordCodecs.categoryGroups]!,
      'user_id': null,
    });
    expect(group.ownerId, isNull);
    expect(RecordCodecs.categoryGroups.toRow(group)['user_id'], isNull);
  });
}
