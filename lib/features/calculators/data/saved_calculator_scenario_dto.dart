import '../domain/saved_calculator_scenario.dart';

class SavedCalculatorScenarioDto {
  const SavedCalculatorScenarioDto(this.json);

  final Map<String, dynamic> json;

  SavedCalculatorScenario toDomain() {
    return SavedCalculatorScenario(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      calculatorType: json['calculator_type'] as String,
      input: Map<String, Object?>.from(json['input_json'] as Map? ?? {}),
      result: Map<String, Object?>.from(json['result_json'] as Map? ?? {}),
      notes: json['notes'] as String?,
      convertedEntityType: json['converted_entity_type'] as String?,
      convertedEntityId: json['converted_entity_id'] as String?,
    );
  }
}
