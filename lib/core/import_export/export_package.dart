enum ExportFormat { csv, pdf, excel, json }

enum ExportScope {
  allData,
  transactions,
  reports,
  taxData,
  calculatorScenarios,
}

class ExportPackage {
  const ExportPackage({
    required this.scope,
    required this.format,
    this.sensitivityAcknowledged = false,
  });

  final ExportScope scope;
  final ExportFormat format;
  final bool sensitivityAcknowledged;

  bool get requiresSensitivityWarning =>
      scope == ExportScope.allData || scope == ExportScope.taxData;

  bool get canCreate => !requiresSensitivityWarning || sensitivityAcknowledged;
}
