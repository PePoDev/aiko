import '../../../core/money/money.dart';

enum DashboardDueItemKind { bill, creditCard }

class DashboardDueItem {
  const DashboardDueItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.kind,
  });

  final String id;
  final String title;
  final Money amount;
  final DateTime dueDate;
  final DashboardDueItemKind kind;

  int daysUntil(DateTime asOf) => dueDate.difference(asOf).inDays;
}
