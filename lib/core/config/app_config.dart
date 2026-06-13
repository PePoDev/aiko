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
