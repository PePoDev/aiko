import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../credit_cards/domain/credit_card_detail.dart';
import '../application/dashboard_due_item_service.dart';
import '../domain/dashboard_due_item.dart';

class DashboardDueItemRepository {
  const DashboardDueItemRepository({
    DashboardDueItemService service = const DashboardDueItemService(),
  }) : _service = service;

  final DashboardDueItemService _service;

  Future<List<DashboardDueItem>> loadUpcomingItems(DateTime asOf) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return const [];
    }

    final List<dynamic> cardsResponse;
    try {
      cardsResponse = await client
          .from('credit_card_profiles')
          .select()
          .eq('user_id', user.id);
    } catch (_) {
      return const [];
    }

    return _service.upcomingItems(
      creditCards: cardsResponse
          .map(
            (row) => _creditCardFromRow(Map<String, dynamic>.from(row), asOf),
          )
          .toList(growable: false),
      asOf: asOf,
    );
  }

  static CreditCardDetail _creditCardFromRow(
    Map<String, dynamic> row,
    DateTime asOf,
  ) {
    final currency = row['currency'] as String? ?? 'THB';
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
