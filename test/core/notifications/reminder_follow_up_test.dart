import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/notifications/transaction_reminder_service.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction _tx(String id) => FinanceTransaction(
  id: id,
  userId: 'user-1',
  accountId: 'cash',
  type: TransactionType.expense,
  amount: Money.parse('10', 'THB'),
  date: DateTime(2026, 10, 20),
  reminderAt: DateTime(2026, 10, 19, 9),
);

void main() {
  test("a transaction's notification ids are stable and distinct", () {
    final ids = reminderNotificationIds('tx-1');
    expect(ids, reminderNotificationIds('tx-1'));
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.every((id) => id >= 0 && id <= 0x7fffffff), isTrue);
    expect(
      ids.toSet().intersection(reminderNotificationIds('tx-2').toSet()),
      isEmpty,
    );
  });

  test('only transactions with a reminder booked here are followed', () {
    final booked = {
      reminderNotificationIds('deleted').first,
      // A bounded series books per-occurrence slots only.
      reminderNotificationIds('edited')[3],
    };

    final plan = planReminderFollowUp(
      booked: booked,
      removedIds: ['deleted', 'never-reminded'],
      changed: [_tx('edited'), _tx('elsewhere-only')],
    );

    expect(plan.cancel, ['deleted']);
    expect(plan.reschedule.map((t) => t.id), ['edited']);
  });

  test('nothing is followed when nothing is booked', () {
    final plan = planReminderFollowUp(
      booked: const {},
      removedIds: ['a'],
      changed: [_tx('b')],
    );

    expect(plan.cancel, isEmpty);
    expect(plan.reschedule, isEmpty);
  });
}
