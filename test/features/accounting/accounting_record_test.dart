import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounting/application/accounting_service.dart';
import 'package:aiko/features/accounting/domain/accounting_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters pending accounting records', () {
    final pending = const AccountingService().pendingReconciliation([
      AccountingRecord(entryType: 'expense', amount: Money.parse('50', 'USD')),
    ]);

    expect(pending, hasLength(1));
  });
}
