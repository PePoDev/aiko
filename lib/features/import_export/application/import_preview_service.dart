import '../../../core/import_export/import_job.dart';

class ImportPreviewService {
  const ImportPreviewService();

  ImportJob preview(List<Map<String, String>> rows) {
    final seen = <String>{};
    final issues = <ImportValidationIssue>[];
    var duplicates = 0;

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final amount = row['amount'];
      final date = row['date'];
      final key = '$date|$amount|${row['merchant'] ?? ''}';

      if (amount == null || amount.isEmpty) {
        issues.add(
          ImportValidationIssue(
            rowNumber: index + 1,
            message: 'Amount is required.',
          ),
        );
      }

      if (date == null || date.isEmpty) {
        issues.add(
          ImportValidationIssue(
            rowNumber: index + 1,
            message: 'Date is required.',
          ),
        );
      }

      if (!seen.add(key)) {
        duplicates++;
      }
    }

    return ImportJob(
      sourceType: 'csv',
      status: issues.isEmpty ? ImportJobStatus.ready : ImportJobStatus.preview,
      validationIssues: issues,
      duplicateCount: duplicates,
    );
  }
}
