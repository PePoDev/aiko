// Translated names for domain enums. Every enum value shown to the user
// gets its label here, in English and Thai (test/l10n/domain_labels_test.dart).

import '../features/accounts/domain/account_details.dart';
import '../features/accounts/domain/account_type.dart';
import '../features/categories/domain/category.dart';
import '../features/settings/domain/profile.dart';
import '../features/transactions/domain/transaction.dart';
import '../features/transactions/domain/transaction_rule.dart';
import 'app_localizations.dart';

extension AccountTypeLabel on AccountType {
  String label(AppLocalizations l10n) => switch (this) {
    AccountType.cash => l10n.accountTypeCash,
    AccountType.bank => l10n.accountTypeBank,
    AccountType.eWallet => l10n.accountTypeEWallet,
    AccountType.creditCard => l10n.accountTypeCreditCard,
    AccountType.loan => l10n.accountTypeLoan,
    AccountType.investment => l10n.accountTypeInvestment,
    AccountType.asset => l10n.accountTypeAsset,
    AccountType.liability => l10n.accountTypeLiability,
    AccountType.goal => l10n.accountTypeGoal,
    AccountType.other => l10n.accountTypeOther,
  };
}

extension GoalPriorityLabel on GoalPriority {
  String label(AppLocalizations l10n) => switch (this) {
    GoalPriority.high => l10n.goalPriorityHigh,
    GoalPriority.medium => l10n.goalPriorityMedium,
    GoalPriority.low => l10n.goalPriorityLow,
  };
}

extension RewardsTypeLabel on RewardsType {
  String label(AppLocalizations l10n) => switch (this) {
    RewardsType.cashback => l10n.rewardsTypeCashback,
    RewardsType.points => l10n.rewardsTypePoints,
    RewardsType.miles => l10n.rewardsTypeMiles,
    RewardsType.none => l10n.rewardsTypeNone,
  };
}

extension LoanTypeLabel on LoanType {
  String label(AppLocalizations l10n) => switch (this) {
    LoanType.mortgage => l10n.loanTypeMortgage,
    LoanType.auto => l10n.loanTypeAuto,
    LoanType.personal => l10n.loanTypePersonal,
    LoanType.student => l10n.loanTypeStudent,
    LoanType.other => l10n.loanTypeOther,
  };
}

extension AssetClassLabel on AssetClass {
  String label(AppLocalizations l10n) => switch (this) {
    AssetClass.cash => l10n.assetClassCash,
    AssetClass.stocks => l10n.assetClassStocks,
    AssetClass.realEstate => l10n.assetClassRealEstate,
    AssetClass.vehicle => l10n.assetClassVehicle,
    AssetClass.other => l10n.assetClassOther,
  };
}

extension CategoryTypeLabel on CategoryType {
  String label(AppLocalizations l10n) => switch (this) {
    CategoryType.income => l10n.categoryTypeIncome,
    CategoryType.expense => l10n.categoryTypeExpense,
    CategoryType.transfer => l10n.categoryTypeTransfer,
    CategoryType.finance => l10n.categoryTypeFinance,
    CategoryType.tax => l10n.categoryTypeTax,
    CategoryType.investment => l10n.categoryTypeInvestment,
    CategoryType.adjustment => l10n.categoryTypeAdjustment,
  };
}

extension CategoryBudgetGroupLabel on CategoryBudgetGroup {
  String label(AppLocalizations l10n) => switch (this) {
    CategoryBudgetGroup.needs => l10n.budgetGroupNeeds,
    CategoryBudgetGroup.wants => l10n.budgetGroupWants,
    CategoryBudgetGroup.savings => l10n.budgetGroupSavings,
    CategoryBudgetGroup.debt => l10n.budgetGroupDebt,
    CategoryBudgetGroup.investment => l10n.budgetGroupInvestment,
    CategoryBudgetGroup.tax => l10n.budgetGroupTax,
    CategoryBudgetGroup.business => l10n.budgetGroupBusiness,
    CategoryBudgetGroup.custom => l10n.budgetGroupCustom,
  };
}

extension CategoryBudgetPeriodLabel on CategoryBudgetPeriod {
  String label(AppLocalizations l10n) => switch (this) {
    CategoryBudgetPeriod.daily => l10n.budgetPeriodDaily,
    CategoryBudgetPeriod.weekly => l10n.budgetPeriodWeekly,
    CategoryBudgetPeriod.monthly => l10n.budgetPeriodMonthly,
    CategoryBudgetPeriod.yearly => l10n.budgetPeriodYearly,
  };
}

extension TransactionTypeLabel on TransactionType {
  String label(AppLocalizations l10n) => switch (this) {
    TransactionType.income => l10n.transactionTypeIncome,
    TransactionType.expense => l10n.transactionTypeExpense,
    TransactionType.transfer => l10n.transactionTypeTransfer,
    TransactionType.transferOut => l10n.transactionTypeTransferOut,
    TransactionType.transferIn => l10n.transactionTypeTransferIn,
    TransactionType.refund => l10n.transactionTypeRefund,
    TransactionType.investmentBuy => l10n.transactionTypeInvestmentBuy,
    TransactionType.investmentSell => l10n.transactionTypeInvestmentSell,
    TransactionType.dividend => l10n.transactionTypeDividend,
    TransactionType.interest => l10n.transactionTypeInterest,
    TransactionType.loanPayment => l10n.transactionTypeLoanPayment,
    TransactionType.creditCardPayment => l10n.transactionTypeCreditCardPayment,
    TransactionType.taxPayment => l10n.transactionTypeTaxPayment,
    TransactionType.fee => l10n.transactionTypeFee,
    TransactionType.adjustment => l10n.transactionTypeAdjustment,
  };
}

extension RecurringFrequencyLabel on RecurringFrequency {
  String label(AppLocalizations l10n) => switch (this) {
    RecurringFrequency.once => l10n.frequencyOnce,
    RecurringFrequency.daily => l10n.frequencyDaily,
    RecurringFrequency.weekly => l10n.frequencyWeekly,
    RecurringFrequency.monthly => l10n.frequencyMonthly,
    RecurringFrequency.annually => l10n.frequencyAnnually,
  };
}

extension RuleConditionTypeLabel on RuleConditionType {
  String label(AppLocalizations l10n) => switch (this) {
    RuleConditionType.merchant => l10n.ruleConditionMerchant,
    RuleConditionType.keyword => l10n.ruleConditionKeyword,
    RuleConditionType.amount => l10n.ruleConditionAmount,
    RuleConditionType.account => l10n.ruleConditionAccount,
    RuleConditionType.category => l10n.ruleConditionCategory,
    RuleConditionType.transactionType => l10n.ruleConditionTransactionType,
  };
}

extension RuleConditionOperatorLabel on RuleConditionOperator {
  String label(AppLocalizations l10n) => switch (this) {
    RuleConditionOperator.contains => l10n.ruleOperatorContains,
    RuleConditionOperator.equals => l10n.ruleOperatorEquals,
    RuleConditionOperator.startsWith => l10n.ruleOperatorStartsWith,
    RuleConditionOperator.endsWith => l10n.ruleOperatorEndsWith,
  };
}

extension GenderLabel on Gender {
  String label(AppLocalizations l10n) => switch (this) {
    Gender.preferNotToSay => l10n.genderPreferNotToSay,
    Gender.female => l10n.genderFemale,
    Gender.male => l10n.genderMale,
    Gender.nonBinary => l10n.genderNonBinary,
    Gender.other => l10n.genderOther,
  };
}

extension PreferredThemeLabel on PreferredTheme {
  String label(AppLocalizations l10n) => switch (this) {
    PreferredTheme.system => l10n.themeSystem,
    PreferredTheme.light => l10n.themeLight,
    PreferredTheme.dark => l10n.themeDark,
  };
}

/// The currency's name in the current language, for the supported codes
/// (`kAikoSupportedCurrencies`); other codes are shown as-is.
String currencyDisplayName(String code, AppLocalizations l10n) =>
    switch (code) {
      'THB' => l10n.currencyNameThb,
      'USD' => l10n.currencyNameUsd,
      'EUR' => l10n.currencyNameEur,
      'GBP' => l10n.currencyNameGbp,
      'JPY' => l10n.currencyNameJpy,
      'SGD' => l10n.currencyNameSgd,
      'AUD' => l10n.currencyNameAud,
      'CAD' => l10n.currencyNameCad,
      'CNY' => l10n.currencyNameCny,
      'HKD' => l10n.currencyNameHkd,
      _ => code,
    };

/// Investment asset classes are stored as English names ('Stocks', 'Bonds',
/// …); the built-in ones are shown in the current language, custom ones as
/// typed.
String investmentAssetClassLabel(String assetClass, AppLocalizations l10n) =>
    switch (assetClass) {
      'Stocks' => l10n.assetClassStocks,
      'Bonds' => l10n.assetClassBonds,
      'Funds' => l10n.assetClassFunds,
      'Crypto' => l10n.assetClassCrypto,
      'Cash' => l10n.assetClassCash,
      'Custom' => l10n.assetClassCustom,
      'Other' => l10n.assetClassOther,
      _ => assetClass,
    };
