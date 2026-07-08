import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../accounts/domain/account.dart';
import '../../categories/application/category_budget_progress_service.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// Layer 1 of Aiko's data access: a compact, read-only snapshot of the user's
/// finances, assembled on-device from the local Brick store and sent with each
/// chat request. The edge function folds it into the system prompt so the model
/// can answer "how am I doing" questions in a single round-trip — no server-side
/// data fetch, no extra Supabase reads, works offline-first.
///
/// Everything here is an aggregate or a short recent slice. We deliberately do
/// **not** ship the full ledger: it keeps tokens (and how much raw financial
/// data leaves the device for the LLM provider) bounded. Deeper, ad-hoc queries
/// are the job of Layer 2 (server-side tools), not this snapshot.
class AikoFinancialContext {
  const AikoFinancialContext({
    required this.baseCurrency,
    required this.asOf,
    required this.netWorth,
    required this.accounts,
    required this.monthIncome,
    required this.monthSpending,
    required this.budgets,
    required this.goals,
    required this.recentTransactions,
  });

  final String baseCurrency;
  final String asOf;
  final double netWorth;
  final List<({String name, String type, double balance})> accounts;
  final double monthIncome;
  final double monthSpending;
  final List<({String name, double limit, double spent, String pace})> budgets;
  final List<({String name, double pct, double current, double target})> goals;
  final List<({String date, String type, double amount, String? merchant})>
  recentTransactions;

  static const _maxAccounts = 12;
  static const _maxBudgets = 12;
  static const _maxGoals = 8;
  static const _maxTransactions = 15;

  /// Pure builder over already-loaded domain data (no I/O) so it can be unit
  /// tested without Riverpod. Amounts are summed as doubles in the reported
  /// base currency; multi-currency holdings are treated as approximate, which
  /// is acceptable for advisory context.
  ///
  /// After the budgets -> categories / goals -> accounts merge (PR5) the
  /// budget shape is sourced from [Category]s that have a `monthlyLimit`,
  /// and goals are [Account]s with `type = AccountType.goal`.
  factory AikoFinancialContext.from({
    required String baseCurrency,
    required List<Account> accounts,
    required List<Category> categories,
    required List<FinanceTransaction> transactions,
    required DateTime now,
  }) {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    bool inThisMonth(FinanceTransaction t) =>
        !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd);
    bool isPosted(FinanceTransaction t) =>
        t.status == TransactionStatus.posted ||
        t.status == TransactionStatus.draft;

    // Goal accounts are savings targets, not free cash, so they are excluded
    // from net worth / spend aggregation by the goal-specific check below.
    final activeAccounts = accounts.where((a) => a.isActive).toList();

    double netWorth = 0;
    for (final a in activeAccounts) {
      if (!a.includeInNetWorth) continue;
      if (a.type == AccountType.goal) continue;
      final sign =
          a.type == AccountType.loan ||
              a.type == AccountType.liability ||
              a.type == AccountType.creditCard
          ? -1.0
          : 1.0;
      netWorth += a.currentBalance.amount.toDouble() * sign;
    }

    double monthIncome = 0;
    double monthSpending = 0;
    for (final t in transactions) {
      if (!isPosted(t) || !inThisMonth(t)) continue;
      if (t.type == TransactionType.income) {
        monthIncome += t.amount.amount.toDouble();
      } else if (t.type == TransactionType.expense) {
        monthSpending += t.amount.amount.toDouble();
      }
    }

    const progressService = CategoryBudgetProgressService();
    final monthEndInclusive = monthEnd.subtract(
      const Duration(microseconds: 1),
    );
    final budgetRows = categories.where((c) => c.hasBudget).map((c) {
      final progress = progressService.progressFor(
        c,
        transactions,
        periodStart: monthStart,
        periodEnd: monthEndInclusive,
      );
      final pct = progress.ratio * 100;
      final pace = pct >= 100
          ? 'over'
          : pct >= 80
          ? 'high'
          : 'ok';
      return (
        name: c.name,
        limit: _round2(c.monthlyLimit!.amount.toDouble()),
        spent: _round2(progress.used.amount.toDouble()),
        pace: pace,
      );
    }).toList();

    final goalAccounts = activeAccounts.where(
      (a) => a.type == AccountType.goal,
    );
    final goalRows = goalAccounts.map((a) {
      final pct = (a.goalProgress * 100).clamp(0, 100).toDouble();
      return (
        name: a.name,
        pct: _round2(pct / 100),
        current: _round2(a.currentBalance.amount.toDouble()),
        target: _round2(a.targetAmount?.amount.toDouble() ?? 0),
      );
    }).toList();

    final sortedTx = [...transactions.where(isPosted)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = sortedTx.take(_maxTransactions).map((t) {
      return (
        date: t.date.toIso8601String().substring(0, 10),
        type: t.type.name,
        amount: _round2(t.amount.amount.toDouble()),
        merchant: t.merchant,
      );
    }).toList();

    return AikoFinancialContext(
      baseCurrency: baseCurrency,
      asOf: now.toIso8601String().substring(0, 10),
      netWorth: _round2(netWorth),
      accounts: activeAccounts
          .take(_maxAccounts)
          .map(
            (a) => (
              name: a.name,
              type: a.type.name,
              balance: _round2(a.currentBalance.amount.toDouble()),
            ),
          )
          .toList(),
      monthIncome: _round2(monthIncome),
      monthSpending: _round2(monthSpending),
      budgets: budgetRows.take(_maxBudgets).toList(),
      goals: goalRows.take(_maxGoals).toList(),
      recentTransactions: recent,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseCurrency': baseCurrency,
    'asOf': asOf,
    'netWorth': netWorth,
    'accounts': [
      for (final a in accounts)
        {'name': a.name, 'type': a.type, 'balance': a.balance},
    ],
    'thisMonth': {
      'income': monthIncome,
      'spending': monthSpending,
      'net': _round2(monthIncome - monthSpending),
    },
    'budgets': [
      for (final b in budgets)
        {'name': b.name, 'limit': b.limit, 'spent': b.spent, 'pace': b.pace},
    ],
    'goals': [
      for (final g in goals)
        {
          'name': g.name,
          'pct': g.pct,
          'current': g.current,
          'target': g.target,
        },
    ],
    'recentTransactions': [
      for (final t in recentTransactions)
        {
          'date': t.date,
          'type': t.type,
          'amount': t.amount,
          if (t.merchant != null) 'merchant': t.merchant,
        },
    ],
  };

  static double _round2(num value) => (value * 100).round() / 100;
}

/// Reads the local repositories (offline-first, no remote round-trip) and
/// reduces them into a snapshot. Returns null if anything fails — the chat
/// still works, just without pre-loaded context.
Future<AikoFinancialContext?> buildAikoFinancialContext(Ref ref) async {
  try {
    // Cap the local snapshot build so a slow/empty offline store (e.g. a fresh
    // install awaiting a hydrate that never comes) can't hang the chat. On
    // timeout the chat just proceeds without pre-loaded context.
    return await _readFinancialContext(ref).timeout(const Duration(seconds: 4));
  } catch (_) {
    return null;
  }
}

Future<AikoFinancialContext?> _readFinancialContext(Ref ref) async {
  final profile = await ref.read(profileRepositoryProvider).load();
  final accounts = await ref.read(accountRepositoryProvider).list();
  final categories = await ref.read(categoryRepositoryProvider).list();
  final transactions = await ref.read(transactionRepositoryProvider).list();
  return AikoFinancialContext.from(
    baseCurrency: profile.baseCurrency,
    accounts: accounts,
    categories: categories,
    transactions: transactions,
    now: DateTime.now(),
  );
}
