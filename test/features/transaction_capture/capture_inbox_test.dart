import 'dart:io';

import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/transaction_capture/transaction_capture.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedMessage _message(
  String id, {
  String body = 'Paid THB 120.00',
  String source = 'sms',
  String sender = 'BANK',
}) => CapturedMessage(
  id: id,
  source: source,
  sender: sender,
  body: body,
  receivedAt: DateTime(2026, 10, 13, 10, 25),
);

FinanceTransaction _draft(CapturedMessage message, String id) =>
    FinanceTransaction(
      id: id,
      userId: '',
      accountId: 'acc',
      type: TransactionType.expense,
      amount: Money(amount: Decimal.parse('120.00'), currency: 'THB'),
      date: message.receivedAt,
    );

class _ThrowingStorage implements SecureStorageService {
  @override
  Future<String?> read(String key) => throw StateError('keystore locked');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aiko_capture_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('CapturedMessageInbox', () {
    test('queues messages and drains them oldest first', () async {
      final inbox = CapturedMessageInbox(
        directory: Directory('${root.path}/inbox'),
      );
      await inbox.add(_message('1760000000000002-1', body: 'second'));
      await inbox.add(_message('1760000000000001-9', body: 'first'));

      final drained = await inbox.drain();

      expect(drained.map((m) => m.body), ['first', 'second']);
      expect(drained.first.receivedAt, DateTime(2026, 10, 13, 10, 25));
      // Draining doesn't remove; booking does, once a message is settled.
      expect(await inbox.drain(), hasLength(2));
      await inbox.remove('1760000000000001-9');
      expect((await inbox.drain()).map((m) => m.body), ['second']);
    });

    test('leaves no temporary file behind after a write', () async {
      final dir = Directory('${root.path}/inbox');
      await CapturedMessageInbox(directory: dir).add(_message('1-a'));

      final names = dir.listSync().map((e) => e.uri.pathSegments.last);
      expect(names, ['1-a.json']);
    });

    test(
      'ignores a write still in progress and drops corrupt entries',
      () async {
        final dir = Directory('${root.path}/inbox')..createSync();
        final inbox = CapturedMessageInbox(directory: dir);
        await inbox.add(_message('2-ok'));
        // Another isolate mid-write: not queued yet, and must survive.
        File('${dir.path}/3-writing.tmp').writeAsStringSync('{"id": "3-wr');
        File('${dir.path}/1-corrupt.json').writeAsStringSync('{"id": ');

        final drained = await inbox.drain();

        expect(drained.map((m) => m.id), ['2-ok']);
        expect(File('${dir.path}/1-corrupt.json').existsSync(), isFalse);
        expect(File('${dir.path}/3-writing.tmp').existsSync(), isTrue);
      },
    );

    test('clear drops everything queued', () async {
      final inbox = CapturedMessageInbox(
        directory: Directory('${root.path}/inbox'),
      );
      await inbox.add(_message('1-a'));
      await inbox.add(_message('2-b'));

      await inbox.clear();

      expect(await inbox.drain(), isEmpty);
    });

    test('removing a message twice is harmless', () async {
      final inbox = CapturedMessageInbox(
        directory: Directory('${root.path}/inbox'),
      );
      await inbox.add(_message('1-a'));
      await inbox.remove('1-a');
      await inbox.remove('1-a');
      expect(await inbox.drain(), isEmpty);
    });
  });

  group('queueBackgroundSms', () {
    Future<MemorySecureStorageService> settings({required bool enabled}) async {
      final storage = MemorySecureStorageService();
      await TransactionCaptureSettings(
        enabled: enabled,
        accountId: 'acc',
      ).save(storage);
      return storage;
    }

    test('queues a bank SMS while capture is on', () async {
      final inbox = CapturedMessageInbox(
        directory: Directory('${root.path}/inbox'),
      );

      final queued = await queueBackgroundSms(
        address: 'KBANK',
        body: 'Paid THB 120.00 at CAFE AMAZON',
        inbox: inbox,
        storage: await settings(enabled: true),
      );

      expect(queued, isTrue);
      final drained = await inbox.drain();
      expect(drained.single.source, 'sms');
      expect(drained.single.sender, 'KBANK');
      expect(drained.single.body, 'Paid THB 120.00 at CAFE AMAZON');
    });

    test('dates the SMS when it was sent, not when it arrived', () async {
      final inbox = CapturedMessageInbox(
        directory: Directory('${root.path}/inbox'),
      );
      // Held back by the carrier: sent a few minutes before it arrives.
      final sent = DateTime.now().subtract(const Duration(minutes: 9));

      await queueBackgroundSms(
        address: 'KBANK',
        body: 'Paid THB 120.00',
        timestamp: sent.millisecondsSinceEpoch,
        inbox: inbox,
        storage: await settings(enabled: true),
      );

      final queued = (await inbox.drain()).single;
      expect(
        queued.receivedAt.millisecondsSinceEpoch,
        sent.millisecondsSinceEpoch,
      );
    });

    test('keeps nothing while capture is off', () async {
      final inbox = CapturedMessageInbox(
        directory: Directory('${root.path}/inbox'),
      );

      final queued = await queueBackgroundSms(
        address: 'KBANK',
        body: 'Paid THB 120.00',
        inbox: inbox,
        storage: await settings(enabled: false),
      );

      expect(queued, isFalse);
      expect(await inbox.drain(), isEmpty);
    });

    test('queues when the settings cannot be read yet', () async {
      final inbox = CapturedMessageInbox(
        directory: Directory('${root.path}/inbox'),
      );

      final queued = await queueBackgroundSms(
        address: 'KBANK',
        body: 'Paid THB 120.00',
        inbox: inbox,
        storage: _ThrowingStorage(),
      );

      expect(queued, isTrue);
      expect(await inbox.drain(), hasLength(1));
    });

    test('never writes a personal text to disk', () async {
      final dir = Directory('${root.path}/inbox');

      final queued = await queueBackgroundSms(
        address: 'Mum',
        body: 'See you at 7?',
        inbox: CapturedMessageInbox(directory: dir),
        storage: await settings(enabled: true),
      );

      expect(queued, isFalse);
      expect(dir.existsSync(), isFalse);
    });
  });

  group('CaptureLedgerStore', () {
    CaptureRecord record(String id) => CaptureRecord.of(
      _message(id),
      FinanceTransaction(
        id: 'tx-$id',
        userId: '',
        accountId: 'acc',
        type: TransactionType.expense,
        amount: Money(amount: Decimal.parse('120.00'), currency: 'THB'),
        date: DateTime(2026, 10, 13),
      ),
    );

    test('starts empty and keeps what was saved', () async {
      final store = CaptureLedgerStore(
        file: File('${root.path}/nested/capture_ledger.json'),
      );
      expect((await store.load()).records, isEmpty);

      await store.save(CaptureLedger([record('1'), record('2')]));
      final loaded = await store.load();

      expect(loaded.records.map((r) => r.id), ['1', '2']);
      expect(loaded.records.first.amount, '120');
      expect(
        File('${root.path}/nested/capture_ledger.json.tmp').existsSync(),
        isFalse,
      );
    });

    test('an unreadable ledger starts over instead of failing', () async {
      final file = File('${root.path}/capture_ledger.json')
        ..writeAsStringSync('[{"id": 1}');
      final store = CaptureLedgerStore(file: file);

      expect((await store.load()).records, isEmpty);
    });

    test(
      'booking after a restart: saved ids and the ledger stop repeats',
      () async {
        // First run: the SMS is booked, then the app is killed before it is
        // removed from the inbox.
        final inbox = CapturedMessageInbox(
          directory: Directory('${root.path}/inbox'),
        );
        final store = CaptureLedgerStore(
          file: File('${root.path}/capture_ledger.json'),
        );
        final sms = _message('1760000000000001-1');
        await inbox.add(sms);
        final saved = <String>{};
        await bookCapturedMessages(
          await inbox.drain(),
          draftFor: _draft,
          isBooked: saved.contains,
          add: (drafts) async => saved.addAll(drafts.map((d) => d.id)),
          remove: (_) async => throw const FileSystemException('killed'),
          ledger: await store.load(),
          saveLedger: store.save,
        );
        expect(saved, hasLength(1));

        // Next start: the message is still queued; it is removed, not rebooked.
        var booked = 0;
        final created = await bookCapturedMessages(
          await inbox.drain(),
          draftFor: _draft,
          isBooked: saved.contains,
          add: (drafts) async => booked += drafts.length,
          remove: inbox.remove,
          ledger: await store.load(),
          saveLedger: store.save,
        );

        expect(created, 0);
        expect(booked, 0);
        expect(await inbox.drain(), isEmpty);
      },
    );

    test(
      'killed right after the transaction write: no repeat is booked either',
      () async {
        final inbox = CapturedMessageInbox(
          directory: Directory('${root.path}/inbox'),
        );
        final store = CaptureLedgerStore(
          file: File('${root.path}/capture_ledger.json'),
        );
        final notification = _message(
          '1760000000000005-1',
          body: 'You paid THB 120.00',
          source: 'notification',
          sender: 'bank.app',
        );
        await inbox.add(notification);
        final saved = <String>{};
        // First run: the bank app's notification is booked, then the app is
        // killed before the ledger or the inbox are written.
        await bookCapturedMessages(
          await inbox.drain(),
          draftFor: _draft,
          isBooked: saved.contains,
          add: (drafts) async => saved.addAll(drafts.map((d) => d.id)),
          remove: (_) async => throw const FileSystemException('killed'),
          ledger: await store.load(),
          saveLedger: (_) async => throw const FileSystemException('killed'),
        );
        expect(saved, hasLength(1));
        // The bank's SMS of the same payment, captured a moment earlier by the
        // background isolate, only lands in the inbox now; it sorts first.
        await inbox.add(_message('1760000000000004-9'));

        final booked = <String>[];
        final created = await bookCapturedMessages(
          await inbox.drain(),
          draftFor: _draft,
          isBooked: saved.contains,
          add: (drafts) async => booked.addAll(drafts.map((d) => d.id)),
          remove: inbox.remove,
          ledger: await store.load(),
          saveLedger: store.save,
        );

        expect(created, 0);
        expect(booked, isEmpty);
        expect(await inbox.drain(), isEmpty);
        final ledger = await store.load();
        expect(ledger.contains(notification.id), isTrue);
        expect(
          ledger.records
              .singleWhere((r) => r.id == '1760000000000004-9')
              .duplicateOf,
          notification.id,
        );
      },
    );
  });
}
