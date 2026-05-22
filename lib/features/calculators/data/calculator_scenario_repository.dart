import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/saved_calculator_scenario.dart';

class CalculatorScenarioRepository {
  const CalculatorScenarioRepository();

  Future<List<SavedCalculatorScenario>> list() async {
    final session = AikoSupabase.requireSession();
    final response = await session.client
        .from('saved_calculator_scenarios')
        .select()
        .eq('user_id', session.userId)
        .order('created_at', ascending: false);

    return response
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<SavedCalculatorScenario> save(SavedCalculatorScenario scenario) async {
    final session = AikoSupabase.requireSession();
    final scenarioWithUser = SavedCalculatorScenario(
      id: scenario.id,
      userId: session.userId,
      calculatorType: scenario.calculatorType,
      input: scenario.input,
      result: scenario.result,
      notes: scenario.notes,
      convertedEntityType: scenario.convertedEntityType,
      convertedEntityId: scenario.convertedEntityId,
    );

    await session.client
        .from('saved_calculator_scenarios')
        .upsert(_toRow(scenarioWithUser));
    return scenarioWithUser;
  }

  static SavedCalculatorScenario _fromRow(Map<String, dynamic> row) {
    return SavedCalculatorScenario(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      calculatorType: row['calculator_type'] as String,
      input: Map<String, Object?>.from(row['input_json'] as Map),
      result: Map<String, Object?>.from(row['result_json'] as Map),
      notes: row['notes'] as String?,
      convertedEntityType: row['converted_entity_type'] as String?,
      convertedEntityId: row['converted_entity_id'] as String?,
    );
  }

  static Map<String, dynamic> _toRow(SavedCalculatorScenario scenario) {
    return {
      'id': scenario.id,
      'user_id': scenario.userId,
      'calculator_type': scenario.calculatorType,
      'input_json': scenario.input,
      'result_json': scenario.result,
      'notes': scenario.notes,
      'converted_entity_type': scenario.convertedEntityType,
      'converted_entity_id': scenario.convertedEntityId,
    };
  }
}
