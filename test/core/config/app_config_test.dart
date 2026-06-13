import 'package:aiko/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConfig only carries Supabase connection settings', () {
    const config = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      enableSupabase: true,
    );

    expect(config.supabaseUrl, 'https://example.supabase.co');
    expect(config.supabaseAnonKey, 'anon-key');
    expect(config.enableSupabase, isTrue);
  });
}
