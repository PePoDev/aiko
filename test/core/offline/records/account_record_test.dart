import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accountDetailsFromRow', () {
    test('null returns empty json object string', () {
      expect(accountDetailsFromRow(null), '{}');
    });

    test('empty string returns empty json object string', () {
      expect(accountDetailsFromRow(''), '{}');
    });

    test('plain string is preserved as-is', () {
      expect(accountDetailsFromRow('{"foo":1}'), '{"foo":1}');
    });

    test('Map is encoded as a json string', () {
      expect(accountDetailsFromRow(<String, dynamic>{'foo': 1}), '{"foo":1}');
    });

    test('non-string/non-Map falls back to empty', () {
      expect(accountDetailsFromRow(42), '{}');
    });
  });

  group('accountDetailsToRow', () {
    test('empty string returns empty Map', () {
      expect(accountDetailsToRow(''), <String, dynamic>{});
    });

    test('valid json string is decoded to Map', () {
      expect(accountDetailsToRow('{"foo":1}'), <String, dynamic>{'foo': 1});
    });

    test('invalid json falls back to empty Map', () {
      expect(accountDetailsToRow('not json'), <String, dynamic>{});
    });
  });

  group('account codec', () {
    const codec = RecordCodecs.accounts;

    test('reading tolerates details = NULL (legacy document)', () {
      final account = codec.fromRow(<String, dynamic>{
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
        'goal_target_amount': null,
        'goal_target_date': null,
        'goal_priority': null,
        'updated_at': null,
        'version': 1,
      });
      expect(account.detailsJson, '{}');
      expect(account.goalPriority, 'medium');
    });

    test('writing encodes detailsJson as a map', () {
      final row = codec.toRow(
        OfflineAccount(
          id: '11111111-1111-1111-1111-111111111111',
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'Card',
          type: 'card',
          currency: 'USD',
          currentBalance: '0',
          detailsJson: '{"limit":5000}',
        ),
      );
      expect(row['details'], <String, dynamic>{'limit': 5000});
    });

    test('writing tolerates default detailsJson', () {
      final row = codec.toRow(
        OfflineAccount(
          id: '11111111-1111-1111-1111-111111111111',
          userId: '22222222-2222-2222-2222-222222222222',
          name: 'Card',
          type: 'card',
          currency: 'USD',
          currentBalance: '0',
        ),
      );
      expect(row['details'], <String, dynamic>{});
    });
  });

  group('account details mapping', () {
    test('round-trips every variant', () {
      final samples = <AccountDetails>[
        const CashDetails(),
        const BankDetails(),
        const EWalletDetails(),
        CreditCardDetails(
          creditLimit: Money.parse('5000', 'USD'),
          statementDay: 15,
          dueDay: 5,
          aprPercent: 19.99,
          rewardsType: RewardsType.cashback,
          annualFee: Money.parse('95', 'USD'),
          minimumPayment: Money.parse('25', 'USD'),
        ),
        LoanDetails(
          loanType: LoanType.auto,
          principal: Money.parse('20000', 'USD'),
          interestRatePercent: 5.5,
          termMonths: 60,
          monthlyPayment: Money.parse('380', 'USD'),
          nextDueDate: DateTime.utc(2026, 8, 1),
        ),
        const InvestmentDetails(accountNumberLast4: '9999'),
        const AssetDetails(assetClass: AssetClass.realEstate, notes: 'condo'),
        const LiabilityDetails(liabilityType: 'overdraft'),
        const OtherDetails(notes: 'misc'),
      ];
      for (final s in samples) {
        final json = accountDetailsToJson(s);
        final restored = accountDetailsFromJson(json);
        expect(
          restored,
          equals(s),
          reason: 'round-trip failed for ${s.variantName}',
        );
      }
    });

    test('unknown variant returns CashDetails', () {
      final restored = accountDetailsFromJson({'_type': 'mystery'});
      expect(restored, isA<CashDetails>());
    });

    test('null json returns CashDetails', () {
      expect(accountDetailsFromJson(null), isA<CashDetails>());
    });

    test('details survive record and row', () {
      final account = Account(
        id: 'acc',
        userId: 'user',
        name: 'Visa',
        type: AccountType.creditCard,
        currentBalance: Money.parse('-10', 'THB'),
        details: CreditCardDetails(
          creditLimit: Money.parse('5000', 'THB'),
          statementDay: 15,
          dueDay: 5,
        ),
      );
      const codec = RecordCodecs.accounts;
      final restored = codec
          .fromRow(codec.toRow(account.toOffline(userId: 'user')))
          .toDomain();
      expect(restored.details, account.details);
      expect(restored.currentBalance, account.currentBalance);
    });
  });

  group('goals -> account mapping', () {
    test('OfflineAccount round-trips goal fields when type=goal', () {
      final source = OfflineAccount(
        id: 'acc-1',
        userId: 'user-1',
        name: 'Europe Trip',
        type: 'goal',
        currency: 'USD',
        currentBalance: '1200.00',
        goalTargetAmount: '5000.00',
        goalTargetDate: DateTime.utc(2027, 6, 1),
        goalPriority: 'high',
      );

      final domain = source.toDomain();

      expect(domain.type, AccountType.goal);
      expect(domain.isGoal, isTrue);
      expect(domain.targetAmount, isNotNull);
      expect(domain.targetAmount!.amount.toDouble(), 5000.0);
      expect(domain.targetDate, DateTime.utc(2027, 6, 1));
      expect(domain.priority, GoalPriority.high);
      expect(domain.goalProgress, closeTo(0.24, 0.01));
    });

    test('non-goal account has null goal fields', () {
      final source = OfflineAccount(
        id: 'acc-2',
        userId: 'user-1',
        name: 'Checking',
        type: 'bank',
        currency: 'USD',
        currentBalance: '500.00',
      );

      final domain = source.toDomain();
      final restored = domain.toOffline(userId: 'user-1');

      expect(domain.type, AccountType.bank);
      expect(domain.isGoal, isFalse);
      expect(domain.targetAmount, isNull);
      expect(domain.targetDate, isNull);
      expect(restored.goalTargetAmount, isNull);
      expect(restored.goalTargetDate, isNull);
      expect(restored.goalPriority, 'medium');
    });

    test('goal remaining caps at zero when over target', () {
      final source = OfflineAccount(
        id: 'acc-3',
        userId: 'user-1',
        name: 'Car',
        type: 'goal',
        currency: 'USD',
        currentBalance: '15000',
        goalTargetAmount: '12000',
        goalPriority: 'medium',
      );

      final domain = source.toDomain();
      expect(domain.goalProgress, 1.0);
      expect(domain.goalRemaining.amount.toString(), '0');
    });
  });
}
