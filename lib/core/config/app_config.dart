/// Default values for the user's profile. Onboarding, the auth
/// repository, and the profile repository all default to THB/TH until the user
/// picks something; the single source of truth lives here so a new entry point
/// doesn't reintroduce a different default.
const String kDefaultBaseCurrency = 'THB';
const String kDefaultCountry = 'TH';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return AppConfig(supabaseUrl: url, supabaseAnonKey: anonKey);
  }

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Whether cloud creds are present. Supabase is always the backend; without
  /// creds the app runs local-only (SQLite) until they're supplied.
  bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
