import 'package:aiko/core/security/app_lock_service.dart';
import 'package:aiko/features/auth/application/app_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app lock configures and unlocks with PIN', () async {
    final controller = AppLockController(InMemoryAppLockService());
    await controller.enablePin('1234');
    await controller.lock();

    expect(await controller.currentStatus(), AppLockStatus.locked);
    expect(await controller.unlock('1234'), isTrue);
  });
}
