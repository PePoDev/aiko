import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/dashboard_due_item.dart';

class DashboardDueItemRepository {
  const DashboardDueItemRepository();

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

    final cutoff = asOf.add(const Duration(days: 30));
    final items = <DashboardDueItem>[];
    for (final raw in cardsResponse) {
      final row = Map<String, dynamic>.from(raw);
      final currency = row['currency'] as String? ?? 'THB';
      final statementBalance = Money.parse(
        '${row['statement_balance'] ?? 0}',
        currency,
      );
      if (statementBalance.isZero) continue;
      final due = _nextDateForDay(asOf, row['due_day'] as int? ?? 1);
      if (due.isBefore(asOf) || due.isAfter(cutoff)) continue;
      items.add(
        DashboardDueItem(
          id: row['id'] as String,
          title: 'Credit card payment',
          amount: statementBalance,
          dueDate: due,
        ),
      );
    }
    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
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
