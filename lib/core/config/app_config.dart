class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.environment,
    this.enableSupabase = true,
  });

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const environment = String.fromEnvironment(
      'AIKO_ENV',
      defaultValue: 'development',
    );

    return AppConfig(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      environment: environment,
      enableSupabase: url.isNotEmpty && anonKey.isNotEmpty,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String environment;
  final bool enableSupabase;

  bool get isLocal => environment == 'local';

  bool get isCloudConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
