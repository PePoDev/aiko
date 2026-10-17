import 'dart:convert';
import 'dart:io';

import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/transaction_capture/transaction_capture.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 10, 13, 10, 25);

CapturedMessage _message(
  String id,
  String body, {
  String source = 'sms',
  String sender = 'BANK',
  DateTime? at,
}) => CapturedMessage(
  id: id,
  source: source,
  sender: sender,
  body: body,
  receivedAt: at ?? _t0,
);

FinanceTransaction _draft(
  String id,
  String amount, {
  TransactionType type = TransactionType.expense,
}) => FinanceTransaction(
  id: id,
  userId: '',
  accountId: 'acc',
  type: type,
  amount: Money(amount: Decimal.parse(amount), currency: 'THB'),
  date: DateTime(2026, 10, 13),
);

/// Books [messages] with every draft at [amount] (or what [amountFor] says),
/// returning the ids of the messages that became transactions.
Future<List<String>> _book(
  List<CapturedMessage> messages, {
  String amount = '120.00',
  String Function(CapturedMessage message)? amountFor,
  Set<String> saved = const {},
  CaptureLedger? ledger,
  Future<void> Function(CaptureLedger ledger)? saveLedger,
  List<String>? removed,
}) async {
  final bookedMessages = <String>[];
  final byTransaction = {
    for (final message in messages) capturedTransactionId(message): message.id,
  };
  await bookCapturedMessages(
    messages,
    draftFor: (message, id) => _draft(id, amountFor?.call(message) ?? amount),
    isBooked: saved.contains,
    add: (draft) async => bookedMessages.add(byTransaction[draft.id]!),
    remove: (id) async => removed?.add(id),
    ledger: ledger,
    saveLedger: saveLedger,
  );
  return bookedMessages;
}

class _ThrowingStorage implements SecureStorageService {
  @override
  Future<String?> read(String key) => throw StateError('keystore locked');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bookCapturedMessages', () {
    test(
      'a failing message is dropped and the rest are still booked',
      () async {
        final added = <String>[];
        final removed = <String>[];
        final created = await bookCapturedMessages(
          [
            _message('1-bad', 'throws while building'),
            _message('2-save-fails', 'add throws'),
            _message('3-good', 'books fine'),
          ],
          draftFor: (message, id) {
            if (message.id == '1-bad') throw const FormatException('bad');
            return _draft(id, '120.00');
          },
          isBooked: (_) => false,
          add: (draft) async {
            if (draft.id ==
                capturedTransactionId(_message('2-save-fails', ''))) {
              throw ArgumentError('Amount must be greater than zero.');
            }
            added.add(draft.id);
          },
          remove: (id) async => removed.add(id),
        );

        expect(created, 1);
        expect(added, [capturedTransactionId(_message('3-good', ''))]);
        // Every message leaves the inbox, so none can block later resumes.
        expect(removed, ['1-bad', '2-save-fails', '3-good']);
      },
    );

    test('never books a zero or negative amount', () async {
      final removed = <String>[];
      final booked = await _book(
        [_message('zero', ''), _message('negative', ''), _message('ok', '')],
        amountFor: (message) => switch (message.id) {
          'zero' => '0',
          'negative' => '-5',
          _ => '42.50',
        },
        removed: removed,
      );

      expect(booked, ['ok']);
      expect(removed, ['zero', 'negative', 'ok']);
    });

    test('a message that does not parse is dropped', () async {
      final removed = <String>[];
      final created = await bookCapturedMessages(
        [_message('unparsed', 'hello')],
        draftFor: (_, _) => null,
        isBooked: (_) => false,
        add: (_) async => fail('nothing to book'),
        remove: (id) async => removed.add(id),
      );

      expect(created, 0);
      expect(removed, ['unparsed']);
    });

    test('a failed removal does not stop the queue', () async {
      final added = <String>[];
      final created = await bookCapturedMessages(
        [_message('a', ''), _message('b', '')],
        draftFor: (message, id) => _draft(id, '10'),
        isBooked: (_) => false,
        add: (draft) async => added.add(draft.id),
        remove: (id) async {
          if (id == 'a') throw StateError('file locked');
        },
      );

      expect(created, 2);
      expect(added, hasLength(2));
    });

    test('the transaction id is stable per message and a UUID', () {
      final first = capturedTransactionId(_message('1760000000-7', 'x'));
      final again = capturedTransactionId(_message('1760000000-7', 'y'));
      final other = capturedTransactionId(_message('1760000000-8', 'x'));

      expect(first, again);
      expect(first, isNot(other));
      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test(
      'a message saved before the app stopped is removed, not booked again',
      () async {
        // The app was killed after saving the transaction but before removing
        // the message from the inbox; on the next run it is still queued.
        final message = _message('1-saved', 'Paid THB 120.00');
        final ledger = CaptureLedger();
        final removed = <String>[];
        final booked = await _book(
          [message, _message('2-new', 'Paid THB 99.00')],
          amountFor: (m) => m.id == '1-saved' ? '120.00' : '99.00',
          saved: {capturedTransactionId(message)},
          ledger: ledger,
          removed: removed,
        );

        expect(booked, ['2-new']);
        expect(removed, ['1-saved', '2-new']);
        // Remembered, so its SMS app notification still counts as a repeat.
        expect(ledger.contains('1-saved'), isTrue);
      },
    );

    test('a message the ledger already holds is only removed', () async {
      // Matched as a repeat, then the app stopped before removing it.
      final message = _message('2-repeat', 'Paid THB 120.00');
      final ledger = CaptureLedger([
        CaptureRecord.of(message, _draft('x', '120')).asDuplicateOf('1-sms'),
      ]);
      final removed = <String>[];
      final booked = await _book([message], ledger: ledger, removed: removed);

      expect(booked, isEmpty);
      expect(removed, ['2-repeat']);
    });

    test('an SMS and the SMS app notification of it book once', () async {
      const text = 'KBank: Paid THB 120.00 at CAFE AMAZON';
      final ledger = CaptureLedger();
      final booked = await _book([
        _message('1-sms', text),
        _message(
          '2-notification',
          'KBank $text',
          source: 'notification',
          sender: 'com.google.android.apps.messaging',
          at: _t0.add(const Duration(seconds: 2)),
        ),
      ], ledger: ledger);

      expect(booked, ['1-sms']);
      expect(ledger.records.last.duplicateOf, '1-sms');
    });

    test(
      'an SMS, the SMS app and the bank app notification book once',
      () async {
        final booked = await _book([
          _message('1-sms', 'Paid THB 120.00'),
          _message(
            '2-messages',
            'KBank Paid THB 120.00',
            source: 'notification',
            sender: 'com.google.android.apps.messaging',
          ),
          _message(
            '3-bank-app',
            'You paid 120 baht',
            source: 'notification',
            sender: 'com.kasikorn.retail.mbanking.wap',
            at: _t0.add(const Duration(minutes: 1)),
          ),
        ]);

        expect(booked, ['1-sms']);
      },
    );

    test('two equal purchases reported both ways stay two', () async {
      final booked = await _book([
        _message('1-sms', 'Paid THB 120.00'),
        _message('2-sms', 'Paid THB 120.00'),
        _message(
          '3-notification',
          'Paid THB 120.00, balance THB 880.00',
          source: 'notification',
          sender: 'bank.app',
        ),
        _message(
          '4-notification',
          'Paid THB 120.00, balance THB 760.00',
          source: 'notification',
          sender: 'bank.app',
          at: _t0.add(const Duration(seconds: 30)),
        ),
      ]);

      // Two SMS with the same text are two purchases; each notification
      // stands for one of them.
      expect(booked, ['1-sms', '2-sms']);
    });

    test('a notification posted again books once', () async {
      final booked = await _book([
        _message(
          '1-notification',
          'You paid 120 baht',
          source: 'notification',
          sender: 'bank.app',
        ),
        _message(
          '2-notification',
          '  you PAID 120   baht ',
          source: 'notification',
          sender: 'bank.app',
          at: _t0.add(const Duration(seconds: 40)),
        ),
      ]);

      expect(booked, ['1-notification']);
    });

    test('a re-posted SMS app notification stays a repeat', () async {
      final booked = await _book([
        _message('1-sms', 'Paid THB 120.00'),
        _message(
          '2-messages',
          'KBank Paid THB 120.00',
          source: 'notification',
          sender: 'sms.app',
        ),
        _message(
          '3-messages-again',
          'KBank Paid THB 120.00',
          source: 'notification',
          sender: 'sms.app',
          at: _t0.add(const Duration(seconds: 10)),
        ),
      ]);

      expect(booked, ['1-sms']);
    });

    test('different amounts, directions or times are separate', () async {
      final booked = await _book([
        _message('1-sms', 'Paid THB 120.00'),
        _message(
          '2-other-amount',
          'Paid THB 99.00',
          source: 'notification',
          sender: 'bank.app',
        ),
        _message(
          '3-later',
          'Paid THB 120.00',
          source: 'notification',
          sender: 'bank.app',
          at: _t0.add(captureDuplicateWindow + const Duration(seconds: 1)),
        ),
      ], amountFor: (m) => m.id == '2-other-amount' ? '99.00' : '120.00');
      expect(booked, ['1-sms', '2-other-amount', '3-later']);

      final directions = <String>[];
      final created = await bookCapturedMessages(
        [
          _message('1-out', 'Paid THB 120.00'),
          _message(
            '2-in',
            'Received THB 120.00',
            source: 'notification',
            sender: 'bank.app',
          ),
        ],
        draftFor: (message, id) => _draft(
          id,
          '120',
          type: message.id == '2-in'
              ? TransactionType.income
              : TransactionType.expense,
        ),
        isBooked: (_) => false,
        add: (draft) async => directions.add(draft.type.name),
        remove: (_) async {},
      );
      expect(created, 2);
      expect(directions, ['expense', 'income']);
    });

    test(
      'a repeat arriving in a later run is matched via the saved ledger',
      () async {
        String? stored;
        Future<void> save(CaptureLedger ledger) async =>
            stored = jsonEncode(ledger.toJson());

        final first = await _book(
          [_message('1-sms', 'Paid THB 120.00')],
          ledger: CaptureLedger(),
          saveLedger: save,
        );
        final second = await _book(
          [
            _message(
              '2-notification',
              'KBank Paid THB 120.00',
              source: 'notification',
              sender: 'sms.app',
              at: _t0.add(const Duration(seconds: 5)),
            ),
          ],
          ledger: CaptureLedger.fromJson(jsonDecode(stored!)),
          saveLedger: save,
        );

        expect(first, ['1-sms']);
        expect(second, isEmpty);
      },
    );

    test('a ledger that cannot be saved does not stop booking', () async {
      final removed = <String>[];
      final booked = await _book(
        [_message('1', 'Paid THB 120.00'), _message('2', 'Paid THB 99.00')],
        amountFor: (m) => m.id == '1' ? '120' : '99',
        ledger: CaptureLedger(),
        saveLedger: (_) async => throw const FileSystemException('disk full'),
        removed: removed,
      );

      expect(booked, ['1', '2']);
      expect(removed, ['1', '2']);
    });
  });

  group('CaptureLedger', () {
    test('keeps the most recent records only', () {
      final ledger = CaptureLedger();
      for (var i = 0; i < CaptureLedger.maxRecords + 5; i++) {
        ledger.add(
          CaptureRecord.of(_message('$i', 'Paid THB $i'), _draft('x', '1')),
        );
      }

      expect(ledger.records, hasLength(CaptureLedger.maxRecords));
      expect(ledger.contains('0'), isFalse);
      expect(ledger.contains('${CaptureLedger.maxRecords + 4}'), isTrue);
    });

    test('survives a JSON round trip', () {
      final ledger = CaptureLedger([
        CaptureRecord.of(_message('1', 'Paid THB 120'), _draft('x', '120.00')),
        CaptureRecord.of(
          _message('2', 'KBank Paid THB 120', source: 'notification'),
          _draft('y', '120'),
        ).asDuplicateOf('1'),
      ]);

      final copy = CaptureLedger.fromJson(
        jsonDecode(jsonEncode(ledger.toJson())),
      );

      expect(jsonEncode(copy.toJson()), jsonEncode(ledger.toJson()));
      expect(copy.records.last.duplicateOf, '1');
      // Amounts compare by value: "120.00" and "120" are the same.
      expect(copy.records.first.amount, copy.records.last.amount);
    });
  });

  group('captured messages', () {
    test('only money movements are queued', () {
      final sms = capturedSms(
        address: 'KBANK',
        body: ' Paid THB 120.00 at CAFE AMAZON ',
      );
      expect(sms, isNotNull);
      expect(sms!.source, 'sms');
      expect(sms.sender, 'KBANK');
      expect(sms.body, 'Paid THB 120.00 at CAFE AMAZON');
      expect(sms.origin, 'sms');

      expect(capturedSms(address: 'Mum', body: 'See you at 7?'), isNull);
      expect(
        capturedSms(
          address: 'KBANK',
          body: 'OTP 123456 for payment of THB 500',
        ),
        isNull,
      );
      expect(capturedSms(address: 'KBANK', body: null), isNull);
    });

    test('notifications: removals and Aiko\'s own are skipped', () {
      final posted = capturedNotification(
        packageName: 'com.bank.app',
        title: 'Payment',
        content: 'You paid THB 120.00',
      );
      expect(posted, isNotNull);
      expect(posted!.source, 'notification');
      expect(posted.sender, 'com.bank.app');
      expect(posted.body, 'Payment You paid THB 120.00');
      expect(posted.origin, 'notification:com.bank.app');

      expect(
        capturedNotification(
          packageName: 'com.bank.app',
          title: 'Payment',
          content: 'You paid THB 120.00',
          removed: true,
        ),
        isNull,
      );
      // A reminder Aiko posted itself ("฿5,000.00 · รายจ่าย").
      expect(
        capturedNotification(
          packageName: 'dev.pepo.aiko',
          title: 'Rent',
          content: '฿5,000.00 · รายจ่าย',
        ),
        isNull,
      );
      expect(
        capturedNotification(
          packageName: 'chat.app',
          title: 'Ploy',
          content: 'Lunch?',
        ),
        isNull,
      );
    });

    test('each capture gets its own inbox id', () {
      final a = capturedSms(address: 'B', body: 'Paid THB 1.00');
      final b = capturedSms(address: 'B', body: 'Paid THB 1.00');
      expect(a!.id, isNot(b!.id));
    });
  });

  group('TransactionCaptureSettings', () {
    test('unreadable storage is unknown, not off', () async {
      expect(
        await TransactionCaptureSettings.tryLoad(_ThrowingStorage()),
        isNull,
      );
      expect(
        (await TransactionCaptureSettings.load(_ThrowingStorage())).enabled,
        isFalse,
      );
    });

    test('reads what was saved; nothing or garbage is off', () async {
      final storage = MemorySecureStorageService();
      expect(
        (await TransactionCaptureSettings.tryLoad(storage))!.enabled,
        isFalse,
      );

      await const TransactionCaptureSettings(
        enabled: true,
        accountId: 'acc',
      ).save(storage);
      final saved = await TransactionCaptureSettings.tryLoad(storage);
      expect(saved!.enabled, isTrue);
      expect(saved.accountId, 'acc');

      await storage.write('transaction_capture_settings', '{not json');
      expect(
        (await TransactionCaptureSettings.tryLoad(storage))!.enabled,
        isFalse,
      );
    });
  });

  test('concurrent processInbox calls share one run', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final processor = container.read(transactionCaptureProcessorProvider);

    // Bootstrap and app resume firing together must not drain twice.
    final first = processor.processInbox();
    final second = container
        .read(transactionCaptureProcessorProvider)
        .processInbox();
    expect(identical(first, second), isTrue);
    await first;

    // Once finished, the next call starts a fresh run.
    final third = processor.processInbox();
    expect(identical(first, third), isFalse);
    await third;
  });
}
