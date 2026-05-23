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
const hasSupabaseProjectConfig =
    integrationSupabaseUrl != '' && integrationSupabaseAnonKey != '';
const hasSupabaseIntegrationConfig =
    hasSupabaseProjectConfig &&
    integrationTestEmail != '' &&
    integrationTestPassword != '';

class IntegrationTestAccount {
  const IntegrationTestAccount({required this.email, required this.password});

  final String email;
  final String password;
}

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

Future<IntegrationTestAccount> createIntegrationTestAccount() async {
  final client = AikoSupabase.requireClient();
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final account = IntegrationTestAccount(
    email: 'aiko.integration.$timestamp@example.com',
    password: 'AikoTest#$timestamp!',
  );

  final response = await client.auth.signUp(
    email: account.email,
    password: account.password,
  );

  if (response.user == null) {
    throw StateError('Failed to create integration test account.');
  }

  if (client.auth.currentSession == null) {
    throw StateError(
      'Integration tests require email confirmation to be disabled in Supabase Auth.',
    );
  }

  await client.auth.signOut();
  return account;
}

Future<void> cleanupIntegrationTestAccount(
  IntegrationTestAccount account,
) async {
  final client = AikoSupabase.requireClient();
  try {
    final currentUser = client.auth.currentUser;
    final isTargetUser = currentUser?.email == account.email;
    if (!isTargetUser) {
      await client.auth.signInWithPassword(
        email: account.email,
        password: account.password,
      );
    }

    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      await client.from('profiles').delete().eq('id', userId);
    }
  } catch (_) {
    // Cleanup should be best-effort to avoid masking test assertions.
  } finally {
    await client.auth.signOut();
    await const FlutterSecureStorage().deleteAll();
  }
}
