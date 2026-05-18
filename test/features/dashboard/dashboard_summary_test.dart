import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/dashboard/application/dashboard_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard service totals active cash accounts', () {
    const service = DashboardSummaryService();
    final total = service.totalCash([
      Account(
        id: 'cash',
        userId: 'user',
        name: 'Cash',
        type: AccountType.cash,
        openingBalance: Money.zero('USD'),
        currentBalance: Money.parse('100', 'USD'),
      ),
    ], 'USD');

    expect(total.amount.toString(), '100');
  });
}
