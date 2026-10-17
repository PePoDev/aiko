import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/storage/synced_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/dashboard/application/notification_dismissals.dart';
import 'package:aiko/features/dashboard/domain/app_notification.dart';
import 'package:aiko/features/dashboard/domain/dashboard_due_item.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  Money usd(String v) => Money.parse(v, 'USD');

  final category = Category(
    id: 'food',
    userId: 'u',
    name: 'Food',
    type: CategoryType.expense,
    group: CategoryBudgetGroup.needs,
    monthlyLimit: usd('100'),
    alertThresholds: const [50, 75, 90, 100],
  );
  FinanceTransaction spend(String amount, DateTime date) => FinanceTransaction(
    id: 't-$amount-${date.month}',
    userId: 'u',
    accountId: 'a',
    type: TransactionType.expense,
    amount: usd(amount),
    date: date,
    categoryId: 'food',
  );
  Account goal({String saved = '1000', bool isActive = true}) => Account(
    id: 'g1',
    userId: 'u',
    name: 'Trip',
    type: AccountType.goal,
    currentBalance: usd(saved),
    targetAmount: usd('1000'),
    isActive: isActive,
  );

  List<AppNotification> build({
    List<FinanceTransaction> transactions = const [],
    List<Account> accounts = const [],
    List<DashboardDueItem> dueItems = const [],
    required DateTime asOf,
  }) => buildNotifications(
    transactions: transactions,
    categories: [category],
    accounts: accounts,
    dueItems: dueItems,
    asOf: asOf,
    l10n: english,
  );

  group('notification ids and targets', () {
    test('a budget alert is keyed by threshold and budget period', () {
      final june = build(
        transactions: [spend('80', DateTime(2026, 6, 10))],
        asOf: DateTime(2026, 6, 20),
      ).single;
      expect(june.id, 'budget:food:75:2026-06-01');
      expect(june.target, AppNotificationTarget.categories);

      // Crossing a higher threshold is a new notification.
      final higher = build(
        transactions: [spend('95', DateTime(2026, 6, 10))],
        asOf: DateTime(2026, 6, 20),
      ).single;
      expect(higher.id, isNot(june.id));

      // The same threshold next month is new too.
      final july = build(
        transactions: [spend('80', DateTime(2026, 7, 2))],
        asOf: DateTime(2026, 7, 3),
      ).single;
      expect(july.id, 'budget:food:75:2026-07-01');
    });

    test('a bill is keyed by account and due date and opens Accounts', () {
      final bill = build(
        dueItems: [
          DashboardDueItem(
            id: 'cc1',
            title: 'Visa payment',
            amount: usd('50'),
            dueDate: DateTime(2026, 6, 23),
          ),
        ],
        asOf: DateTime(2026, 6, 20),
      ).single;
      expect(bill.id, 'bill:cc1:2026-06-23');
      expect(bill.target, AppNotificationTarget.accounts);
    });

    test('a goal milestone opens the goal account; inactive goals are '
        'skipped', () {
      final reached = build(
        accounts: [goal()],
        asOf: DateTime(2026, 6, 20),
      ).single;
      expect(reached.id, 'goal:g1:100');
      expect(reached.target, AppNotificationTarget.account);
      expect(reached.accountId, 'g1');

      expect(
        build(accounts: [goal(isActive: false)], asOf: DateTime(2026, 6, 20)),
        isEmpty,
      );
    });
  });

  group('NotificationDismissalStore', () {
    test('dismissed ids are stored and filtered out', () async {
      final store = NotificationDismissalStore(MemorySecureStorageService());
      expect(await store.load(), isEmpty);

      final dismissed = await store.dismiss('goal:g1:100', [
        'goal:g1:100',
        'bill:cc1:2026-06-23',
      ]);
      expect(dismissed, {'goal:g1:100'});
      expect(await store.load(), {'goal:g1:100'});

      final all = build(accounts: [goal()], asOf: DateTime(2026, 6, 20));
      expect(withoutDismissed(all, dismissed), isEmpty);
    });

    test('ids from past periods are dropped on a later dismissal once they '
        'are old', () async {
      final storage = MemorySecureStorageService();
      var now = DateTime.utc(2026, 6, 20);
      final store = NotificationDismissalStore(storage, clock: () => now);
      await store.dismiss('budget:food:75:2026-06-01', [
        'budget:food:75:2026-06-01',
      ]);

      // A few days later the June alert is no longer listed, but another
      // device may still show it: keep the dismissal for now.
      now = DateTime.utc(2026, 7, 2);
      expect(
        await store.dismiss('budget:food:75:2026-07-01', [
          'budget:food:75:2026-07-01',
        ]),
        {'budget:food:75:2026-06-01', 'budget:food:75:2026-07-01'},
      );

      now = DateTime.utc(2026, 9, 1);
      expect(await store.dismiss('goal:g1:100', ['goal:g1:100']), {
        'goal:g1:100',
      });
    });

    test('reads the earlier list format and carries it over', () async {
      final storage = MemorySecureStorageService();
      await storage.write(
        NotificationDismissalStore.legacyKey,
        '["goal:g1:100", "bill:cc1:2026-06-23"]',
      );
      final store = NotificationDismissalStore(storage);
      expect(await store.load(), {'goal:g1:100', 'bill:cc1:2026-06-23'});

      // Earlier dismissals have no time; the ones not shown any more go.
      expect(await store.dismiss('goal:g1:50', ['goal:g1:100', 'goal:g1:50']), {
        'goal:g1:100',
        'goal:g1:50',
      });
      expect(await store.load(), {'goal:g1:100', 'goal:g1:50'});
    });

    test('dismissals made on two devices while offline both survive', () async {
      final firestore = FakeFirebaseFirestore();
      NotificationDismissalStore device() => NotificationDismissalStore(
        SyncedPreferences(
          local: MemorySecureStorageService(),
          firestore: firestore,
          userId: () => 'user-1',
          sync: FirestoreSyncState(firstSnapshotWait: Duration.zero),
        ),
      );

      await device().dismiss('goal:g1:100', ['goal:g1:100']);
      // The other device doesn't list the goal alert (not synced yet).
      await device().dismiss('bill:cc1:2026-06-23', ['bill:cc1:2026-06-23']);

      expect(await device().load(), {'goal:g1:100', 'bill:cc1:2026-06-23'});
    });

    test('unreadable storage reads as nothing dismissed', () async {
      final storage = MemorySecureStorageService();
      await storage.write(NotificationDismissalStore.storageKey, 'not json');
      expect(await NotificationDismissalStore(storage).load(), isEmpty);
    });
  });

  test('notificationsProvider hides a dismissed notification and remembers '
      'it', () async {
    final storage = MemorySecureStorageService();
    final all = build(accounts: [goal()], asOf: DateTime(2026, 6, 20));
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          allNotificationsProvider.overrideWith((ref) async => all),
          notificationDismissalStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(notificationsProvider, (_, _) {});
      addTearDown(sub.close);
      return c;
    }

    final first = container();
    expect(await first.read(notificationsProvider.future), hasLength(1));
    await first
        .read(notificationDismissalsProvider.notifier)
        .dismiss('goal:g1:100');
    expect(await first.read(notificationsProvider.future), isEmpty);

    // A fresh session reads the dismissal back from storage.
    expect(await container().read(notificationsProvider.future), isEmpty);
  });
}
