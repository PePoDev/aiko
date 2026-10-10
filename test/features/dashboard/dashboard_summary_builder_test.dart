import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/dashboard/application/dashboard_summary_builder.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 10, 15);

  Account account(
    String name,
    AccountType type,
    String balance,
    String currency, {
    bool includeInNetWorth = true,
  }) => Account(
    id: name,
    userId: 'u',
    name: name,
    type: type,
    currentBalance: Money.parse(balance, currency),
    includeInNetWorth: includeInNetWorth,
  );

  FinanceTransaction tx(
    TransactionType type,
    String amount,
    String currency,
    DateTime date, {
    TransactionStatus status = TransactionStatus.posted,
  }) => FinanceTransaction(
    id: '$type$amount$currency$date',
    userId: 'u',
    accountId: 'a',
    type: type,
    amount: Money.parse(amount, currency),
    date: date,
    status: status,
  );

  group('CurrencyConverter', () {
    test('converts with rates quoted against the base currency', () {
      // 1 THB buys 0.025 USD, so 1 USD is 40 THB.
      final converter = CurrencyConverter('thb', {
        'usd': Decimal.parse('0.025'),
      });
      expect(converter.toBase(Money.parse('10', 'USD')), Decimal.parse('400'));
      expect(converter.toBase(Money.parse('10', 'THB')), Decimal.parse('10'));
      expect(converter.toBase(Money.parse('10', 'EUR')), isNull);
    });
  });

  test('totals are in the base currency and convert other currencies', () {
    final summary = buildDashboardSummary(
      accounts: [
        account('Bank', AccountType.bank, '10000', 'THB'),
        account('Wise', AccountType.bank, '100', 'USD'),
        account('Card', AccountType.creditCard, '-2000', 'THB'),
        account('Trip fund', AccountType.goal, '5000', 'THB'),
        account(
          'Hidden',
          AccountType.cash,
          '300',
          'THB',
          includeInNetWorth: false,
        ),
      ],
      transactions: [
        tx(TransactionType.income, '30000', 'THB', DateTime(2026, 10, 1)),
        tx(TransactionType.expense, '50', 'USD', DateTime(2026, 10, 10)),
        tx(TransactionType.expense, '1000', 'THB', DateTime(2026, 10, 10)),
        tx(
          TransactionType.expense,
          '999',
          'THB',
          DateTime(2026, 10, 10),
          status: TransactionStatus.draft,
        ),
        tx(
          TransactionType.expense,
          '500',
          'THB',
          DateTime(2026, 10, 9),
          status: TransactionStatus.voided,
        ),
        // Last month: not counted.
        tx(TransactionType.expense, '7000', 'THB', DateTime(2026, 9, 30)),
      ],
      converter: CurrencyConverter('THB', {'USD': Decimal.parse('0.025')}),
      now: now,
    );

    expect(summary.netWorth, Money.parse('12000', 'THB'));
    expect(summary.totalCash, Money.parse('14300', 'THB'));
    expect(summary.monthlyIncome, Money.parse('30000', 'THB'));
    // 2,000 (50 USD) + 1,000 + 999 draft.
    expect(summary.monthlySpending, Money.parse('3999', 'THB'));
    // Only posted expenses count as spent today.
    expect(summary.todaySpending, Money.parse('3000', 'THB'));
    expect(summary.excludedCurrencies, isEmpty);
  });

  test('amounts without a rate are left out and reported', () {
    final summary = buildDashboardSummary(
      accounts: [
        account('Bank', AccountType.bank, '10000', 'THB'),
        account('Wise', AccountType.bank, '100', 'USD'),
      ],
      transactions: [
        tx(TransactionType.expense, '20', 'EUR', DateTime(2026, 10, 2)),
      ],
      converter: CurrencyConverter('THB'),
      now: now,
    );

    expect(summary.netWorth, Money.parse('10000', 'THB'));
    expect(summary.monthlySpending, Money.parse('0', 'THB'));
    expect(summary.excludedCurrencies, {'USD', 'EUR'});
  });

  test('rates are only needed when another currency is present', () {
    final accounts = [account('Bank', AccountType.bank, '1', 'THB')];
    expect(
      foreignCurrencies(
        baseCurrency: 'THB',
        accounts: accounts,
        transactions: [
          tx(TransactionType.expense, '5', 'USD', DateTime(2026, 9, 1)),
        ],
        now: now,
      ),
      isEmpty,
    );
    expect(
      foreignCurrencies(
        baseCurrency: 'THB',
        accounts: accounts,
        transactions: [
          tx(TransactionType.expense, '5', 'USD', DateTime(2026, 10, 1)),
        ],
        now: now,
      ),
      {'USD'},
    );
  });

  test('the whole last day of the month counts', () {
    final summary = buildDashboardSummary(
      accounts: const [],
      transactions: [
        tx(TransactionType.income, '100', 'THB', DateTime(2026, 10, 31, 23)),
        tx(TransactionType.income, '50', 'THB', DateTime(2026, 11, 1)),
      ],
      converter: CurrencyConverter('THB'),
      now: DateTime(2026, 10, 31, 8),
    );
    expect(summary.monthlyIncome, Money.parse('100', 'THB'));
  });
}
