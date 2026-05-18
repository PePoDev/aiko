import '../domain/saved_calculator_scenario.dart';

class CalculatorConversionService {
  const CalculatorConversionService();

  SavedCalculatorScenario markConverted(
    SavedCalculatorScenario scenario, {
    required String entityType,
    required String entityId,
  }) {
    return SavedCalculatorScenario(
      id: scenario.id,
      userId: scenario.userId,
      calculatorType: scenario.calculatorType,
      input: scenario.input,
      result: scenario.result,
      notes: scenario.notes,
      convertedEntityType: entityType,
      convertedEntityId: entityId,
    );
  }
}
