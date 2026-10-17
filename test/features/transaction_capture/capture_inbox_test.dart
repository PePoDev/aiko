import 'dart:io';

import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transaction_capture/transaction_capture.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedMessage _message(String id, {String body = 'Paid THB 120.00'}) =>
    CapturedMessage(
      id: id,
      source: 'sms',
      sender: 'BANK',
      body: body,
      receivedAt: DateTime(2026, 10, 13, 10, 25),
    );

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
      // Draining doesn't remove; booking does, one message at a time.
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
          draftFor: (message, id) => FinanceTransaction(
            id: id,
            userId: '',
            accountId: 'acc',
            type: TransactionType.expense,
            amount: Money(amount: Decimal.parse('120.00'), currency: 'THB'),
            date: message.receivedAt,
          ),
          isBooked: saved.contains,
          add: (draft) async => saved.add(draft.id),
          remove: (_) async => throw const FileSystemException('killed'),
          ledger: await store.load(),
          saveLedger: store.save,
        );
        expect(saved, hasLength(1));

        // Next start: the message is still queued; it is removed, not rebooked.
        var booked = 0;
        final created = await bookCapturedMessages(
          await inbox.drain(),
          draftFor: (message, id) => FinanceTransaction(
            id: id,
            userId: '',
            accountId: 'acc',
            type: TransactionType.expense,
            amount: Money(amount: Decimal.parse('120.00'), currency: 'THB'),
            date: message.receivedAt,
          ),
          isBooked: saved.contains,
          add: (_) async => booked++,
          remove: inbox.remove,
          ledger: await store.load(),
          saveLedger: store.save,
        );

        expect(created, 0);
        expect(booked, 0);
        expect(await inbox.drain(), isEmpty);
      },
    );
  });
}
