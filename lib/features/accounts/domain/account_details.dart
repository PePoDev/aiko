import '../../../core/money/money.dart';
import 'account_type.dart';

enum RewardsType { cashback, points, miles, none }

enum LoanType { mortgage, auto, personal, student, other }

enum AssetClass { cash, stocks, realEstate, vehicle, other }

sealed class AccountDetails {
  const AccountDetails();

  /// Returns the empty default for [type]. Always non-null. A loan's next due
  /// date defaults to a month from [now] (today when omitted).
  static AccountDetails defaultFor(AccountType type, {DateTime? now}) {
    return switch (type) {
      AccountType.cash => const CashDetails(),
      AccountType.bank => const BankDetails(),
      AccountType.eWallet => const EWalletDetails(),
      AccountType.creditCard => CreditCardDetails(statementDay: 1, dueDay: 1),
      AccountType.loan => LoanDetails(
        loanType: LoanType.other,
        principal: Money.zero('USD'),
        interestRatePercent: 0,
        termMonths: 1,
        monthlyPayment: Money.zero('USD'),
        nextDueDate: oneMonthAfter(now ?? DateTime.now()),
      ),
      AccountType.investment => const InvestmentDetails(),
      AccountType.asset => const AssetDetails(assetClass: AssetClass.other),
      AccountType.liability => const LiabilityDetails(),
      AccountType.goal => const OtherDetails(),
      AccountType.other => const OtherDetails(),
    };
  }

  /// String discriminator used in JSON and stored records.
  String get variantName;

  /// The same day next month (date only), clamped to that month's last day:
  /// Jan 31 → Feb 28/29.
  static DateTime oneMonthAfter(DateTime date) {
    final lastDay = DateTime(date.year, date.month + 2, 0).day;
    return DateTime(
      date.year,
      date.month + 1,
      date.day > lastDay ? lastDay : date.day,
    );
  }
}

class CashDetails extends AccountDetails {
  const CashDetails();
  @override
  String get variantName => 'cash';
}

class BankDetails extends AccountDetails {
  const BankDetails();
  @override
  String get variantName => 'bank';
}

class EWalletDetails extends AccountDetails {
  const EWalletDetails();
  @override
  String get variantName => 'eWallet';
}

class CreditCardDetails extends AccountDetails {
  const CreditCardDetails({
    this.creditLimit,
    required this.statementDay,
    required this.dueDay,
    this.aprPercent,
    this.rewardsType,
    this.annualFee,
    this.minimumPayment,
    this.sharesLimit = false,
    this.sharedLimitAccountId,
  });

  final Money? creditLimit;
  final int statementDay;
  final int dueDay;
  final double? aprPercent;
  final RewardsType? rewardsType;
  final Money? annualFee;
  final Money? minimumPayment;
  final bool sharesLimit;
  final String? sharedLimitAccountId;
  @override
  String get variantName => 'creditCard';

  CreditCardDetails copyWith({
    Money? creditLimit,
    int? statementDay,
    int? dueDay,
    double? aprPercent,
    RewardsType? rewardsType,
    Money? annualFee,
    Money? minimumPayment,
    bool? sharesLimit,
    String? sharedLimitAccountId,
    bool clearSharedLimitAccountId = false,
  }) => CreditCardDetails(
    creditLimit: creditLimit ?? this.creditLimit,
    statementDay: statementDay ?? this.statementDay,
    dueDay: dueDay ?? this.dueDay,
    aprPercent: aprPercent ?? this.aprPercent,
    rewardsType: rewardsType ?? this.rewardsType,
    annualFee: annualFee ?? this.annualFee,
    minimumPayment: minimumPayment ?? this.minimumPayment,
    sharesLimit: sharesLimit ?? this.sharesLimit,
    sharedLimitAccountId: clearSharedLimitAccountId
        ? null
        : (sharedLimitAccountId ?? this.sharedLimitAccountId),
  );

  @override
  bool operator ==(Object other) =>
      other is CreditCardDetails &&
      other.creditLimit == creditLimit &&
      other.statementDay == statementDay &&
      other.dueDay == dueDay &&
      other.aprPercent == aprPercent &&
      other.rewardsType == rewardsType &&
      other.annualFee == annualFee &&
      other.minimumPayment == minimumPayment &&
      other.sharesLimit == sharesLimit &&
      other.sharedLimitAccountId == sharedLimitAccountId;

  @override
  int get hashCode => Object.hash(
    creditLimit,
    statementDay,
    dueDay,
    aprPercent,
    rewardsType,
    annualFee,
    minimumPayment,
    sharesLimit,
    sharedLimitAccountId,
  );
}

class LoanDetails extends AccountDetails {
  const LoanDetails({
    required this.loanType,
    required this.principal,
    required this.interestRatePercent,
    required this.termMonths,
    required this.monthlyPayment,
    required this.nextDueDate,
  });

  final LoanType loanType;
  final Money principal;
  final double interestRatePercent;
  final int termMonths;
  final Money monthlyPayment;
  final DateTime nextDueDate;
  @override
  String get variantName => 'loan';

  @override
  bool operator ==(Object other) =>
      other is LoanDetails &&
      other.loanType == loanType &&
      other.principal == principal &&
      other.interestRatePercent == interestRatePercent &&
      other.termMonths == termMonths &&
      other.monthlyPayment == monthlyPayment &&
      other.nextDueDate == nextDueDate;

  @override
  int get hashCode => Object.hash(
    loanType,
    principal,
    interestRatePercent,
    termMonths,
    monthlyPayment,
    nextDueDate,
  );
}

class InvestmentDetails extends AccountDetails {
  const InvestmentDetails({this.accountNumberLast4});
  final String? accountNumberLast4;
  @override
  String get variantName => 'investment';

  @override
  bool operator ==(Object other) =>
      other is InvestmentDetails &&
      other.accountNumberLast4 == accountNumberLast4;

  @override
  int get hashCode => accountNumberLast4.hashCode;
}

class AssetDetails extends AccountDetails {
  const AssetDetails({
    required this.assetClass,
    this.purchasePrice,
    this.purchaseDate,
    this.notes,
  });
  final AssetClass assetClass;
  final Money? purchasePrice;
  final DateTime? purchaseDate;
  final String? notes;
  @override
  String get variantName => 'asset';

  @override
  bool operator ==(Object other) =>
      other is AssetDetails &&
      other.assetClass == assetClass &&
      other.purchasePrice == purchasePrice &&
      other.purchaseDate == purchaseDate &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(assetClass, purchasePrice, purchaseDate, notes);
}

class LiabilityDetails extends AccountDetails {
  const LiabilityDetails({
    this.liabilityType,
    this.interestRatePercent,
    this.notes,
  });
  final String? liabilityType;
  final double? interestRatePercent;
  final String? notes;
  @override
  String get variantName => 'liability';

  @override
  bool operator ==(Object other) =>
      other is LiabilityDetails &&
      other.liabilityType == liabilityType &&
      other.interestRatePercent == interestRatePercent &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(liabilityType, interestRatePercent, notes);
}

class OtherDetails extends AccountDetails {
  const OtherDetails({this.notes});
  final String? notes;
  @override
  String get variantName => 'other';

  @override
  bool operator ==(Object other) =>
      other is OtherDetails && other.notes == notes;

  @override
  int get hashCode => notes.hashCode;
}
