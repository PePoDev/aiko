import 'package:aiko/core/import_export/export_package.dart';
import 'package:aiko/features/import_export/application/export_package_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sensitive export scopes require acknowledgement', () {
    const service = ExportPackageService();

    final package = service.create(
      scope: ExportScope.taxData,
      format: ExportFormat.pdf,
    );

    expect(package.requiresSensitivityWarning, isTrue);
    expect(package.canCreate, isFalse);
  });

  test('acknowledged sensitive export can be created', () {
    const package = ExportPackage(
      scope: ExportScope.allData,
      format: ExportFormat.json,
      sensitivityAcknowledged: true,
    );

    expect(package.canCreate, isTrue);
  });
}
