import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class AikoSupabase {
  const AikoSupabase._();

  static bool _initialized = false;

  static Future<void> initialize(AppConfig config) async {
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
    );
    _initialized = true;
  }

  static SupabaseClient? tryClient() {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }
}
