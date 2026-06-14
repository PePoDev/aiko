import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../assets/domain/asset.dart';
import '../domain/account_details.dart';

class AccountDetailsDto {
  const AccountDetailsDto._();

  static Map<String, dynamic> toJson(AccountDetails d) {
    final base = <String, dynamic>{'_type': d.variantName};
    switch (d) {
      case CashDetails():
        break;
      case BankDetails():
        base['accountNumberLast4'] = d.accountNumberLast4;
        base['accountHolderName'] = d.accountHolderName;
      case EWalletDetails():
        base['linkedPhoneOrEmail'] = d.linkedPhoneOrEmail;
      case CreditCardDetails():
        base['creditLimit'] = d.creditLimit?.toJson();
        base['statementDay'] = d.statementDay;
        base['dueDay'] = d.dueDay;
        base['aprPercent'] = d.aprPercent;
        base['rewardsType'] = d.rewardsType?.name;
        base['annualFee'] = d.annualFee?.toJson();
        base['minimumPayment'] = d.minimumPayment?.toJson();
        base['sharesLimit'] = d.sharesLimit;
        base['sharedLimitAccountId'] = d.sharedLimitAccountId;
      case LoanDetails():
        base['loanType'] = d.loanType.name;
        base['principal'] = d.principal.toJson();
        base['interestRatePercent'] = d.interestRatePercent;
        base['termMonths'] = d.termMonths;
        base['monthlyPayment'] = d.monthlyPayment.toJson();
        base['nextDueDate'] = d.nextDueDate.toIso8601String();
      case InvestmentDetails():
        base['accountNumberLast4'] = d.accountNumberLast4;
      case AssetDetails():
        base['assetClass'] = d.assetClass.name;
        base['purchasePrice'] = d.purchasePrice?.toJson();
        base['purchaseDate'] = d.purchaseDate?.toIso8601String();
        base['notes'] = d.notes;
      case LiabilityDetails():
        base['liabilityType'] = d.liabilityType;
        base['interestRatePercent'] = d.interestRatePercent;
        base['notes'] = d.notes;
      case OtherDetails():
        base['notes'] = d.notes;
    }
    return base;
  }

  static AccountDetails fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CashDetails();
    final type = json['_type'] as String?;
    return switch (type) {
      'cash' => const CashDetails(),
      'bank' => BankDetails(
          accountNumberLast4: json['accountNumberLast4'] as String?,
          accountHolderName: json['accountHolderName'] as String?,
        ),
      'eWallet' => EWalletDetails(
          linkedPhoneOrEmail: json['linkedPhoneOrEmail'] as String?,
        ),
      'creditCard' => CreditCardDetails(
          creditLimit: _money(json['creditLimit']),
          statementDay: (json['statementDay'] as int?) ?? 1,
          dueDay: (json['dueDay'] as int?) ?? 1,
          aprPercent: (json['aprPercent'] as num?)?.toDouble(),
          rewardsType: _rewardsType(json['rewardsType'] as String?),
          annualFee: _money(json['annualFee']),
          minimumPayment: _money(json['minimumPayment']),
          sharesLimit: (json['sharesLimit'] as bool?) ?? false,
          sharedLimitAccountId: json['sharedLimitAccountId'] as String?,
        ),
      'loan' => LoanDetails(
          loanType: _loanType(json['loanType'] as String?),
          principal: _money(json['principal'], 'USD') ??
              Money.zero('USD'),
          interestRatePercent:
              (json['interestRatePercent'] as num?)?.toDouble() ?? 0,
          termMonths: (json['termMonths'] as int?) ?? 1,
          monthlyPayment:
              _money(json['monthlyPayment'], 'USD') ?? Money.zero('USD'),
          nextDueDate: json['nextDueDate'] is String
              ? DateTime.parse(json['nextDueDate'] as String)
              : DateTime.utc(1970, 1, 1),
        ),
      'investment' => InvestmentDetails(
          accountNumberLast4: json['accountNumberLast4'] as String?,
        ),
      'asset' => AssetDetails(
          assetClass: _assetClass(json['assetClass'] as String?),
          purchasePrice: _money(json['purchasePrice']),
          purchaseDate: json['purchaseDate'] is String
              ? DateTime.parse(json['purchaseDate'] as String)
              : null,
          notes: json['notes'] as String?,
        ),
      'liability' => LiabilityDetails(
          liabilityType: json['liabilityType'] as String?,
          interestRatePercent: (json['interestRatePercent'] as num?)?.toDouble(),
          notes: json['notes'] as String?,
        ),
      'other' => OtherDetails(notes: json['notes'] as String?),
      _ => const CashDetails(),
    };
  }

  static Money? _money(Object? raw, [String fallback = 'USD']) {
    if (raw is! Map) return null;
    final m = raw;
    final amt = m['amount'];
    final cur = (m['currency'] as String?) ?? fallback;
    if (amt is! String) return null;
    final parsed = Decimal.tryParse(amt);
    if (parsed == null) return null;
    return Money(amount: parsed, currency: cur);
  }

  static RewardsType? _rewardsType(String? name) {
    if (name == null) return null;
    for (final v in RewardsType.values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static LoanType _loanType(String? name) {
    if (name == null) return LoanType.other;
    for (final v in LoanType.values) {
      if (v.name == name) return v;
    }
    return LoanType.other;
  }

  static AssetClass _assetClass(String? name) {
    if (name == null) return AssetClass.other;
    for (final v in AssetClass.values) {
      if (v.name == name) return v;
    }
    return AssetClass.other;
  }
}
