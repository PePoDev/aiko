import 'package:aiko/brick/models/transaction.model.dart';
import 'package:aiko/brick/repository.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:brick_sqlite/brick_sqlite.dart' show SqliteModel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';

  test('authenticated reads map fixed category ids to clones', () async {
    final store = _TransactionStore([
      OfflineTransaction(
        id: 'transaction',
        userId: userId,
        accountId: 'account',
        type: 'expense',
        amount: '10',
        currency: 'THB',
        date: DateTime(2026, 7, 26),
        categoryId: CategoryDefaults.coffeeId,
      ),
    ]);
    final repository = TransactionRepository(
      store: store,
      userContext: _FixedUserContext(userId),
    );

    final transaction = (await repository.list()).single;

    expect(
      transaction.categoryId,
      CategoryDefaults.cloneIdForUser(
        userId: userId,
        templateId: CategoryDefaults.coffeeId,
      ),
    );
  });

  test('authenticated saves persist clone category ids', () async {
    final store = _TransactionStore();
    final repository = TransactionRepository(
      store: store,
      userContext: _FixedUserContext(userId),
    );

    await repository.save(
      FinanceTransaction(
        id: 'transaction',
        userId: userId,
        accountId: 'account',
        type: TransactionType.expense,
        amount: Money.parse('10', 'THB'),
        date: DateTime(2026, 7, 26),
        categoryId: CategoryDefaults.coffeeId,
      ),
    );

    expect(
      store.transactions.single.categoryId,
      CategoryDefaults.cloneIdForUser(
        userId: userId,
        templateId: CategoryDefaults.coffeeId,
      ),
    );
  });

  test('anonymous saves retain fixed template ids', () async {
    final store = _TransactionStore();
    final repository = TransactionRepository(
      store: store,
      userContext: _FixedUserContext('local:test-user'),
    );

    await repository.save(
      FinanceTransaction(
        id: 'transaction',
        userId: 'local:test-user',
        accountId: 'account',
        type: TransactionType.expense,
        amount: Money.parse('10', 'THB'),
        date: DateTime(2026, 7, 26),
        categoryId: CategoryDefaults.coffeeId,
      ),
    );

    expect(store.transactions.single.categoryId, CategoryDefaults.coffeeId);
  });
}

class _FixedUserContext implements OfflineUserContext {
  const _FixedUserContext(this.userId);

  final String userId;

  @override
  Future<String> resolveUserId() async => userId;
}

class _TransactionStore implements OfflineStore {
  _TransactionStore([List<OfflineTransaction>? transactions])
    : transactions = transactions ?? [];

  final List<OfflineTransaction> transactions;

  @override
  bool get canSyncRemote => false;

  @override
  Future<List<TModel>> get<TModel extends SqliteModel>({
    Query? query,
    OfflineReadPolicy? policy,
  }) async => transactions.whereType<TModel>().toList();

  @override
  Future<TModel> upsert<TModel extends SqliteModel>(
    TModel model, {
    Query? query,
  }) async {
    final transaction = model as OfflineTransaction;
    transactions.removeWhere((item) => item.id == transaction.id);
    transactions.add(transaction);
    return model;
  }

  @override
  Future<void> upsertBatch<TModel extends SqliteModel>(
    List<TModel> models,
  ) async {
    for (final model in models) {
      await upsert<TModel>(model);
    }
  }

  @override
  Future<bool> delete<TModel extends SqliteModel>(
    TModel model, {
    Query? query,
    bool localOnly = false,
  }) async => false;
}
