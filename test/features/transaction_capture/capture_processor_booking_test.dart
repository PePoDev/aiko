import 'dart:io';

import 'package:aiko/app/providers.dart';
import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/transaction_capture/transaction_capture.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/data/transaction_rule_store.dart';
import 'package:aiko/features/transactions/domain/transaction_rule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/offline/record_store_harness.dart';

/// Reads the ledger like [CaptureLedgerStore], running [onLoad] first: a
/// hook into the middle of a processing run.
class _HookedLedgerStore extends CaptureLedgerStore {
  const _HookedLedgerStore({required super.file, required this.onLoad});

  final Future<void> Function() onLoad;

  @override
  Future<CaptureLedger> load() async {
    await onLoad();
    return super.load();
  }
}

/// The processor against the real transactions and accounts notifiers over
/// a local record store.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'local:guest';
  const userContext = FixedUserContext(owner);
  late LocalRecordStore local;
  late RecordingStore store;
  late Directory root;
  late CapturedMessageInbox inbox;
  late ProviderContainer container;
  Future<void> Function() midRun = () async {};

  setUp(() async {
    local = await openMemoryRecordStore();
    store = RecordingStore(local);
    root = await Directory.systemTemp.createTemp('aiko_capture_booking');
    inbox = CapturedMessageInbox(directory: Directory('${root.path}/inbox'));
    final settings = MemorySecureStorageService();
    await const TransactionCaptureSettings(
      enabled: true,
      accountId: 'wallet',
    ).save(settings);
    midRun = () async {};
    container = ProviderContainer(
      overrides: [
        offlineStoreProvider.overrideWithValue(store),
        accountRepositoryProvider.overrideWithValue(
          AccountRepository(store: store, userContext: userContext),
        ),
        transactionRepositoryProvider.overrideWithValue(
          TransactionRepository(store: store, userContext: userContext),
        ),
        transactionRulesProvider.overrideWith(
          (ref) async => const <TransactionRule>[],
        ),
        transactionCaptureProcessorProvider.overrideWith(
          (ref) => CapturedMessageProcessor(
            ref,
            inbox: inbox,
            ledger: _HookedLedgerStore(
              file: File('${root.path}/capture_ledger.json'),
              onLoad: () => midRun(),
            ),
            settingsStorage: settings,
          ),
        ),
      ],
    );

    final batch = RecordBatch()
      ..upsert(
        Account(
          id: 'wallet',
          userId: owner,
          name: 'Wallet',
          type: AccountType.bank,
          currentBalance: Money.parse('1000', 'THB'),
        ).toOffline(userId: owner),
      );
    await store.commit(batch);
    store.commits.clear();

    for (final (i, body) in const [
      'Paid THB 120.00',
      'Paid THB 99.00',
      'Paid THB 45.00',
    ].indexed) {
      await inbox.add(
        CapturedMessage(
          id: '176000000000000$i-1',
          source: 'sms',
          sender: 'KBANK',
          body: body,
          receivedAt: DateTime(2026, 10, 13, 10, 25 + i),
        ),
      );
    }
  });

  tearDown(() async {
    container.dispose();
    await local.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> storedBalance() async =>
      (await store.get<OfflineAccount>()).single.currentBalance;

  test('a run is booked in one write with one balance update', () async {
    final created = await container
        .read(transactionCaptureProcessorProvider)
        .processInbox();

    expect(created, 3);
    final write = store.commits.single;
    expect(write.writes.map((w) => w.collection), [
      'transactions',
      'transactions',
      'transactions',
      'accounts',
    ]);
    expect(await storedBalance(), '736');
    expect(await store.get<OfflineTransaction>(), hasLength(3));
    expect(await inbox.drain(), isEmpty);
  });

  test('the transactions list being refreshed mid-run loses nothing', () async {
    // firebase_sync refreshes the list after every snapshot. Nothing on
    // screen watches it here, like on the Ask Aiko tab.
    midRun = () async {
      container.invalidate(transactionsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    };

    final created = await container
        .read(transactionCaptureProcessorProvider)
        .processInbox();

    expect(created, 3);
    expect(await store.get<OfflineTransaction>(), hasLength(3));
    expect(await storedBalance(), '736');
    expect(await inbox.drain(), isEmpty);
  });

  test('a run that cannot be saved keeps every message queued', () async {
    store.failCommits = true;

    final created = await container
        .read(transactionCaptureProcessorProvider)
        .processInbox();

    expect(created, 0);
    expect(await inbox.drain(), hasLength(3));

    // The next run books them, once.
    store.failCommits = false;
    expect(
      await container.read(transactionCaptureProcessorProvider).processInbox(),
      3,
    );
    expect(await store.get<OfflineTransaction>(), hasLength(3));
    expect(await storedBalance(), '736');
  });
}
