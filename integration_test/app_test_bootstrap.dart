import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_app.dart';

/// Ensures the integration test binding is ready and clears any persisted
/// secure-storage state so every test starts from a clean splash screen.
///
/// Usage in each test file:
/// ```dart
/// await bootstrapIntegrationTest(tester);
/// ```
Future<void> bootstrapIntegrationTest(WidgetTester tester) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await const FlutterSecureStorage().deleteAll();
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();
}
