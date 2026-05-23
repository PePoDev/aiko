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

  Trip copyWith({
    String? name,
    String? homeCurrency,
    String? localCurrency,
    Money? budget,
    List<Money>? foreignFees,
  }) {
    return Trip(
      name: name ?? this.name,
      homeCurrency: homeCurrency ?? this.homeCurrency,
      localCurrency: localCurrency ?? this.localCurrency,
      budget: budget ?? this.budget,
      foreignFees: foreignFees ?? this.foreignFees,
    );
  }
}
