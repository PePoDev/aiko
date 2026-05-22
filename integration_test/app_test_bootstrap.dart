import 'package:aiko/app/aiko_app.dart';
import 'package:aiko/core/config/app_config.dart';
import 'package:aiko/core/supabase/supabase_client_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const integrationSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const integrationSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const integrationTestEmail = String.fromEnvironment('AIKO_TEST_EMAIL');
const integrationTestPassword = String.fromEnvironment('AIKO_TEST_PASSWORD');
const hasSupabaseIntegrationConfig =
    integrationSupabaseUrl != '' &&
    integrationSupabaseAnonKey != '' &&
    integrationTestEmail != '' &&
    integrationTestPassword != '';

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
  const config = AppConfig(
    supabaseUrl: integrationSupabaseUrl,
    supabaseAnonKey: integrationSupabaseAnonKey,
    environment: 'test',
    enableSupabase:
        integrationSupabaseUrl != '' && integrationSupabaseAnonKey != '',
  );
  await AikoSupabase.initialize(config);
  await tester.pumpWidget(const AikoApp(config: config));
  await tester.pumpAndSettle();
}
