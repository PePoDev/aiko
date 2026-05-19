enum AikoAlertSeverity { info, caution, urgent }

class AikoAlert {
  const AikoAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.sourceType,
  });

  final String title;
  final String message;
  final AikoAlertSeverity severity;
  final String sourceType;

  bool get requiresAction => severity == AikoAlertSeverity.urgent;
}
