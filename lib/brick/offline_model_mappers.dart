import '../core/money/money.dart';
import '../features/accounts/domain/account.dart';
import '../features/budgets/domain/budget.dart';
import '../features/categories/domain/category.dart';
import '../features/goals/domain/goal.dart';
import '../features/settings/domain/profile.dart';
import '../features/transactions/domain/transaction.dart';
import 'models/account.model.dart';
import 'models/budget.model.dart';
import 'models/category.model.dart';
import 'models/goal.model.dart';
import 'models/profile.model.dart';
import 'models/transaction.model.dart';

extension OfflineAccountMapper on OfflineAccount {
  Account toDomain() {
    return Account(
      id: id,
      userId: userId,
      name: name,
      type: _enumByName(AccountType.values, type, AccountType.cash),
      openingBalance: Money.parse(openingBalance, currency),
      currentBalance: Money.parse(currentBalance, currency),
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive,
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
      openingBalance: openingBalance.amount.toString(),
      currentBalance: currentBalance.amount.toString(),
      institution: institution,
      includeInNetWorth: includeInNetWorth,
      isActive: isActive,
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
        CategoryGroup.values,
        categoryGroup,
        CategoryGroup.custom,
      ),
      parentId: parentId,
      icon: icon,
      color: color,
      budgetEnabled: budgetEnabled,
      isActive: isActive,
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
      parentId: parentId,
      icon: icon,
      color: color,
      budgetEnabled: budgetEnabled,
      isActive: isActive,
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
      aiConsentEnabled: aiConsentEnabled,
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
      aiConsentEnabled: aiConsentEnabled,
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
