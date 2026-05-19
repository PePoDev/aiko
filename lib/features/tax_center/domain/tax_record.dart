import '../../../core/money/money.dart';

class TaxRecord {
  const TaxRecord({
    required this.taxYear,
    required this.amount,
    this.deductionType,
    this.estimateOnly = true,
  });

  final int taxYear;
  final Money amount;
  final String? deductionType;
  final bool estimateOnly;

  bool get isDeductible => deductionType != null;
}
