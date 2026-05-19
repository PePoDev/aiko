import '../../../core/import_export/export_package.dart';
import '../../../core/import_export/import_job.dart';

class ImportJobDto {
  const ImportJobDto({
    required this.sourceType,
    required this.status,
    this.duplicateCount = 0,
  });

  final String sourceType;
  final String status;
  final int duplicateCount;

  ImportJob toDomain() {
    return ImportJob(
      sourceType: sourceType,
      status: ImportJobStatus.values.byName(status),
      duplicateCount: duplicateCount,
    );
  }
}

class ExportPackageDto {
  const ExportPackageDto({
    required this.scope,
    required this.format,
    required this.sensitivityAcknowledged,
  });

  final String scope;
  final String format;
  final bool sensitivityAcknowledged;

  ExportPackage toDomain() {
    return ExportPackage(
      scope: ExportScope.values.byName(scope),
      format: ExportFormat.values.byName(format),
      sensitivityAcknowledged: sensitivityAcknowledged,
    );
  }
}
