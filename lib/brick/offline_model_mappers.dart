import 'dart:convert';

import '../core/money/money.dart';
import '../features/accounts/data/account_details_dto.dart';
import '../features/accounts/domain/account.dart';
import '../features/accounts/domain/account_details.dart';
import '../features/categories/domain/category.dart';
import '../features/investments/domain/investment_holding.dart';
import '../features/settings/domain/profile.dart';
import '../features/transactions/domain/transaction.dart';
import 'models/account.model.dart';
import 'models/category.model.dart';
import 'models/category_group.model.dart';
import 'models/investment_holding.model.dart';
import 'models/profile.model.dart';
import 'models/transaction.model.dart';

// Budgets -> Categories and Goals -> Accounts merge:
// - `Budget` / `Goal` domain models and their Brick models are gone. The
//   budget shape now lives on `Category` (`monthlyLimit`, `budgetPeriod`,
//   `rolloverUnused`, `alertThresholds`); the goal shape now lives on
//   `Account` with `type == AccountType.goal` (`targetAmount`, `targetDate`,
//   `priority`). Mappers only read the new shape; the one-time data migration
//   in `lib/core/sync/budget_goal_migration.dart` is responsible for
//   rewriting the legacy `budgets` / `goals` rows before the app reads from
//   them.

extension OfflineAccountMapper on OfflineAccount {
  Account toDomain() {
    return Account(
      id: id,
      userId: userId,
      name: name,
      type: _enumByName(AccountType.values, type, AccountType.cash),
      currentBalance: Money.parse(currentBalance, currency),
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive,
      details: _parseDetails(detailsJson),
      targetAmount: _parseMoney(goalTargetAmount, currency),
      targetDate: goalTargetDate,
      priority: _enumByName(
        GoalPriority.values,
        goalPriority,
        GoalPriority.medium,
      ),
    );
  }
}

extension AccountOfflineMapper on Account {
  OfflineAccount toOffline({required String userId}) {
    return OfflineAccount(
      id: id,
      userId: userId,
      name: name,
      type: type.name,
      currency: currency,
      currentBalance: currentBalance.amount.toString(),
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive,
      detailsJson: _detailsToJson(resolvedDetails),
      goalTargetAmount: targetAmount?.amount.toString(),
      goalTargetDate: targetDate,
      goalPriority: priority.name,
    );
  }
}

extension OfflineCategoryMapper on OfflineCategory {
  Category toDomain() {
    final budget = _parseMoneyPair(
      budgetAmount: budgetAmount,
      budgetCurrency: budgetCurrency,
    );
    return Category(
      id: id,
      userId: userId,
      name: name,
      type: _enumByName(CategoryType.values, type, CategoryType.expense),
      group: _enumByName(
        CategoryBudgetGroup.values,
        categoryGroup,
        CategoryBudgetGroup.custom,
      ),
      groupId: groupId,
      parentId: parentId,
      icon: icon,
      color: color,
      budgetEnabled: budgetEnabled,
      isActive: isActive,
      createdAt: createdAt,
      monthlyLimit: budget,
      budgetPeriod: _enumByName(
        CategoryBudgetPeriod.values,
        budgetPeriod,
        CategoryBudgetPeriod.monthly,
      ),
      rolloverUnused: budgetRollover,
      alertThresholds: alertThresholds.isEmpty
          ? Category.defaultAlertThresholds
          : alertThresholds,
    );
  }
}

extension CategoryOfflineMapper on Category {
  OfflineCategory toOffline({required String userId}) {
    return OfflineCategory(
      id: id,
      userId: userId,
      name: name,
      type: type.name,
      categoryGroup: group.name,
      groupId: groupId,
      parentId: parentId,
      icon: icon,
      color: color,
      budgetEnabled: budgetEnabled,
      isActive: isActive,
      createdAt: createdAt,
      budgetAmount: monthlyLimit?.amount.toString(),
      budgetCurrency: monthlyLimit?.currency,
      budgetPeriod: budgetPeriod.name,
      budgetRollover: rolloverUnused,
      alertThresholds: alertThresholds,
    );
  }
}

extension OfflineCategoryGroupMapper on OfflineCategoryGroup {
  CategoryGroup toDomain() {
    return CategoryGroup(
      id: id,
      userId: userId ?? '',
      name: name,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }
}

extension CategoryGroupOfflineMapper on CategoryGroup {
  OfflineCategoryGroup toOffline({required String userId}) {
    return OfflineCategoryGroup(
      id: id,
      userId: userId,
      name: name,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }
}

extension OfflineProfileMapper on OfflineProfile {
  Profile toDomain() {
    return Profile(
      id: id,
      displayName: displayName,
      email: email,
      baseCurrency: baseCurrency,
      country: country,
      onboardingStatus: _enumByName(
        OnboardingStatus.values,
        onboardingStatus,
        OnboardingStatus.notStarted,
      ),
      securityStatus: _enumByName(
        SecurityStatus.values,
        securityStatus,
        SecurityStatus.notConfigured,
      ),
      preferredTheme: _enumByName(
        PreferredTheme.values,
        preferredTheme,
        PreferredTheme.system,
      ),
    );
  }
}

extension ProfileOfflineMapper on Profile {
  OfflineProfile toOffline() {
    return OfflineProfile(
      id: id,
      displayName: displayName,
      email: email,
      baseCurrency: baseCurrency,
      country: country,
      preferredTheme: preferredTheme.name,
      onboardingStatus: onboardingStatus.name,
      securityStatus: securityStatus.name,
    );
  }
}

extension OfflineTransactionMapper on OfflineTransaction {
  FinanceTransaction toDomain() {
    return FinanceTransaction(
      id: id,
      userId: userId,
      accountId: accountId,
      type: _enumByName(TransactionType.values, type, TransactionType.expense),
      amount: Money.parse(amount, currency),
      date: date,
      categoryId: categoryId,
      merchant: merchant,
      note: note,
      tags: tags,
      status: _enumByName(
        TransactionStatus.values,
        status,
        TransactionStatus.posted,
      ),
      isRecurring: isRecurring,
      recurringFrequency: _optionalEnumByName(
        RecurringFrequency.values,
        recurringFrequency,
      ),
      recurringSettings: _buildRecurringSettings(),
    );
  }

  RecurringSettings? _buildRecurringSettings() {
    if (!isRecurring) {
      return null;
    }
    return RecurringSettings(
      endDate: recurringEndDate,
      maxOccurrences: recurringMaxOccurrences,
      dayOfWeek: recurringDayOfWeek,
      dayOfMonth: recurringDayOfMonth,
      monthOfYear: recurringMonthOfYear,
    );
  }
}

extension TransactionOfflineMapper on FinanceTransaction {
  OfflineTransaction toOffline({required String userId}) {
    return OfflineTransaction(
      id: id,
      userId: userId,
      accountId: accountId,
      type: type.name,
      amount: amount.amount.toString(),
      currency: amount.currency,
      date: date,
      categoryId: categoryId,
      merchant: merchant,
      note: note,
      tags: tags,
      status: status.name,
      isRecurring: isRecurring,
      recurringFrequency: recurringFrequency?.name,
      recurringEndDate: recurringSettings?.endDate,
      recurringMaxOccurrences: recurringSettings?.maxOccurrences,
      recurringDayOfWeek: recurringSettings?.dayOfWeek,
      recurringDayOfMonth: recurringSettings?.dayOfMonth,
      recurringMonthOfYear: recurringSettings?.monthOfYear,
    );
  }
}

extension OfflineInvestmentHoldingMapper on OfflineInvestmentHolding {
  InvestmentHolding toDomain() {
    return InvestmentHolding(
      id: id,
      userId: userId,
      symbol: symbol,
      assetClass: assetClass,
      quantity: double.parse(quantity),
      averageCost: Money.parse(averageCost, currency),
      currentPrice: Money.parse(currentPrice, currency),
      targetAllocationPercent: targetAllocationPercent,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension InvestmentHoldingOfflineMapper on InvestmentHolding {
  OfflineInvestmentHolding toOffline({required String userId}) {
    return OfflineInvestmentHolding(
      id: id,
      userId: userId,
      symbol: symbol,
      assetClass: assetClass,
      quantity: quantity.toString(),
      averageCost: averageCost.amount.toString(),
      currentPrice: currentPrice.amount.toString(),
      currency: currentPrice.currency,
      marketValue: marketValue.amount.toString(),
      targetAllocationPercent: targetAllocationPercent,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

T _enumByName<T extends Enum>(Iterable<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

T? _optionalEnumByName<T extends Enum>(Iterable<T> values, String? name) {
  if (name == null) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

Money? _parseMoney(String? amount, String fallbackCurrency) {
  if (amount == null || amount.isEmpty) return null;
  try {
    return Money.parse(amount, fallbackCurrency);
  } catch (_) {
    return null;
  }
}

Money? _parseMoneyPair({
  required String? budgetAmount,
  required String? budgetCurrency,
}) {
  if (budgetAmount == null || budgetAmount.isEmpty) return null;
  if (budgetCurrency == null || budgetCurrency.isEmpty) return null;
  try {
    return Money.parse(budgetAmount, budgetCurrency);
  } catch (_) {
    return null;
  }
}

AccountDetails? _parseDetails(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return AccountDetailsDto.fromJson(decoded);
    }
  } catch (_) {}
  return null;
}

String _detailsToJson(AccountDetails d) {
  return jsonEncode(AccountDetailsDto.toJson(d));
}
