/// Default values for the user's profile. Onboarding, the auth
/// repository, and the profile repository all default to USD/US until the user
/// picks something; the single source of truth lives here so a new entry point
/// doesn't reintroduce a different default.
const String kDefaultBaseCurrency = 'USD';
const String kDefaultCountry = 'US';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.enableSupabase = true,
  });

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return AppConfig(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      enableSupabase: url.isNotEmpty && anonKey.isNotEmpty,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool enableSupabase;
}
