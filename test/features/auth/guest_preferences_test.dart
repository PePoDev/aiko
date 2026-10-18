import 'dart:convert';

import 'package:aiko/app/locale_controller.dart';
import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/storage/synced_preferences.dart';
import 'package:aiko/features/auth/data/guest_preferences.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/dashboard/application/notification_dismissals.dart';
import 'package:aiko/features/learning_hub/application/lesson_progress.dart';
import 'package:aiko/features/learning_hub/domain/lesson.dart';
import 'package:aiko/features/transactions/data/transaction_rule_store.dart';
import 'package:aiko/features/transactions/domain/transaction_rule.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/storage/offline_firestore.dart';

const _uid = 'user-1';

TransactionRule _rule(
  String id, {
  RuleConditionType type = RuleConditionType.merchant,
  String value = 'Starbucks',
  String? target,
}) => TransactionRule(
  id: id,
  userId: 'local:guest',
  name: id,
  conditionType: type,
  operator: RuleConditionOperator.contains,
  conditionValue: value,
  targetCategoryId: target,
);

String _trip(String name) => jsonEncode({
  'trip': {'name': name},
  'rate': 0.25,
});

void main() {
  late FakeFirebaseFirestore firestore;
  late MemorySecureStorageService device;
  late SyncedPreferences account;
  late GuestPreferences guest;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    device = MemorySecureStorageService();
    account = SyncedPreferences(
      local: device,
      firestore: firestore,
      userId: () => _uid,
      sync: FirestoreSyncState(
        firstSnapshotWait: Duration.zero,
        serverWait: const Duration(milliseconds: 50),
      ),
    );
    guest = GuestPreferences(
      device: device,
      account: account,
      signedInUserId: () => _uid,
    );
  });

  Future<void> setUpGuest() async {
    await device.write(AppLocaleController.languageKey, 'th');
    await device.write(GuestPreferences.travelKey, _trip('Japan'));
    final rules = TransactionRuleStore(storage: device);
    await rules.saveRule(_rule('coffee', target: CategoryDefaults.coffeeId));
    await rules.saveRule(
      _rule(
        'pets',
        type: RuleConditionType.category,
        value: 'guest-pets',
        target: 'guest-pets',
      ),
    );
    await LessonProgressStore(
      device,
    ).record('budget-basics', LessonProgress.completed);
    await NotificationDismissalStore(device).dismiss('bill:1', const []);
  }

  test('a guest\'s preferences move into a new account and leave the '
      'device', () async {
    await setUpGuest();

    await guest.claim(
      _uid,
      categoryId: (id) => id == 'guest-pets'
          ? 'account-pets'
          : CategoryDefaults.categoryIdForUser(userId: _uid, categoryId: id),
    );

    expect(await account.read(AppLocaleController.languageKey), 'th');
    expect(await account.read(GuestPreferences.travelKey), _trip('Japan'));
    final rules = {
      for (final rule in await TransactionRuleStore(storage: account).load())
        rule.id: rule,
    };
    expect(rules.keys, unorderedEquals(['coffee', 'pets']));
    expect(rules['coffee']!.userId, _uid);
    expect(
      rules['coffee']!.targetCategoryId,
      CategoryDefaults.cloneIdForUser(
        userId: _uid,
        templateId: CategoryDefaults.coffeeId,
      ),
    );
    expect(rules['pets']!.conditionValue, 'account-pets');
    expect(rules['pets']!.targetCategoryId, 'account-pets');
    expect(await LessonProgressStore(account).load(), {
      'budget-basics': LessonProgress.completed,
    });
    expect(await NotificationDismissalStore(account).load(), {'bill:1'});
    for (final key in GuestPreferences.dataKeys) {
      expect(await device.read(key), isNull, reason: key);
    }
    // Welcome and the login screen still use it after a log-out.
    expect(await device.read(AppLocaleController.languageKey), 'th');
  });

  test('an existing account keeps its own language and trip, and gains the '
      'guest\'s rules and progress', () async {
    await account.write(AppLocaleController.languageKey, 'en');
    await account.write(GuestPreferences.travelKey, _trip('Laos'));
    await TransactionRuleStore(storage: account).saveRule(_rule('own'));
    await LessonProgressStore(
      account,
    ).record('budget-basics', LessonProgress.read);
    await setUpGuest();

    await guest.claim(_uid);

    expect(await account.read(AppLocaleController.languageKey), 'en');
    expect(await account.read(GuestPreferences.travelKey), _trip('Laos'));
    expect(
      (await TransactionRuleStore(storage: account).load()).map((r) => r.id),
      unorderedEquals(['own', 'coffee', 'pets']),
    );
    expect(await LessonProgressStore(account).load(), {
      'budget-basics': LessonProgress.completed,
    });
    expect(await device.read(AppLocaleController.languageKey), 'th');
  });

  test('the account keeps every dismissal of its own, old ones too', () async {
    // From the earlier format (no time), and one dismissed long ago.
    await firestore
        .collection('users')
        .doc(_uid)
        .collection('preferences')
        .doc(NotificationDismissalStore.legacyKey)
        .set({'value': '["goal:g1:100"]'});
    await NotificationDismissalStore(
      account,
      clock: () => DateTime.utc(2020),
    ).dismiss('bill:old', const ['goal:g1:100']);
    await setUpGuest();

    await guest.claim(_uid);

    expect(await NotificationDismissalStore(account).load(), {
      'goal:g1:100',
      'bill:old',
      'bill:1',
    });
  });

  test('while the account can\'t be read, its language and trip are left '
      'alone and the trip waits on the device', () async {
    final offline = SyncedPreferences(
      local: device,
      // Offline, with nothing cached: reads never answer.
      firestore: OfflineFirestore(),
      userId: () => _uid,
      sync: FirestoreSyncState(
        firstSnapshotWait: Duration.zero,
        serverWait: const Duration(milliseconds: 20),
      ),
    );
    await setUpGuest();

    await GuestPreferences(
      device: device,
      account: offline,
      signedInUserId: () => _uid,
    ).claim(_uid);

    // Nothing written to the account (each write updates this copy first).
    for (final key in [
      AppLocaleController.languageKey,
      GuestPreferences.travelKey,
    ]) {
      expect(await device.read('$_uid:$key'), isNull, reason: key);
    }
    expect(await device.read(AppLocaleController.languageKey), 'th');
    expect(await device.read(GuestPreferences.travelKey), _trip('Japan'));
    // Rules wait among the account's deferred changes instead.
    expect(await device.read(TransactionRuleStore.storageKey), isNull);
  });

  test('nothing moves unless that account is signed in', () async {
    await setUpGuest();

    await GuestPreferences(
      device: device,
      account: account,
      signedInUserId: () => null,
    ).claim(_uid);

    expect(await device.read(AppLocaleController.languageKey), 'th');
    expect(await device.read(TransactionRuleStore.storageKey), isNotNull);
    expect(await account.read(AppLocaleController.languageKey), isNull);
  });

  test('clearing removes the guest\'s data but keeps the language', () async {
    await setUpGuest();

    await guest.clear();

    for (final key in GuestPreferences.dataKeys) {
      expect(await device.read(key), isNull, reason: key);
    }
    expect(await device.read(AppLocaleController.languageKey), 'th');
  });
}
