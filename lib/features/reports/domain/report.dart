class Report {
  const Report({
    required this.id,
    required this.userId,
    required this.type,
    required this.periodStart,
    required this.periodEnd,
    required this.summary,
  });

  final String id;
  final String userId;
  final String type;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, Object?> summary;
}
