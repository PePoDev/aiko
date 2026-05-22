import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../bills/domain/bill_subscription.dart';
import '../../credit_cards/domain/credit_card_detail.dart';
import '../application/dashboard_due_item_service.dart';
import '../domain/dashboard_due_item.dart';

class DashboardDueItemRepository {
  const DashboardDueItemRepository({
    DashboardDueItemService service = const DashboardDueItemService(),
  }) : _service = service;

  final DashboardDueItemService _service;

  Future<List<DashboardDueItem>> loadUpcomingItems(DateTime asOf) async {
    final session = AikoSupabase.requireSession();
    final windowEnd = asOf.add(const Duration(days: 30));
    final billsResponse = await session.client
        .from('bill_subscriptions')
        .select()
        .eq('user_id', session.userId)
        .neq('cancellation_status', 'canceled')
        .gte('next_billing_date', asOf.toIso8601String().substring(0, 10))
        .lte('next_billing_date', windowEnd.toIso8601String().substring(0, 10))
        .order('next_billing_date');
    final cardsResponse = await session.client
        .from('credit_card_profiles')
        .select()
        .eq('user_id', session.userId);

    return _service.upcomingItems(
      bills: billsResponse
          .map((row) => _billFromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      creditCards: cardsResponse
          .map(
            (row) => _creditCardFromRow(Map<String, dynamic>.from(row), asOf),
          )
          .toList(growable: false),
      asOf: asOf,
    );
  }

  static BillSubscription _billFromRow(Map<String, dynamic> row) {
    final cycle = BillingCycle.values.firstWhere(
      (item) => item.name == row['billing_cycle'],
      orElse: () => BillingCycle.monthly,
    );
    final cancellationStatus = CancellationStatus.values.firstWhere(
      (item) =>
          item.name == (row['cancellation_status'] as String? ?? 'active'),
      orElse: () => CancellationStatus.active,
    );
    final currency = row['currency'] as String? ?? 'USD';

    return BillSubscription(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      merchant: row['merchant'] as String,
      amount: Money.parse('${row['amount'] ?? 0}', currency),
      billingCycle: cycle,
      nextDueDate: DateTime.parse(row['next_billing_date'] as String),
      categoryId: row['category_id'] as String?,
      cancellationStatus: cancellationStatus,
    );
  }

  static CreditCardDetail _creditCardFromRow(
    Map<String, dynamic> row,
    DateTime asOf,
  ) {
    final currency = row['currency'] as String? ?? 'USD';
    final dueDay = row['due_day'] as int? ?? 1;
    final paymentDueDate = _nextDateForDay(asOf, dueDay);

    return CreditCardDetail(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      accountId: row['account_id'] as String,
      statementBalance: Money.parse(
        '${row['statement_balance'] ?? 0}',
        currency,
      ),
      paymentDueDate: paymentDueDate,
      creditLimit: Money.parse('${row['credit_limit'] ?? 0}', currency),
      aprPercent: (row['apr'] as num?)?.toDouble(),
      minimumPayment: Money.parse('${row['minimum_payment'] ?? 0}', currency),
      annualFee: Money.parse('${row['annual_fee'] ?? 0}', currency),
    );
  }

  static DateTime _nextDateForDay(DateTime asOf, int requestedDay) {
    final day = requestedDay.clamp(1, 31);
    var candidate = DateTime(
      asOf.year,
      asOf.month,
      day.clamp(1, DateTime(asOf.year, asOf.month + 1, 0).day).toInt(),
    );
    if (candidate.isBefore(asOf)) {
      final nextMonthLastDay = DateTime(asOf.year, asOf.month + 2, 0).day;
      candidate = DateTime(
        asOf.year,
        asOf.month + 1,
        day.clamp(1, nextMonthLastDay).toInt(),
      );
    }
    return candidate;
  }
}
