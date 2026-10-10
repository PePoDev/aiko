import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/auth/data/defaults_seed_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are unseeded until marked, per user', () async {
    final marker = DefaultsSeedMarker(MemorySecureStorageService());

    expect(await marker.isSeeded('alice'), isFalse);
    await marker.markSeeded('alice');
    expect(await marker.isSeeded('alice'), isTrue);
    expect(await marker.isSeeded('bob'), isFalse);
  });

  test('a stamp from an older default set triggers a re-check', () async {
    final storage = MemorySecureStorageService();
    await storage.write('aiko_defaults_seeded:alice', '0:13:80');

    expect(await DefaultsSeedMarker(storage).isSeeded('alice'), isFalse);
  });

  test('the stamp tracks the current template counts', () {
    expect(DefaultsSeedMarker.stamp, '${DefaultsSeedMarker.version}:13:81');
  });
}
