class SavedCalculatorScenario {
  const SavedCalculatorScenario({
    required this.id,
    required this.userId,
    required this.calculatorType,
    required this.input,
    required this.result,
    this.notes,
    this.convertedEntityType,
    this.convertedEntityId,
  });

  final String id;
  final String userId;
  final String calculatorType;
  final Map<String, Object?> input;
  final Map<String, Object?> result;
  final String? notes;
  final String? convertedEntityType;
  final String? convertedEntityId;
}
