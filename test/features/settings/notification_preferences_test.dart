import 'package:aiko/features/settings/data/notification_preference_repository.dart';
import 'package:aiko/features/settings/domain/notification_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps notification preferences by source module', () async {
    final repository = NotificationPreferenceRepository();
    await repository.save(
      const NotificationPreference(
        userId: 'user',
        type: NotificationType.billDue,
        sourceModule: NotificationSourceModule.bills,
        isEnabled: true,
      ),
    );
    await repository.save(
      const NotificationPreference(
        userId: 'user',
        type: NotificationType.portfolioDrift,
        sourceModule: NotificationSourceModule.portfolio,
        isEnabled: false,
      ),
    );

    final billPreferences = await repository.listForModule(
      'user',
      NotificationSourceModule.bills,
    );

    expect(billPreferences, hasLength(1));
    expect(billPreferences.single.type, NotificationType.billDue);
    expect(billPreferences.single.isEnabled, isTrue);
  });
}
