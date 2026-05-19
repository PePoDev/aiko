import '../../../core/money/money.dart';

enum AssetClass { cash, stocks, realEstate, vehicle, other }

class Asset {
  const Asset({
    required this.name,
    required this.assetClass,
    required this.value,
    this.isLiability = false,
  });

  final String name;
  final AssetClass assetClass;
  final Money value;
  final bool isLiability;
}
