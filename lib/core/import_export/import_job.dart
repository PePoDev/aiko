enum ImportJobStatus { preview, ready, importing, completed, canceled }

class ImportValidationIssue {
  const ImportValidationIssue({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;
}

class ImportJob {
  const ImportJob({
    required this.sourceType,
    required this.status,
    this.validationIssues = const <ImportValidationIssue>[],
    this.duplicateCount = 0,
  });

  final String sourceType;
  final ImportJobStatus status;
  final List<ImportValidationIssue> validationIssues;
  final int duplicateCount;

  bool get canImport =>
      status == ImportJobStatus.ready && validationIssues.isEmpty;

  bool get needsReview => validationIssues.isNotEmpty || duplicateCount > 0;
}
