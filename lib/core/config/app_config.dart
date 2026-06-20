const String kDefaultBaseCurrency = 'THB';
const String kDefaultCountry = 'TH';

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return AppConfig(supabaseUrl: url, supabaseAnonKey: anonKey);
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
}
