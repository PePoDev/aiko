import 'dart:convert';

import '../core/money/money.dart';
import '../features/accounts/data/account_details_dto.dart';
import '../features/accounts/domain/account.dart';
import '../features/accounts/domain/account_details.dart';
import '../features/budgets/domain/budget.dart';
import '../features/categories/domain/category.dart';
import '../features/goals/domain/goal.dart';
import '../features/investments/domain/investment_holding.dart';
import '../features/settings/domain/profile.dart';
import '../features/transactions/domain/transaction.dart';
import 'models/account.model.dart';
import 'models/budget.model.dart';
import 'models/category.model.dart';
import 'models/category_group.model.dart';
import 'models/goal.model.dart';
import 'models/investment_holding.model.dart';
import 'models/profile.model.dart';
import 'models/transaction.model.dart';

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
    );
  }
}

extension OfflineBudgetMapper on OfflineBudget {
  Budget toDomain() {
    return Budget(
      id: id,
      userId: userId,
      name: name,
      categoryId: categoryId,
      amount: Money.parse(amount, currency),
      periodStart: periodStart,
      periodEnd: periodEnd,
      period: _enumByName(BudgetPeriod.values, period, BudgetPeriod.monthly),
      alertThresholds: alertThresholds,
      status: _enumByName(BudgetStatus.values, status, BudgetStatus.active),
      includedCategoryIds: includedCategoryIds,
      isAppDefined: isAppDefined,
    );
  }
}

extension BudgetOfflineMapper on Budget {
  OfflineBudget toOffline({required String userId}) {
    return OfflineBudget(
      id: id,
      userId: userId,
      name: name,
      categoryId: categoryId,
      amount: amount.amount.toString(),
      currency: amount.currency,
      periodStart: periodStart,
      periodEnd: periodEnd,
      period: period.name,
      alertThresholds: alertThresholds,
      status: status.name,
      includedCategoryIds: includedCategoryIds,
      isAppDefined: isAppDefined,
    );
  }
}

extension OfflineCategoryMapper on OfflineCategory {
  Category toDomain() {
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

extension OfflineGoalMapper on OfflineGoal {
  Goal toDomain() {
    return Goal(
      id: id,
      userId: userId,
      name: name,
      purpose: _enumByName(GoalPurpose.values, purpose, GoalPurpose.custom),
      targetAmount: Money.parse(targetAmount, currency),
      currentAmount: Money.parse(currentAmount, currency),
      targetDate: targetDate,
      linkedAccountId: linkedAccountId,
      priority: priority,
      successProbability: successProbability,
      status: _enumByName(GoalStatus.values, status, GoalStatus.active),
    );
  }
}

extension GoalOfflineMapper on Goal {
  OfflineGoal toOffline({required String userId}) {
    return OfflineGoal(
      id: id,
      userId: userId,
      name: name,
      purpose: purpose.name,
      targetAmount: targetAmount.amount.toString(),
      currentAmount: currentAmount.amount.toString(),
      currency: targetAmount.currency,
      targetDate: targetDate,
      linkedAccountId: linkedAccountId,
      priority: priority,
      successProbability: successProbability,
      status: status.name,
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
