import 'package:aiko/app/firebase_sync.dart';
import 'package:aiko/app/locale_controller.dart';
import 'package:aiko/app/providers.dart';
import 'package:aiko/features/dashboard/application/notification_dismissals.dart';
import 'package:aiko/features/learning_hub/application/lesson_progress.dart';
import 'package:aiko/features/transactions/data/transaction_rule_store.dart';
import 'package:aiko/features/travel_mode/application/travel_mode_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preferenceProvidersToRefresh', () {
    test('reloads only the providers built from the changed documents', () {
      expect(
        preferenceProvidersToRefresh({NotificationDismissalStore.storageKey}),
        {notificationDismissalsProvider},
      );
      expect(
        preferenceProvidersToRefresh({
          AppLocaleController.languageKey,
          LessonProgressStore.storageKey,
        }),
        {appLocaleControllerProvider, lessonProgressProvider},
      );
      expect(preferenceProvidersToRefresh({TransactionRuleStore.legacyKey}), {
        transactionRulesProvider,
      });
    });

    test('reloads every preference provider when the change is unknown', () {
      final all = preferenceProvidersToRefresh(null);
      expect(
        all,
        containsAll([
          appLocaleControllerProvider,
          transactionRulesProvider,
          storedTravelProvider,
          notificationDismissalsProvider,
          lessonProgressProvider,
        ]),
      );
      expect(preferenceProvidersToRefresh({'travel_mode_v2'}), all);
    });
  });
}
