import 'package:aiko/features/import_export/presentation/import_export_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows import preview, export, and backup states', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ImportExportScreen()));

    expect(find.text('Preview import'), findsOneWidget);
    expect(find.text('Export package'), findsOneWidget);
    expect(find.text('Backup status'), findsOneWidget);
  });
}
