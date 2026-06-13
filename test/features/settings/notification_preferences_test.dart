import 'package:aiko/features/settings/data/notification_preference_repository.dart';
import 'package:aiko/features/settings/domain/notification_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification preference repository falls back offline', () async {
    const repository = NotificationPreferenceRepository();

    await repository.save(
      const NotificationPreference(
        userId: 'user',
        type: NotificationType.recurringDue,
        sourceModule: NotificationSourceModule.recurring,
        isEnabled: true,
      ),
    );
    expect(
      await repository.listForModule(
        'user',
        NotificationSourceModule.recurring,
      ),
      isEmpty,
    );
  });
}
