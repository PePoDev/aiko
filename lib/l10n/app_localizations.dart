import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Aiko'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your financial companion'**
  String get appSubtitle;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get homeTab;

  /// No description provided for @transactionsTab.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsTab;

  /// No description provided for @budgetTab.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetTab;

  /// No description provided for @insightsTab.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTab;

  /// No description provided for @aikoTab.
  ///
  /// In en, this message translates to:
  /// **'Aiko'**
  String get aikoTab;

  /// No description provided for @moreTab.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTab;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @aikoHub.
  ///
  /// In en, this message translates to:
  /// **'Aiko Hub'**
  String get aikoHub;

  /// No description provided for @aikoHubDescription.
  ///
  /// In en, this message translates to:
  /// **'Every feature area is grouped here so secondary pages stay reachable without crowding the main tabs.'**
  String get aikoHubDescription;

  /// No description provided for @hiAiko.
  ///
  /// In en, this message translates to:
  /// **'Hi, I am Aiko'**
  String get hiAiko;

  /// No description provided for @safeToSpend.
  ///
  /// In en, this message translates to:
  /// **'Safe to spend'**
  String get safeToSpend;

  /// No description provided for @safeToSpendDescription.
  ///
  /// In en, this message translates to:
  /// **'You have {amount} estimated safe to spend this week. This is an estimate, so keep bills and planned purchases in view.'**
  String safeToSpendDescription(String amount);

  /// No description provided for @safeToSpendWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly cushion calculated from your posted transactions.'**
  String get safeToSpendWeekly;

  /// No description provided for @monthlyCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Monthly cash flow'**
  String get monthlyCashFlow;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @spending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get spending;

  /// No description provided for @pace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// No description provided for @paceAhead.
  ///
  /// In en, this message translates to:
  /// **'Spending is ahead of the current budget pace.'**
  String get paceAhead;

  /// No description provided for @paceOnTrack.
  ///
  /// In en, this message translates to:
  /// **'Spending is on pace for the current budget period.'**
  String get paceOnTrack;

  /// No description provided for @financialPyramid.
  ///
  /// In en, this message translates to:
  /// **'Financial Pyramid'**
  String get financialPyramid;

  /// No description provided for @currentHealth.
  ///
  /// In en, this message translates to:
  /// **'Current health: {level}'**
  String currentHealth(String level);

  /// No description provided for @pyramidFit.
  ///
  /// In en, this message translates to:
  /// **'{percent}% fit'**
  String pyramidFit(int percent);

  /// No description provided for @pyramidBuildBase.
  ///
  /// In en, this message translates to:
  /// **'Build the base first, then climb tier by tier.'**
  String get pyramidBuildBase;

  /// No description provided for @pyramidLevel1.
  ///
  /// In en, this message translates to:
  /// **'Level 1 (Base)'**
  String get pyramidLevel1;

  /// No description provided for @pyramidLevel1Desc.
  ///
  /// In en, this message translates to:
  /// **'Earn enough income for monthly obligations, purchase health insurance, and establish an emergency fund.'**
  String get pyramidLevel1Desc;

  /// No description provided for @pyramidLevel2.
  ///
  /// In en, this message translates to:
  /// **'Level 2'**
  String get pyramidLevel2;

  /// No description provided for @pyramidLevel2Desc.
  ///
  /// In en, this message translates to:
  /// **'Increase income, buy life and disability insurance, repay high-interest debt, and begin retirement savings.'**
  String get pyramidLevel2Desc;

  /// No description provided for @pyramidLevel3.
  ///
  /// In en, this message translates to:
  /// **'Level 3'**
  String get pyramidLevel3;

  /// No description provided for @pyramidLevel3Desc.
  ///
  /// In en, this message translates to:
  /// **'Buy a home, repay low-interest debt, provide for your children, and increase retirement savings.'**
  String get pyramidLevel3Desc;

  /// No description provided for @pyramidLevel4.
  ///
  /// In en, this message translates to:
  /// **'Level 4'**
  String get pyramidLevel4;

  /// No description provided for @pyramidLevel4Desc.
  ///
  /// In en, this message translates to:
  /// **'Provide for aging parents, save for children\'s college, pay off your mortgage before retirement, maximize retirement savings, and consider long-term care insurance.'**
  String get pyramidLevel4Desc;

  /// No description provided for @pyramidLevel5.
  ///
  /// In en, this message translates to:
  /// **'Level 5 (Peak)'**
  String get pyramidLevel5;

  /// No description provided for @pyramidLevel5Desc.
  ///
  /// In en, this message translates to:
  /// **'Retire and build a retirement income strategy, fulfill your dreams, donate money, and plan your legacy.'**
  String get pyramidLevel5Desc;

  /// No description provided for @upcomingDueDates.
  ///
  /// In en, this message translates to:
  /// **'Upcoming due dates'**
  String get upcomingDueDates;

  /// No description provided for @loadingBills.
  ///
  /// In en, this message translates to:
  /// **'Loading bills and card payments...'**
  String get loadingBills;

  /// No description provided for @unableToLoadDueDates.
  ///
  /// In en, this message translates to:
  /// **'Unable to load due dates right now.'**
  String get unableToLoadDueDates;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAdd;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get addTransaction;

  /// No description provided for @addBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get addBudget;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Profile and privacy'**
  String get profileAndPrivacy;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInformation;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @baseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get baseCurrency;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @preferredTheme.
  ///
  /// In en, this message translates to:
  /// **'Preferred theme'**
  String get preferredTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @aiConsent.
  ///
  /// In en, this message translates to:
  /// **'AI consent'**
  String get aiConsent;

  /// No description provided for @aiConsentDescription.
  ///
  /// In en, this message translates to:
  /// **'Allow Aiko to analyze sensitive financial data for insights'**
  String get aiConsentDescription;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @securityAndPinLock.
  ///
  /// In en, this message translates to:
  /// **'Security & PIN Lock'**
  String get securityAndPinLock;

  /// No description provided for @pinLockDescription.
  ///
  /// In en, this message translates to:
  /// **'Protect your private financial data by configuring a secure 4-digit PIN lock.'**
  String get pinLockDescription;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-Digit PIN'**
  String get enterPin;

  /// No description provided for @pinConfigured.
  ///
  /// In en, this message translates to:
  /// **'PIN configured successfully!'**
  String get pinConfigured;

  /// No description provided for @pinMustBe4Digits.
  ///
  /// In en, this message translates to:
  /// **'PIN must be exactly 4 digits.'**
  String get pinMustBe4Digits;

  /// No description provided for @pinEnabled.
  ///
  /// In en, this message translates to:
  /// **'PIN Lock Enabled'**
  String get pinEnabled;

  /// No description provided for @removePinLock.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN Lock'**
  String get removePinLock;

  /// No description provided for @disablePinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove your PIN lock? This will reduce the security of your financial data.'**
  String get disablePinConfirm;

  /// No description provided for @pinRemoved.
  ///
  /// In en, this message translates to:
  /// **'PIN lock removed.'**
  String get pinRemoved;

  /// No description provided for @biometricsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication enabled'**
  String get biometricsEnabled;

  /// No description provided for @enableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometrics'**
  String get enableBiometrics;

  /// No description provided for @disableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Disable Biometrics'**
  String get disableBiometrics;

  /// No description provided for @biometricsConfigured.
  ///
  /// In en, this message translates to:
  /// **'Biometrics enabled!'**
  String get biometricsConfigured;

  /// No description provided for @biometricsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Biometrics disabled.'**
  String get biometricsRemoved;

  /// No description provided for @accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get accountManagement;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get signingOut;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out successfully.'**
  String get signedOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get deletingAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account? This action cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted!'**
  String get accountDeleted;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated!'**
  String get profileUpdated;

  /// No description provided for @failedToSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile: {error}'**
  String failedToSaveProfile(String error);

  /// No description provided for @couldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile'**
  String get couldNotLoadProfile;

  /// No description provided for @welcomeToAiko.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aiko'**
  String get welcomeToAiko;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @signInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get signInWithEmail;

  /// No description provided for @signUpWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign up with email'**
  String get signUpWithEmail;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent you a password reset link.'**
  String get resetLinkSent;

  /// No description provided for @welcomeToAikoOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Aiko'**
  String get welcomeToAikoOnboarding;

  /// No description provided for @meetAiko.
  ///
  /// In en, this message translates to:
  /// **'Meet Aiko'**
  String get meetAiko;

  /// No description provided for @aikoPersonalityTone.
  ///
  /// In en, this message translates to:
  /// **'Aiko\'s Personality Tone'**
  String get aikoPersonalityTone;

  /// No description provided for @personalitySupportive.
  ///
  /// In en, this message translates to:
  /// **'Supportive'**
  String get personalitySupportive;

  /// No description provided for @personalitySupportiveDesc.
  ///
  /// In en, this message translates to:
  /// **'A warm, encouraging, non-judgmental finance bestie.'**
  String get personalitySupportiveDesc;

  /// No description provided for @personalityProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get personalityProfessional;

  /// No description provided for @personalityProfessionalDesc.
  ///
  /// In en, this message translates to:
  /// **'Analytical, serious, data-driven financial advisor.'**
  String get personalityProfessionalDesc;

  /// No description provided for @personalityPlayful.
  ///
  /// In en, this message translates to:
  /// **'Playful'**
  String get personalityPlayful;

  /// No description provided for @personalityPlayfulDesc.
  ///
  /// In en, this message translates to:
  /// **'Energetic, fun, celebrates small wins with high-fives.'**
  String get personalityPlayfulDesc;

  /// No description provided for @mainFinancialGoal.
  ///
  /// In en, this message translates to:
  /// **'What is your main financial goal?'**
  String get mainFinancialGoal;

  /// No description provided for @goalSaveMoney.
  ///
  /// In en, this message translates to:
  /// **'Save money'**
  String get goalSaveMoney;

  /// No description provided for @goalSaveMoneyDesc.
  ///
  /// In en, this message translates to:
  /// **'Build a strong emergency savings cushion.'**
  String get goalSaveMoneyDesc;

  /// No description provided for @goalTrackSpending.
  ///
  /// In en, this message translates to:
  /// **'Track spending'**
  String get goalTrackSpending;

  /// No description provided for @goalTrackSpendingDesc.
  ///
  /// In en, this message translates to:
  /// **'Log expenses to see where every dollar goes.'**
  String get goalTrackSpendingDesc;

  /// No description provided for @goalPayOffDebt.
  ///
  /// In en, this message translates to:
  /// **'Pay off debt'**
  String get goalPayOffDebt;

  /// No description provided for @goalPayOffDebtDesc.
  ///
  /// In en, this message translates to:
  /// **'Create payoffs plans to become debt-free.'**
  String get goalPayOffDebtDesc;

  /// No description provided for @goalBuildWealth.
  ///
  /// In en, this message translates to:
  /// **'Build wealth'**
  String get goalBuildWealth;

  /// No description provided for @goalBuildWealthDesc.
  ///
  /// In en, this message translates to:
  /// **'Invest smartly and plan for long-term growth.'**
  String get goalBuildWealthDesc;

  /// No description provided for @currencyAndCountrySettings.
  ///
  /// In en, this message translates to:
  /// **'Currency & Country Settings'**
  String get currencyAndCountrySettings;

  /// No description provided for @addFirstAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Financial Account'**
  String get addFirstAccount;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountName;

  /// No description provided for @accountNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Pocket Wallet, Checking Account'**
  String get accountNameHint;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountType;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash Wallet'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank Account'**
  String get accountTypeBank;

  /// No description provided for @accountTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get accountTypeCreditCard;

  /// No description provided for @accountTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountTypeInvestment;

  /// No description provided for @openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance'**
  String get openingBalance;

  /// No description provided for @accountNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter account name'**
  String get accountNameRequired;

  /// No description provided for @balanceRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter starting balance'**
  String get balanceRequired;

  /// No description provided for @balanceMustBeValid.
  ///
  /// In en, this message translates to:
  /// **'Must be a valid positive number'**
  String get balanceMustBeValid;

  /// No description provided for @configureSecurity.
  ///
  /// In en, this message translates to:
  /// **'Configure Security Shield'**
  String get configureSecurity;

  /// No description provided for @securePinCode.
  ///
  /// In en, this message translates to:
  /// **'Secure PIN Code'**
  String get securePinCode;

  /// No description provided for @biometricsOnly.
  ///
  /// In en, this message translates to:
  /// **'Biometrics Only'**
  String get biometricsOnly;

  /// No description provided for @enter4DigitPin.
  ///
  /// In en, this message translates to:
  /// **'Enter a 4-Digit Passcode PIN'**
  String get enter4DigitPin;

  /// No description provided for @useDeviceBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use Your Native Device Biometrics'**
  String get useDeviceBiometrics;

  /// No description provided for @biometricsDescription.
  ///
  /// In en, this message translates to:
  /// **'Taps into Face ID / Touch ID / Android fingerprint scanning securely to instantly unlock Aiko.'**
  String get biometricsDescription;

  /// No description provided for @finishAndSignIn.
  ///
  /// In en, this message translates to:
  /// **'Finish & Sign In'**
  String get finishAndSignIn;

  /// No description provided for @enterFullPin.
  ///
  /// In en, this message translates to:
  /// **'Please enter a full 4-digit PIN passcode.'**
  String get enterFullPin;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @addNewTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add new transaction'**
  String get addNewTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransaction;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get transactionDetails;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @typeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get typeIncome;

  /// No description provided for @typeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get typeExpense;

  /// No description provided for @typeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get typeTransfer;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @recurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Recurring transaction'**
  String get recurringTransaction;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @addReceipt.
  ///
  /// In en, this message translates to:
  /// **'Add receipt'**
  String get addReceipt;

  /// No description provided for @scanReceipt.
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get scanReceipt;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved!'**
  String get transactionSaved;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted!'**
  String get transactionDeleted;

  /// No description provided for @deleteTransactionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this transaction?'**
  String get deleteTransactionConfirm;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @addBudgetItem.
  ///
  /// In en, this message translates to:
  /// **'Add budget'**
  String get addBudgetItem;

  /// No description provided for @editBudgetItem.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudgetItem;

  /// No description provided for @budgetName.
  ///
  /// In en, this message translates to:
  /// **'Budget name'**
  String get budgetName;

  /// No description provided for @budgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget amount'**
  String get budgetAmount;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @periodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// No description provided for @periodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// No description provided for @periodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get periodYearly;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @budgetProgress.
  ///
  /// In en, this message translates to:
  /// **'Budget progress'**
  String get budgetProgress;

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get overBudget;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get onTrack;

  /// No description provided for @budgetSaved.
  ///
  /// In en, this message translates to:
  /// **'Budget saved!'**
  String get budgetSaved;

  /// No description provided for @budgetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Budget deleted!'**
  String get budgetDeleted;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @savingGoals.
  ///
  /// In en, this message translates to:
  /// **'Saving goals'**
  String get savingGoals;

  /// No description provided for @addGoal.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get addGoal;

  /// No description provided for @editGoal.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get editGoal;

  /// No description provided for @goalName.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get goalName;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get targetAmount;

  /// No description provided for @currentAmount.
  ///
  /// In en, this message translates to:
  /// **'Current amount'**
  String get currentAmount;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get targetDate;

  /// No description provided for @goalProgress.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get goalProgress;

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days} days remaining'**
  String daysRemaining(int days);

  /// No description provided for @goalAchieved.
  ///
  /// In en, this message translates to:
  /// **'Goal achieved!'**
  String get goalAchieved;

  /// No description provided for @goalSaved.
  ///
  /// In en, this message translates to:
  /// **'Goal saved!'**
  String get goalSaved;

  /// No description provided for @goalDeleted.
  ///
  /// In en, this message translates to:
  /// **'Goal deleted!'**
  String get goalDeleted;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @addAccountItem.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccountItem;

  /// No description provided for @editAccountItem.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccountItem;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Account balance'**
  String get accountBalance;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get totalBalance;

  /// No description provided for @activeAccounts.
  ///
  /// In en, this message translates to:
  /// **'Active accounts'**
  String get activeAccounts;

  /// No description provided for @accountSaved.
  ///
  /// In en, this message translates to:
  /// **'Account saved!'**
  String get accountSaved;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @spendingAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Spending analysis'**
  String get spendingAnalysis;

  /// No description provided for @incomeAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Income analysis'**
  String get incomeAnalysis;

  /// No description provided for @trends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trends;

  /// No description provided for @categoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category breakdown'**
  String get categoryBreakdown;

  /// No description provided for @topCategories.
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get topCategories;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get lastMonth;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTitle;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportData;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export format'**
  String get exportFormat;

  /// No description provided for @exportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Export period'**
  String get exportPeriod;

  /// No description provided for @exportAllData.
  ///
  /// In en, this message translates to:
  /// **'Export all data'**
  String get exportAllData;

  /// No description provided for @exportCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get exportCustomRange;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @exportComplete.
  ///
  /// In en, this message translates to:
  /// **'Export complete!'**
  String get exportComplete;

  /// No description provided for @learningHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Hub'**
  String get learningHubTitle;

  /// No description provided for @articles.
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get articles;

  /// No description provided for @tutorials.
  ///
  /// In en, this message translates to:
  /// **'Tutorials'**
  String get tutorials;

  /// No description provided for @guides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get guides;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile and privacy'**
  String get privacyTitle;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Aiko provides estimates, not certified financial advice.'**
  String get aiDisclaimer;

  /// No description provided for @noDueDates.
  ///
  /// In en, this message translates to:
  /// **'No upcoming due dates'**
  String get noDueDates;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// No description provided for @noBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get noBudgets;

  /// No description provided for @noGoals.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get noGoals;

  /// No description provided for @noAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccounts;

  /// No description provided for @dashboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Dashboard is unavailable'**
  String get dashboardUnavailable;

  /// No description provided for @dashboardUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Aiko could not load your Supabase workspace.'**
  String get dashboardUnavailableMessage;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
