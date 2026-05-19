import 'package:aiko/features/import_export/application/import_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('import preview flags validation issues and duplicates', () {
    const service = ImportPreviewService();

    final job = service.preview([
      {'date': '2026-05-01', 'amount': '12.00', 'merchant': 'Cafe'},
      {'date': '2026-05-01', 'amount': '12.00', 'merchant': 'Cafe'},
      {'date': '', 'amount': '', 'merchant': 'Store'},
    ]);

    expect(job.duplicateCount, 1);
    expect(job.validationIssues, hasLength(2));
    expect(job.needsReview, isTrue);
  });
}
