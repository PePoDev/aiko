import '../../../core/money/money.dart';
import 'account_type.dart';

enum RewardsType { cashback, points, miles, none }

enum LoanType { mortgage, auto, personal, student, other }

enum AssetClass { cash, stocks, realEstate, vehicle, other }

sealed class AccountDetails {
  const AccountDetails();

  /// Returns the empty default for [type]. Always non-null.
  static AccountDetails defaultFor(AccountType type) {
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
        nextDueDate: DateTime.utc(1970, 1, 1),
      ),
      AccountType.investment => const InvestmentDetails(),
      AccountType.asset => const AssetDetails(assetClass: AssetClass.other),
      AccountType.liability => const LiabilityDetails(),
      AccountType.goal => const OtherDetails(),
      AccountType.other => const OtherDetails(),
    };
  }

  /// String discriminator used in JSON / Brick storage.
  String get variantName;
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

  LoanDetails copyWith({
    LoanType? loanType,
    Money? principal,
    double? interestRatePercent,
    int? termMonths,
    Money? monthlyPayment,
    DateTime? nextDueDate,
  }) => LoanDetails(
    loanType: loanType ?? this.loanType,
    principal: principal ?? this.principal,
    interestRatePercent: interestRatePercent ?? this.interestRatePercent,
    termMonths: termMonths ?? this.termMonths,
    monthlyPayment: monthlyPayment ?? this.monthlyPayment,
    nextDueDate: nextDueDate ?? this.nextDueDate,
  );

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

  InvestmentDetails copyWith({String? accountNumberLast4}) => InvestmentDetails(
    accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
  );

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

  AssetDetails copyWith({
    AssetClass? assetClass,
    Money? purchasePrice,
    DateTime? purchaseDate,
    String? notes,
  }) => AssetDetails(
    assetClass: assetClass ?? this.assetClass,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    notes: notes ?? this.notes,
  );

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

  LiabilityDetails copyWith({
    String? liabilityType,
    double? interestRatePercent,
    String? notes,
  }) => LiabilityDetails(
    liabilityType: liabilityType ?? this.liabilityType,
    interestRatePercent: interestRatePercent ?? this.interestRatePercent,
    notes: notes ?? this.notes,
  );

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

  OtherDetails copyWith({String? notes}) =>
      OtherDetails(notes: notes ?? this.notes);

  @override
  bool operator ==(Object other) =>
      other is OtherDetails && other.notes == notes;

  @override
  int get hashCode => notes.hashCode;
}
