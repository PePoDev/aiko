import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AikoSupabase {
  const AikoSupabase._();

  static bool _initialized = false;

  static Future<void> initialize(
    AppConfig config, {
    http.Client? httpClient,
  }) async {
    if (!config.enableSupabase || _initialized) {
      return;
    }
    if (!config.supabaseUrl.startsWith('https://')) {
      throw ArgumentError(
        'SUPABASE_URL must be a Supabase Cloud HTTPS project URL.',
      );
    }
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      httpClient: httpClient,
    );
    _initialized = true;
  }

  static SupabaseClient? tryClient() {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }

  static SupabaseClient requireClient() {
    final client = tryClient();
    if (client == null) {
      throw StateError(
        'Supabase is required. Run Aiko with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    return client;
  }
}
