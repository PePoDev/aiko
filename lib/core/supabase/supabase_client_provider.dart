import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class AikoSupabase {
  const AikoSupabase._();

  static Future<void> initialize(AppConfig config) async {
    if (!config.enableSupabase || Supabase.instance.isInitialized) {
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
  }

  static SupabaseClient? tryClient() {
    if (!Supabase.instance.isInitialized) {
      return null;
    }
    return Supabase.instance.client;
  }
}
