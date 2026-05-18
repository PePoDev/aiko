import '../domain/saved_calculator_scenario.dart';

class CalculatorScenarioRepository {
  final List<SavedCalculatorScenario> _scenarios = [];

  Future<List<SavedCalculatorScenario>> list() async =>
      List.unmodifiable(_scenarios);

  Future<SavedCalculatorScenario> save(SavedCalculatorScenario scenario) async {
    _scenarios.add(scenario);
    return scenario;
  }
}
