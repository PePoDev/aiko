/// The asset classes a holding can have, stored as these English names and
/// shown in the current language (`investmentAssetClassLabel`).
const investmentAssetClasses = [
  'Stocks',
  'Bonds',
  'Funds',
  'Crypto',
  'Cash',
  'Custom',
];

class AllocationTarget {
  const AllocationTarget({
    required this.assetClass,
    required this.targetPercent,
  });

  final String assetClass;
  final double targetPercent;
}
