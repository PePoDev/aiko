import '../../core/money/money.dart';

class DemoData {
  const DemoData._();

  static final monthlyIncome = Money.parse('5200', 'USD');
  static final monthlySpending = Money.parse('2180', 'USD');
  static final safeToSpend = Money.parse('245', 'USD');
}
