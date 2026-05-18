class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.environment,
    this.enableSupabase = true,
  });

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://127.0.0.1:54321',
    );
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const environment = String.fromEnvironment(
      'AIKO_ENV',
      defaultValue: 'local',
    );

    return AppConfig(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      environment: environment,
      enableSupabase: anonKey.isNotEmpty,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String environment;
  final bool enableSupabase;

  bool get isLocal => environment == 'local';
}
