import '../../../core/money/money.dart';

class Trip {
  const Trip({
    required this.name,
    required this.homeCurrency,
    required this.localCurrency,
    required this.budget,
    this.foreignFees = const <Money>[],
  });

  final String name;
  final String homeCurrency;
  final String localCurrency;
  final Money budget;
  final List<Money> foreignFees;
}
