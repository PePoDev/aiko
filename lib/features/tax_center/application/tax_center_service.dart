import '../../../core/money/money.dart';
import '../domain/tax_record.dart';

class TaxCenterService {
  const TaxCenterService();

  Money deductibleTotal(List<TaxRecord> records, String currency) {
    return records
        .where((record) => record.isDeductible)
        .fold(Money.zero(currency), (total, record) => total + record.amount);
  }

  Map<int, List<TaxRecord>> groupByYear(List<TaxRecord> records) {
    final grouped = <int, List<TaxRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.taxYear, () => []).add(record);
    }
    return grouped;
  }
}
