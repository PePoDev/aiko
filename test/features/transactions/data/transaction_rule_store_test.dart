import 'dart:convert';

import 'package:aiko/core/offline/firestore_sync_state.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/storage/synced_preferences.dart';
import 'package:aiko/features/transactions/data/transaction_rule_store.dart';
import 'package:aiko/features/transactions/domain/transaction_rule.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionRule _rule(String id, {int priority = 0, bool active = true}) =>
    TransactionRule(
      id: id,
      userId: 'user-1',
      name: 'Rule $id',
      conditionType: RuleConditionType.merchant,
      operator: RuleConditionOperator.contains,
      conditionValue: id,
      targetCategoryId: 'food',
      priority: priority,
      isActive: active,
    );

void main() {
  test(
    'rules are saved and deleted one at a time, sorted by priority',
    () async {
      final store = TransactionRuleStore(storage: MemorySecureStorageService());
      expect(await store.load(), isEmpty);

      await store.saveRule(_rule('b', priority: 2));
      await store.saveRule(_rule('a', priority: 1));
      expect((await store.load()).map((rule) => rule.id), ['a', 'b']);

      await store.saveRule(_rule('b', priority: 2, active: false));
      await store.deleteRule('a');
      final rules = await store.load();
      expect(rules.single.id, 'b');
      expect(rules.single.isActive, isFalse);
    },
  );

  test(
    'the earlier single list is read, and the first save keeps it',
    () async {
      final storage = MemorySecureStorageService();
      await storage.write(
        TransactionRuleStore.legacyKey,
        jsonEncode([_rule('old', priority: 1).toJson()]),
      );
      final store = TransactionRuleStore(storage: storage);
      expect((await store.load()).single.id, 'old');

      await store.saveRule(_rule('new', priority: 2));
      expect((await store.load()).map((rule) => rule.id), ['old', 'new']);
    },
  );

  test('unreadable storage and unreadable rules are skipped', () async {
    final storage = MemorySecureStorageService();
    await storage.write(
      TransactionRuleStore.storageKey,
      jsonEncode({'x': 'not a rule', 'a': jsonEncode(_rule('a').toJson())}),
    );
    expect(
      (await TransactionRuleStore(storage: storage).load()).single.id,
      'a',
    );

    await storage.write(TransactionRuleStore.storageKey, '[oops');
    expect(await TransactionRuleStore(storage: storage).load(), isEmpty);
  });

  test('rules added on two devices while offline both survive, and a load '
      'that failed never wipes them', () async {
    final firestore = FakeFirebaseFirestore();
    TransactionRuleStore device() => TransactionRuleStore(
      storage: SyncedPreferences(
        local: MemorySecureStorageService(),
        firestore: firestore,
        userId: () => 'user-1',
        sync: FirestoreSyncState(firstSnapshotWait: Duration.zero),
      ),
    );

    await device().saveRule(_rule('phone'));
    // The tablet never loaded the phone's rule; it only writes its own.
    await device().saveRule(_rule('tablet'));

    expect(
      (await device().load()).map((rule) => rule.id),
      unorderedEquals(['phone', 'tablet']),
    );
  });

  test('withEdits applies changes made before a load finished', () {
    final loaded = [_rule('a', priority: 1), _rule('b', priority: 2)];

    final shown = TransactionRuleStore.withEdits(loaded, {
      'a': null,
      'c': _rule('c', priority: 0),
      'b': _rule('b', priority: 2, active: false),
    });

    expect(shown.map((rule) => rule.id), ['c', 'b']);
    expect(shown.last.isActive, isFalse);
  });
}
