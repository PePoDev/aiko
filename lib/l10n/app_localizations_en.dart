// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aiko';

  @override
  String get appSubtitle => 'Your financial companion';

  @override
  String get homeTab => 'Overview';

  @override
  String get transactionsTab => 'Transactions';

  @override
  String get budgetTab => 'Budget';

  @override
  String get insightsTab => 'Insights';

  @override
  String get aikoTab => 'Aiko';

  @override
  String get moreTab => 'More';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get close => 'Close';

  @override
  String get continueButton => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get loading => 'Loading';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get overview => 'Overview';

  @override
  String get aikoHub => 'Aiko Hub';

  @override
  String get aikoHubDescription =>
      'Every feature area is grouped here so secondary pages stay reachable without crowding the main tabs.';

  @override
  String get hiAiko => 'Hi, I am Aiko';

  @override
  String get safeToSpend => 'Safe to spend';

  @override
  String safeToSpendDescription(String amount) {
    return 'You have $amount estimated safe to spend this week. This is an estimate, so keep bills and planned purchases in view.';
  }

  @override
  String get safeToSpendWeekly =>
      'Weekly cushion calculated from your posted transactions.';

  @override
  String get monthlyCashFlow => 'Monthly cash flow';

  @override
  String get income => 'Income';

  @override
  String get spending => 'Spending';

  @override
  String get pace => 'Pace';

  @override
  String get paceAhead => 'Spending is ahead of the current budget pace.';

  @override
  String get paceOnTrack =>
      'Spending is on pace for the current budget period.';

  @override
  String get financialPyramid => 'Financial Pyramid';

  @override
  String currentHealth(String level) {
    return 'Current health: $level';
  }

  @override
  String pyramidFit(int percent) {
    return '$percent% fit';
  }

  @override
  String get pyramidBuildBase =>
      'Build the base first, then climb tier by tier.';

  @override
  String get pyramidLevel1 => 'Level 1 (Base)';

  @override
  String get pyramidLevel1Desc =>
      'Earn enough income for monthly obligations, purchase health insurance, and establish an emergency fund.';

  @override
  String get pyramidLevel2 => 'Level 2';

  @override
  String get pyramidLevel2Desc =>
      'Increase income, buy life and disability insurance, repay high-interest debt, and begin retirement savings.';

  @override
  String get pyramidLevel3 => 'Level 3';

  @override
  String get pyramidLevel3Desc =>
      'Buy a home, repay low-interest debt, provide for your children, and increase retirement savings.';

  @override
  String get pyramidLevel4 => 'Level 4';

  @override
  String get pyramidLevel4Desc =>
      'Provide for aging parents, save for children\'s college, pay off your mortgage before retirement, maximize retirement savings, and consider long-term care insurance.';

  @override
  String get pyramidLevel5 => 'Level 5 (Peak)';

  @override
  String get pyramidLevel5Desc =>
      'Retire and build a retirement income strategy, fulfill your dreams, donate money, and plan your legacy.';

  @override
  String get upcomingDueDates => 'Upcoming due dates';

  @override
  String get loadingBills => 'Loading bills and card payments...';

  @override
  String get unableToLoadDueDates => 'Unable to load due dates right now.';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get addTransaction => 'Transaction';

  @override
  String get addBudget => 'Budget';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get profile => 'Profile';

  @override
  String get profileAndPrivacy => 'Profile and privacy';

  @override
  String get personalInformation => 'Personal information';

  @override
  String get displayName => 'Display name';

  @override
  String get email => 'Email';

  @override
  String get baseCurrency => 'Base currency';

  @override
  String get country => 'Country';

  @override
  String get preferredTheme => 'Preferred theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get aiConsent => 'AI consent';

  @override
  String get aiConsentDescription =>
      'Allow Aiko to analyze sensitive financial data for insights';

  @override
  String get security => 'Security';

  @override
  String get securityAndPinLock => 'Security & PIN Lock';

  @override
  String get pinLockDescription =>
      'Protect your private financial data by configuring a secure 4-digit PIN lock.';

  @override
  String get enterPin => 'Enter 4-Digit PIN';

  @override
  String get pinConfigured => 'PIN configured successfully!';

  @override
  String get pinMustBe4Digits => 'PIN must be exactly 4 digits.';

  @override
  String get pinEnabled => 'PIN Lock Enabled';

  @override
  String get removePinLock => 'Remove PIN Lock';

  @override
  String get disablePinConfirm =>
      'Are you sure you want to remove your PIN lock? This will reduce the security of your financial data.';

  @override
  String get pinRemoved => 'PIN lock removed.';

  @override
  String get biometricsEnabled => 'Biometric authentication enabled';

  @override
  String get enableBiometrics => 'Enable Biometrics';

  @override
  String get disableBiometrics => 'Disable Biometrics';

  @override
  String get biometricsConfigured => 'Biometrics enabled!';

  @override
  String get biometricsRemoved => 'Biometrics disabled.';

  @override
  String get accountManagement => 'Account management';

  @override
  String get signOut => 'Sign out';

  @override
  String get signingOut => 'Signing out...';

  @override
  String get signedOut => 'Signed out successfully.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deletingAccount => 'Deleting account...';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to permanently delete your account? This action cannot be undone.';

  @override
  String get accountDeleted => 'Account deleted!';

  @override
  String get profileUpdated => 'Profile updated!';

  @override
  String failedToSaveProfile(String error) {
    return 'Failed to save profile: $error';
  }

  @override
  String get couldNotLoadProfile => 'Could not load your profile';

  @override
  String get welcomeToAiko => 'Welcome to Aiko';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get signInWithEmail => 'Sign in with email';

  @override
  String get signUpWithEmail => 'Sign up with email';

  @override
  String get emailAddress => 'Email address';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get createAccount => 'Create account';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get resetLinkSent => 'We\'ve sent you a password reset link.';

  @override
  String get welcomeToAikoOnboarding => 'Welcome to Aiko';

  @override
  String get meetAiko => 'Meet Aiko';

  @override
  String get aikoPersonalityTone => 'Aiko\'s Personality Tone';

  @override
  String get personalitySupportive => 'Supportive';

  @override
  String get personalitySupportiveDesc =>
      'A warm, encouraging, non-judgmental finance bestie.';

  @override
  String get personalityProfessional => 'Professional';

  @override
  String get personalityProfessionalDesc =>
      'Analytical, serious, data-driven financial advisor.';

  @override
  String get personalityPlayful => 'Playful';

  @override
  String get personalityPlayfulDesc =>
      'Energetic, fun, celebrates small wins with high-fives.';

  @override
  String get mainFinancialGoal => 'What is your main financial goal?';

  @override
  String get goalSaveMoney => 'Save money';

  @override
  String get goalSaveMoneyDesc => 'Build a strong emergency savings cushion.';

  @override
  String get goalTrackSpending => 'Track spending';

  @override
  String get goalTrackSpendingDesc =>
      'Log expenses to see where every dollar goes.';

  @override
  String get goalPayOffDebt => 'Pay off debt';

  @override
  String get goalPayOffDebtDesc => 'Create payoffs plans to become debt-free.';

  @override
  String get goalBuildWealth => 'Build wealth';

  @override
  String get goalBuildWealthDesc =>
      'Invest smartly and plan for long-term growth.';

  @override
  String get currencyAndCountrySettings => 'Currency & Country Settings';

  @override
  String get addFirstAccount => 'Add Your First Financial Account';

  @override
  String get accountName => 'Account Name';

  @override
  String get accountNameHint => 'e.g., Pocket Wallet, Checking Account';

  @override
  String get accountType => 'Account Type';

  @override
  String get accountTypeCash => 'Cash Wallet';

  @override
  String get accountTypeBank => 'Bank Account';

  @override
  String get accountTypeCreditCard => 'Credit Card';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get openingBalance => 'Opening Balance';

  @override
  String get accountNameRequired => 'Please enter account name';

  @override
  String get balanceRequired => 'Please enter starting balance';

  @override
  String get balanceMustBeValid => 'Must be a valid positive number';

  @override
  String get configureSecurity => 'Configure Security Shield';

  @override
  String get securePinCode => 'Secure PIN Code';

  @override
  String get biometricsOnly => 'Biometrics Only';

  @override
  String get enter4DigitPin => 'Enter a 4-Digit Passcode PIN';

  @override
  String get useDeviceBiometrics => 'Use Your Native Device Biometrics';

  @override
  String get biometricsDescription =>
      'Taps into Face ID / Touch ID / Android fingerprint scanning securely to instantly unlock Aiko.';

  @override
  String get finishAndSignIn => 'Finish & Sign In';

  @override
  String get enterFullPin => 'Please enter a full 4-digit PIN passcode.';

  @override
  String get transactions => 'Transactions';

  @override
  String get addNewTransaction => 'Add new transaction';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get transactionDetails => 'Transaction details';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get category => 'Category';

  @override
  String get account => 'Account';

  @override
  String get description => 'Description';

  @override
  String get notes => 'Notes';

  @override
  String get type => 'Type';

  @override
  String get typeIncome => 'Income';

  @override
  String get typeExpense => 'Expense';

  @override
  String get typeTransfer => 'Transfer';

  @override
  String get recurring => 'Recurring';

  @override
  String get recurringTransaction => 'Recurring transaction';

  @override
  String get tags => 'Tags';

  @override
  String get attachments => 'Attachments';

  @override
  String get receipt => 'Receipt';

  @override
  String get addReceipt => 'Add receipt';

  @override
  String get scanReceipt => 'Scan receipt';

  @override
  String get transactionSaved => 'Transaction saved!';

  @override
  String get transactionDeleted => 'Transaction deleted!';

  @override
  String get deleteTransactionConfirm =>
      'Are you sure you want to delete this transaction?';

  @override
  String get budgets => 'Budgets';

  @override
  String get addBudgetItem => 'Add budget';

  @override
  String get editBudgetItem => 'Edit budget';

  @override
  String get budgetName => 'Budget name';

  @override
  String get budgetAmount => 'Budget amount';

  @override
  String get period => 'Period';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get periodYearly => 'Yearly';

  @override
  String get spent => 'Spent';

  @override
  String get remaining => 'Remaining';

  @override
  String get budgetProgress => 'Budget progress';

  @override
  String get overBudget => 'Over budget';

  @override
  String get onTrack => 'On track';

  @override
  String get budgetSaved => 'Budget saved!';

  @override
  String get budgetDeleted => 'Budget deleted!';

  @override
  String get goals => 'Goals';

  @override
  String get savingGoals => 'Saving goals';

  @override
  String get addGoal => 'Add goal';

  @override
  String get editGoal => 'Edit goal';

  @override
  String get goalName => 'Goal name';

  @override
  String get targetAmount => 'Target amount';

  @override
  String get currentAmount => 'Current amount';

  @override
  String get targetDate => 'Target date';

  @override
  String get goalProgress => 'Goal progress';

  @override
  String daysRemaining(int days) {
    return '$days days remaining';
  }

  @override
  String get goalAchieved => 'Goal achieved!';

  @override
  String get goalSaved => 'Goal saved!';

  @override
  String get goalDeleted => 'Goal deleted!';

  @override
  String get accounts => 'Accounts';

  @override
  String get addAccountItem => 'Add account';

  @override
  String get editAccountItem => 'Edit account';

  @override
  String get accountBalance => 'Account balance';

  @override
  String get totalBalance => 'Total balance';

  @override
  String get activeAccounts => 'Active accounts';

  @override
  String get accountSaved => 'Account saved!';

  @override
  String get insights => 'Insights';

  @override
  String get spendingAnalysis => 'Spending analysis';

  @override
  String get incomeAnalysis => 'Income analysis';

  @override
  String get trends => 'Trends';

  @override
  String get categoryBreakdown => 'Category breakdown';

  @override
  String get topCategories => 'Top categories';

  @override
  String get thisMonth => 'This month';

  @override
  String get lastMonth => 'Last month';

  @override
  String get thisYear => 'This year';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportData => 'Export data';

  @override
  String get exportFormat => 'Export format';

  @override
  String get exportPeriod => 'Export period';

  @override
  String get exportAllData => 'Export all data';

  @override
  String get exportCustomRange => 'Custom range';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get exportComplete => 'Export complete!';

  @override
  String get learningHubTitle => 'Learning Hub';

  @override
  String get articles => 'Articles';

  @override
  String get tutorials => 'Tutorials';

  @override
  String get guides => 'Guides';

  @override
  String get privacyTitle => 'Profile and privacy';

  @override
  String get aiDisclaimer =>
      'Aiko provides estimates, not certified financial advice.';

  @override
  String get noDueDates => 'No upcoming due dates';

  @override
  String get noTransactions => 'No transactions yet';

  @override
  String get noBudgets => 'No budgets yet';

  @override
  String get noGoals => 'No goals yet';

  @override
  String get noAccounts => 'No accounts yet';

  @override
  String get dashboardUnavailable => 'Dashboard is unavailable';

  @override
  String get dashboardUnavailableMessage =>
      'Aiko could not load your Supabase workspace.';

  @override
  String get total => 'Total';

  @override
  String get average => 'Average';

  @override
  String get currency => 'Currency';

  @override
  String get timezone => 'Timezone';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get help => 'Help';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';
}
