import 'package:aiko/core/supabase/supabase_client_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AikoSupabase URL policy', () {
    test('accepts cloud HTTPS and local self-hosted HTTP URLs', () {
      expect(
        AikoSupabase.isSupportedProjectUrl(
          'https://example-project.supabase.co',
        ),
        isTrue,
      );
      expect(
        AikoSupabase.isSupportedProjectUrl('http://localhost:8000'),
        isTrue,
      );
      expect(
        AikoSupabase.isSupportedProjectUrl('http://10.0.2.2:8000'),
        isTrue,
      );
    });

    test('rejects arbitrary HTTP URLs', () {
      expect(AikoSupabase.isSupportedProjectUrl('http://example.com'), isFalse);
    });
  });
}
