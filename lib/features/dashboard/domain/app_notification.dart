import '../../../core/formatting/money_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_names.dart';
import '../../transactions/domain/transaction.dart';
import 'dashboard_due_item.dart';

/// Where a derived notification belongs in the Notifications Center. Used only
/// for grouping in the UI.
enum AppNotificationGroup { budget, bills, goals }

/// Maps to a semantic color in the UI; kept framework-light here (no Flutter).
enum AppNotificationSeverity { info, success, warning, danger }

/// A notification derived on the fly from the user's real local data. There is
/// no notifications table — these are recomputed from transactions/categories/
/// accounts/due-items each time the screen opens.
class AppNotification {
  const AppNotification({
    required this.group,
    required this.title,
    required this.subtitle,
    required this.severity,
  });

  final AppNotificationGroup group;
  final String title;
  final String subtitle;
  final AppNotificationSeverity severity;
}

/// Derives notifications from real data. Pure + framework-free so it is unit
/// testable. Three sources: budget threshold breaches, upcoming credit-card
/// bills, and goal milestones.
List<AppNotification> buildNotifications({
  required List<FinanceTransaction> transactions,
  required List<Category> categories,
  required List<Account> accounts,
  required List<DashboardDueItem> dueItems,
  required DateTime asOf,
  required AppLocalizations l10n,
}) {
  final result = <AppNotification>[];

  // Budget alerts: this-month posted expense vs the category's limit, against
  // its own alert thresholds (default 50/75/90/100%).
  final spentByCategory = <String, double>{};
  for (final tx in transactions) {
    if (!tx.isExpense || tx.status != TransactionStatus.posted) continue;
    if (tx.date.year != asOf.year || tx.date.month != asOf.month) continue;
    final id = tx.categoryId;
    if (id == null) continue;
    spentByCategory[id] =
        (spentByCategory[id] ?? 0) + tx.amount.amount.toDouble();
  }
  for (final cat in categories) {
    if (!cat.hasBudget) continue;
    final limit = cat.monthlyLimit!.amount.toDouble();
    if (limit <= 0) continue;
    final pct = ((spentByCategory[cat.id] ?? 0) / limit * 100).round();
    int? crossed;
    for (final t in [...cat.alertThresholds]..sort()) {
      if (pct >= t) crossed = t;
    }
    if (crossed == null) continue;
    result.add(
      AppNotification(
        group: AppNotificationGroup.budget,
        title: cat.displayName(l10n),
        subtitle: l10n.notifBudgetUsed(pct, cat.displayName(l10n)),
        severity: pct >= 100
            ? AppNotificationSeverity.danger
            : AppNotificationSeverity.warning,
      ),
    );
  }

  // Upcoming bills: due items landing within the next week.
  for (final item in dueItems) {
    final days = item.daysUntil(asOf);
    if (days < 0 || days > 7) continue;
    final amount = item.amount.format();
    result.add(
      AppNotification(
        group: AppNotificationGroup.bills,
        title: item.title,
        subtitle: days == 0
            ? l10n.notifDueToday(amount)
            : days == 1
            ? l10n.notifDueTomorrow(amount)
            : l10n.notifDueInDays(amount, days),
        severity: days <= 2
            ? AppNotificationSeverity.warning
            : AppNotificationSeverity.info,
      ),
    );
  }

  // Goal milestones: goal accounts crossing 50% and 100% funded.
  for (final account in accounts) {
    if (!account.isGoal) continue;
    final pct = (account.goalProgress * 100).round();
    if (pct >= 100) {
      result.add(
        AppNotification(
          group: AppNotificationGroup.goals,
          title: account.name,
          subtitle: l10n.notifGoalReached(account.name),
          severity: AppNotificationSeverity.success,
        ),
      );
    } else if (pct >= 50) {
      result.add(
        AppNotification(
          group: AppNotificationGroup.goals,
          title: account.name,
          subtitle: l10n.notifGoalProgress(account.name, pct),
          severity: AppNotificationSeverity.success,
        ),
      );
    }
  }

  return result;
}
