import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/aiko_assistant/application/financial_context.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _snapshotProvider = FutureProvider<AikoFinancialContext?>(
  buildAikoFinancialContext,
);

void main() {
  test(
    'the snapshot reuses loaded providers instead of the repositories',
    () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          // Any repository read fails the snapshot (it then returns null).
          accountRepositoryProvider.overrideWithValue(_NoAccountReads()),
          categoryRepositoryProvider.overrideWithValue(_NoCategoryReads()),
          transactionRepositoryProvider.overrideWithValue(
            _NoTransactionReads(),
          ),
          profileRepositoryProvider.overrideWithValue(_NoProfileReads()),
          profileProvider.overrideWith(
            (ref) async => const Profile(
              id: 'u',
              displayName: 'Aiko user',
              email: 'user@example.com',
              baseCurrency: 'USD',
              country: 'US',
              securityStatus: SecurityStatus.notConfigured,
            ),
          ),
          accountsProvider.overrideWith(
            () => _Accounts([
              Account(
                id: 'checking',
                userId: 'u',
                name: 'Checking',
                type: AccountType.bank,
                currentBalance: Money.parse('1000', 'USD'),
              ),
            ]),
          ),
          categoriesProvider.overrideWith(() => _Categories(const [])),
          transactionsProvider.overrideWith(
            () => _Transactions([
              FinanceTransaction(
                id: 'lunch',
                userId: 'u',
                accountId: 'checking',
                type: TransactionType.expense,
                amount: Money.parse('12.5', 'USD'),
                date: now,
              ),
            ]),
          ),
          fxRatesProvider.overrideWith(
            (ref, base) async => <String, Decimal>{},
          ),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await container.read(_snapshotProvider.future);

      expect(snapshot, isNotNull);
      expect(snapshot!.baseCurrency, 'USD');
      expect(snapshot.netWorth, 1000);
      expect(snapshot.monthSpending, 12.5);
      expect(snapshot.recentTransactions, hasLength(1));
    },
  );
}

class _Accounts extends AccountsNotifier {
  _Accounts(this.accounts);
  final List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;
}

class _Categories extends CategoriesNotifier {
  _Categories(this.categories);
  final List<Category> categories;

  @override
  Future<List<Category>> build() async => categories;
}

class _Transactions extends TransactionsNotifier {
  _Transactions(this.transactions);
  final List<FinanceTransaction> transactions;

  @override
  Future<List<FinanceTransaction>> build() async => transactions;
}

mixin _NoReads {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected repository read');
}

class _NoAccountReads with _NoReads implements AccountRepository {}

class _NoCategoryReads with _NoReads implements CategoryRepository {}

class _NoTransactionReads with _NoReads implements TransactionRepository {}

class _NoProfileReads with _NoReads implements ProfileRepository {}
