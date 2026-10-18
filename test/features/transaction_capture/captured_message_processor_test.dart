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
  String? key,
}) => CapturedMessage(
  id: id,
  source: source,
  sender: sender,
  body: body,
  receivedAt: at ?? _t0,
  notificationKey: key,
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
/// returning the ids of the messages that became transactions. [writes]
/// collects the messages of each write; a message in [failing] can't be
/// saved.
Future<List<String>> _book(
  List<CapturedMessage> messages, {
  String amount = '120.00',
  String Function(CapturedMessage message)? amountFor,
  Set<String> saved = const {},
  CaptureLedger? ledger,
  Future<void> Function(CaptureLedger ledger)? saveLedger,
  List<String>? removed,
  List<List<String>>? writes,
  Map<String, Object> failing = const {},
}) async {
  final bookedMessages = <String>[];
  final byTransaction = {
    for (final message in messages) capturedTransactionId(message): message.id,
  };
  await bookCapturedMessages(
    messages,
    draftFor: (message, id) => _draft(id, amountFor?.call(message) ?? amount),
    isBooked: saved.contains,
    add: (drafts) async {
      final ids = [for (final draft in drafts) byTransaction[draft.id]!];
      for (final id in ids) {
        if (failing[id] case final error?) throw error;
      }
      writes?.add(ids);
      bookedMessages.addAll(ids);
    },
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bookCapturedMessages', () {
    test('every new message is booked in one write', () async {
      final writes = <List<String>>[];
      final removed = <String>[];
      final booked = await _book(
        [
          _message('1-sms', 'Paid THB 120.00'),
          _message('2-sms', 'Paid THB 99.00'),
          _message(
            '3-notification',
            'You paid 45 baht',
            source: 'notification',
            sender: 'wallet.app',
          ),
        ],
        amountFor: (m) => switch (m.id) {
          '1-sms' => '120',
          '2-sms' => '99',
          _ => '45',
        },
        writes: writes,
        removed: removed,
      );

      // One write, so the account balance is set once and never races.
      expect(writes, [
        ['1-sms', '2-sms', '3-notification'],
      ]);
      expect(booked, ['1-sms', '2-sms', '3-notification']);
      expect(removed, ['1-sms', '2-sms', '3-notification']);
    });

    test('a very long inbox takes a few writes', () async {
      final writes = <List<String>>[];
      final messages = [
        for (var i = 0; i < 450; i++)
          _message(i.toString().padLeft(4, '0'), 'Paid THB $i'),
      ];
      final booked = await _book(
        messages,
        amountFor: (m) => '${int.parse(m.id) + 1}',
        writes: writes,
      );

      expect(booked, hasLength(450));
      expect(writes.map((w) => w.length), [400, 50]);
    });

    test(
      'a message that can\'t be saved stays queued; the rest are booked',
      () async {
        final writes = <List<String>>[];
        final removed = <String>[];
        final ledger = CaptureLedger();
        final booked = await _book(
          [
            _message('1-ok', 'Paid THB 120.00'),
            _message('2-stuck', 'Paid THB 99.00'),
            _message('3-ok', 'Paid THB 45.00'),
          ],
          amountFor: (m) => switch (m.id) {
            '1-ok' => '120',
            '2-stuck' => '99',
            _ => '45',
          },
          failing: {'2-stuck': StateError('store unavailable')},
          writes: writes,
          ledger: ledger,
          removed: removed,
        );

        // The write of all three failed, so each was tried on its own.
        expect(writes, [
          ['1-ok'],
          ['3-ok'],
        ]);
        expect(booked, ['1-ok', '3-ok']);
        // Left in the inbox for the next run, which books it once.
        expect(removed, ['1-ok', '3-ok']);
        expect(ledger.contains('2-stuck'), isFalse);
      },
    );

    test('nothing is lost while saving fails altogether', () async {
      final removed = <String>[];
      final ledger = CaptureLedger();
      final booked = await _book(
        [_message('1-sms', 'Paid THB 120.00'), _message('2-sms', 'x')],
        amountFor: (m) => m.id == '1-sms' ? '120' : '99',
        // Say the transactions list was disposed in the middle of the run.
        failing: {
          '1-sms': StateError('disposed'),
          '2-sms': StateError('disposed'),
        },
        ledger: ledger,
        removed: removed,
      );

      expect(booked, isEmpty);
      expect(removed, isEmpty);
      expect(ledger.records, isEmpty);
    });

    test('a repeat books in place of a message that cannot be saved', () async {
      final removed = <String>[];
      final ledger = CaptureLedger();
      final messages = [
        _message('1-sms', 'Paid THB 120.00'),
        _message(
          '2-notification',
          'KBank Paid THB 120.00',
          source: 'notification',
          sender: 'sms.app',
        ),
      ];
      final booked = await _book(
        messages,
        failing: {'1-sms': StateError('disposed')},
        ledger: ledger,
        removed: removed,
      );

      // The notification of the SMS that couldn't be saved books in its
      // place; the SMS stays queued and is matched to it next time.
      expect(booked, ['2-notification']);
      expect(removed, ['2-notification']);

      final retried = await _book([messages.first], ledger: ledger);
      expect(retried, isEmpty);
      expect(
        ledger.records.singleWhere((r) => r.id == '1-sms').duplicateOf,
        '2-notification',
      );
    });

    test('a draft the store rejects as invalid is dropped', () async {
      final removed = <String>[];
      final booked = await _book(
        [_message('1-invalid', 'Paid THB 1.00'), _message('2-ok', 'x')],
        amountFor: (m) => m.id == '1-invalid' ? '1' : '2',
        failing: {'1-invalid': ArgumentError('Split total must equal amount')},
        removed: removed,
      );

      // No retry would fix it, so it doesn't stay queued.
      expect(booked, ['2-ok']);
      expect(removed, ['1-invalid', '2-ok']);
    });

    test('a message whose draft cannot be built is dropped', () async {
      final added = <String>[];
      final removed = <String>[];
      final created = await bookCapturedMessages(
        [
          _message('1-bad', 'throws while building'),
          _message('2-good', 'books fine'),
        ],
        draftFor: (message, id) {
          if (message.id == '1-bad') throw const FormatException('bad');
          return _draft(id, '120.00');
        },
        isBooked: (_) => false,
        add: (drafts) async => added.addAll(drafts.map((d) => d.id)),
        remove: (id) async => removed.add(id),
      );

      expect(created, 1);
      expect(added, [capturedTransactionId(_message('2-good', ''))]);
      expect(removed, ['1-bad', '2-good']);
    });

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
        add: (drafts) async => added.addAll(drafts.map((d) => d.id)),
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

    test(
      'a saved message is recognised before an earlier repeat of it books',
      () async {
        // The bank app's notification was booked, but the app stopped before
        // recording it; the SMS of the same payment sorts before it.
        final notification = _message(
          '2-notification',
          'You paid 120 baht',
          source: 'notification',
          sender: 'bank.app',
        );
        final ledger = CaptureLedger();
        final removed = <String>[];
        final booked = await _book(
          [_message('1-sms', 'Paid THB 120.00'), notification],
          saved: {capturedTransactionId(notification)},
          ledger: ledger,
          removed: removed,
        );

        expect(booked, isEmpty);
        expect(removed, ['1-sms', '2-notification']);
        expect(
          ledger.records.singleWhere((r) => r.id == '1-sms').duplicateOf,
          '2-notification',
        );
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

    test('the same text from one app minutes apart is two payments', () async {
      // An e-wallet that says nothing but the amount and the shop.
      final booked = await _book([
        _message(
          '1-notification',
          'You paid 60 baht to Cafe Amazon',
          source: 'notification',
          sender: 'wallet.app',
          key: '0|wallet.app|101|null|10123',
        ),
        _message(
          '2-notification',
          'You paid 60 baht to Cafe Amazon',
          source: 'notification',
          sender: 'wallet.app',
          key: '0|wallet.app|102|null|10123',
          at: _t0.add(const Duration(minutes: 3)),
        ),
      ]);

      expect(booked, ['1-notification', '2-notification']);
    });

    test('one notification updated minutes later books once', () async {
      const key = '0|bank.app|7|null|10123';
      final booked = await _book([
        _message(
          '1-notification',
          'You paid 120 baht',
          source: 'notification',
          sender: 'bank.app',
          key: key,
        ),
        _message(
          '2-notification',
          'You paid 120 baht',
          source: 'notification',
          sender: 'bank.app',
          key: key,
          at: _t0.add(const Duration(minutes: 3)),
        ),
      ]);

      expect(booked, ['1-notification']);
    });

    test('a group summary repeating a notification books once', () async {
      final booked = await _book([
        _message(
          '1-notification',
          'You paid 120 baht',
          source: 'notification',
          sender: 'bank.app',
          key: '0|bank.app|7|null|10123',
        ),
        _message(
          '2-summary',
          'You paid 120 baht',
          source: 'notification',
          sender: 'bank.app',
          key: '0|bank.app|0|g:payments|10123',
          at: _t0.add(const Duration(seconds: 1)),
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
        add: (drafts) async =>
            directions.addAll(drafts.map((d) => d.type.name)),
        remove: (_) async {},
      );
      expect(created, 2);
      expect(directions, ['expense', 'income']);
    });

    test('a late SMS still matches the bank app notification', () async {
      final notifiedAt = DateTime.now().subtract(const Duration(minutes: 9));
      final ledger = CaptureLedger();
      final first = await _book([
        _message(
          '1-notification',
          'You paid 120 baht',
          source: 'notification',
          sender: 'bank.app',
          at: notifiedAt,
        ),
      ], ledger: ledger);
      // The carrier delivers the bank's SMS nine minutes late; it is dated
      // when it was sent.
      final sms = capturedSms(
        address: 'KBANK',
        body: 'Paid THB 120.00',
        timestamp: notifiedAt.millisecondsSinceEpoch,
      )!;
      final second = await _book([sms], ledger: ledger);

      expect(first, ['1-notification']);
      expect(second, isEmpty);
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
          _message(
            '2',
            'KBank Paid THB 120',
            source: 'notification',
            key: '0|sms.app|3|null|10123',
          ),
          _draft('y', '120'),
        ).asDuplicateOf('1'),
      ]);

      final copy = CaptureLedger.fromJson(
        jsonDecode(jsonEncode(ledger.toJson())),
      );

      expect(jsonEncode(copy.toJson()), jsonEncode(ledger.toJson()));
      expect(copy.records.last.duplicateOf, '1');
      expect(copy.records.first.keyHash, isNull);
      expect(copy.records.last.keyHash, ledger.records.last.keyHash);
      // Only a hash of the key is kept.
      expect(copy.records.last.keyHash, isNot(contains('sms.app')));
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

    test('notifications: Aiko\'s own and other texts are skipped', () {
      final posted = capturedNotification(
        packageName: 'com.bank.app',
        title: 'Payment',
        content: 'You paid THB 120.00',
        key: '0|com.bank.app|7|null|10123',
      );
      expect(posted, isNotNull);
      expect(posted!.source, 'notification');
      expect(posted.sender, 'com.bank.app');
      expect(posted.body, 'Payment You paid THB 120.00');
      expect(posted.origin, 'notification:com.bank.app');
      expect(posted.notificationKey, '0|com.bank.app|7|null|10123');
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

    test('reads the events of Aiko\'s notification listener', () {
      final posted = capturedNotificationEvent({
        'packageName': 'com.bank.app',
        'key': '0|com.bank.app|7|null|10123',
        'title': 'Payment',
        'content': 'You paid THB 120.00',
      });
      expect(posted!.sender, 'com.bank.app');
      expect(posted.body, 'Payment You paid THB 120.00');
      expect(posted.notificationKey, '0|com.bank.app|7|null|10123');

      expect(
        capturedNotificationEvent({
          'packageName': 'com.bank.app',
          'title': null,
          'content': 'You paid THB 120.00',
        })!.body,
        'You paid THB 120.00',
      );
      expect(capturedNotificationEvent('not a map'), isNull);
      expect(
        capturedNotificationEvent({'packageName': 'chat.app', 'content': 7}),
        isNull,
      );
    });

    test('an SMS is dated when it was sent, within reason', () {
      final now = DateTime(2026, 10, 18, 0, 7);
      final sent = DateTime(2026, 10, 17, 23, 58);

      expect(smsSentAt(sent.millisecondsSinceEpoch, now), sent);
      expect(smsSentAt(null, now), now);
      // A service centre clock ahead of the phone, or years off.
      expect(
        smsSentAt(
          now.add(const Duration(hours: 7)).millisecondsSinceEpoch,
          now,
        ),
        now,
      );
      expect(smsSentAt(DateTime(2000).millisecondsSinceEpoch, now), now);
      // Held for days (phone off) is still believable.
      final daysAgo = now.subtract(const Duration(days: 3));
      expect(smsSentAt(daysAgo.millisecondsSinceEpoch, now), daysAgo);
    });

    test('a queued message keeps its notification key', () {
      final message = _message(
        '1',
        'You paid 120 baht',
        source: 'notification',
        key: '0|bank.app|7|null|10123',
      );
      final copy = CapturedMessage.fromJson(
        jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
      );
      expect(copy.notificationKey, '0|bank.app|7|null|10123');
      expect(
        CapturedMessage.fromJson(
          _message('2', 'Paid THB 1').toJson(),
        ).notificationKey,
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
