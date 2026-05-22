import 'package:aiko/features/settings/data/notification_preference_repository.dart';
import 'package:aiko/features/settings/domain/notification_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification preference repository requires Supabase', () async {
    const repository = NotificationPreferenceRepository();

    await expectLater(
      repository.save(
        const NotificationPreference(
          userId: 'user',
          type: NotificationType.billDue,
          sourceModule: NotificationSourceModule.bills,
          isEnabled: true,
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      repository.listForModule('user', NotificationSourceModule.bills),
      throwsStateError,
    );
  });

  test('notification preference model keeps source module metadata', () {
    expect(
      const NotificationPreference(
        userId: 'user',
        type: NotificationType.billDue,
        sourceModule: NotificationSourceModule.bills,
        isEnabled: true,
      ).sourceModule,
      NotificationSourceModule.bills,
    );
  });
}
