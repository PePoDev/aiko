import '../../../core/import_export/export_package.dart';

class ExportPackageService {
  const ExportPackageService();

  ExportPackage create({
    required ExportScope scope,
    required ExportFormat format,
    bool sensitivityAcknowledged = false,
  }) {
    return ExportPackage(
      scope: scope,
      format: format,
      sensitivityAcknowledged: sensitivityAcknowledged,
    );
  }
}
