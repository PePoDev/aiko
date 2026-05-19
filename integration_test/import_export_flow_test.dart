import 'package:aiko/core/import_export/export_package.dart';
import 'package:aiko/features/import_export/application/export_package_service.dart';
import 'package:aiko/features/import_export/application/import_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import preview to export package flow', (tester) async {
    const importService = ImportPreviewService();
    const exportService = ExportPackageService();

    final preview = importService.preview([
      {'date': '2026-05-01', 'amount': '24.00', 'merchant': 'Grocer'},
    ]);
    final package = exportService.create(
      scope: ExportScope.transactions,
      format: ExportFormat.csv,
    );

    expect(preview.canImport, isTrue);
    expect(package.canCreate, isTrue);
  });
}
