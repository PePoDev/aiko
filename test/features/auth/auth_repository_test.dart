import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('hasKnownAccount returns false on fresh storage', () async {
    final repository = AuthRepository(storage: MemorySecureStorageService());

    expect(await repository.hasKnownAccount(), isFalse);
  });

  test('signOut starts a fresh anonymous offline identity', () async {
    final storage = MemorySecureStorageService();
    final context = OfflineUserContext(storage: storage);
    final previousId = await context.resolveUserId();
    final repository = AuthRepository(
      storage: storage,
      client: SupabaseClient('https://offline.aiko.local', 'offline-anon-key'),
    );

    await repository.signOut();

    final anonymousId = await context.resolveUserId();
    expect(anonymousId, startsWith(OfflineUserContext.localUserIdPrefix));
    expect(anonymousId, isNot(previousId));
  });

  test('repairs category clones immediately after profile upsert', () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://offline.aiko.local',
      'offline-anon-key',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.method == 'GET' &&
            request.url.path == '/rest/v1/accounts') {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          request.url.path.contains('/rpc/') ? 'null' : '[]',
          request.url.path.contains('/rpc/') ? 200 : 201,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final repository = AuthRepository(
      storage: MemorySecureStorageService(),
      client: client,
    );

    await repository.ensureProfileAndDefaultsExistForTesting(
      '11111111-1111-4111-8111-111111111111',
      'clone@example.test',
    );

    expect(paths.take(3), [
      '/rest/v1/profiles',
      '/rest/v1/rpc/ensure_default_category_clones',
      '/rest/v1/accounts',
    ]);
  });
}
