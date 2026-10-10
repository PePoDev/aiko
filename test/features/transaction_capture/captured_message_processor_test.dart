import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/transaction_capture/transaction_capture.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedMessage _message(String id, String body) => CapturedMessage(
  id: id,
  source: 'sms',
  sender: 'BANK',
  body: body,
  receivedAt: DateTime(2026, 10, 13, 10, 25),
);

FinanceTransaction _draft(String id, String amount) => FinanceTransaction(
  id: id,
  userId: '',
  accountId: 'acc',
  type: TransactionType.expense,
  amount: Money(amount: Decimal.parse(amount), currency: 'THB'),
  date: DateTime(2026, 10, 13),
);

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
          draftFor: (message) {
            if (message.id == '1-bad') throw const FormatException('bad');
            return _draft(message.id, '120.00');
          },
          add: (draft) async {
            if (draft.id == '2-save-fails') {
              throw ArgumentError('Amount must be greater than zero.');
            }
            added.add(draft.id);
          },
          remove: (id) async => removed.add(id),
        );

        expect(created, 1);
        expect(added, ['3-good']);
        // Every message leaves the inbox, so none can block later resumes.
        expect(removed, ['1-bad', '2-save-fails', '3-good']);
      },
    );

    test('never books a zero or negative amount', () async {
      final added = <String>[];
      final removed = <String>[];
      final created = await bookCapturedMessages(
        [
          _message('zero', ''),
          _message('negative', ''),
          _message('unparsed', ''),
          _message('ok', ''),
        ],
        draftFor: (message) => switch (message.id) {
          'zero' => _draft('zero', '0'),
          'negative' => _draft('negative', '-5'),
          'unparsed' => null,
          _ => _draft('ok', '42.50'),
        },
        add: (draft) async => added.add(draft.id),
        remove: (id) async => removed.add(id),
      );

      expect(created, 1);
      expect(added, ['ok']);
      expect(removed, ['zero', 'negative', 'unparsed', 'ok']);
    });

    test('a failed removal does not stop the queue', () async {
      final added = <String>[];
      final created = await bookCapturedMessages(
        [_message('a', ''), _message('b', '')],
        draftFor: (message) => _draft(message.id, '10'),
        add: (draft) async => added.add(draft.id),
        remove: (id) async {
          if (id == 'a') throw StateError('file locked');
        },
      );

      expect(created, 2);
      expect(added, ['a', 'b']);
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
