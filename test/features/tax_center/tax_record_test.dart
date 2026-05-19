import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/tax_center/application/tax_center_service.dart';
import 'package:aiko/features/tax_center/domain/tax_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups tax records and totals deductible expenses', () {
    final records = [
      TaxRecord(
        taxYear: 2026,
        amount: Money.parse('100', 'USD'),
        deductionType: 'business',
      ),
    ];

    expect(const TaxCenterService().groupByYear(records).keys.single, 2026);
    expect(
      const TaxCenterService()
          .deductibleTotal(records, 'USD')
          .amount
          .toString(),
      '100',
    );
  });
}
