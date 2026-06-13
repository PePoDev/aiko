import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';

class InvestmentHolding {
  const InvestmentHolding({
    required this.id,
    required this.symbol,
    required this.assetClass,
    required this.quantity,
    required this.averageCost,
    required this.currentPrice,
    this.userId = '',
    this.targetAllocationPercent,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String symbol;
  final String assetClass;
  final double quantity;
  final Money averageCost;
  final Money currentPrice;
  final double? targetAllocationPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get currency => currentPrice.currency;

  Money get marketValue => currentPrice.times(Decimal.parse('$quantity'));

  Money get unrealizedGainLoss =>
      marketValue - averageCost.times(Decimal.parse('$quantity'));

  InvestmentHolding copyWith({
    String? id,
    String? userId,
    String? symbol,
    String? assetClass,
    double? quantity,
    Money? averageCost,
    Money? currentPrice,
    double? targetAllocationPercent,
    bool clearTargetAllocation = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvestmentHolding(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      symbol: symbol ?? this.symbol,
      assetClass: assetClass ?? this.assetClass,
      quantity: quantity ?? this.quantity,
      averageCost: averageCost ?? this.averageCost,
      currentPrice: currentPrice ?? this.currentPrice,
      targetAllocationPercent: clearTargetAllocation
          ? null
          : (targetAllocationPercent ?? this.targetAllocationPercent),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
