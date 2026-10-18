import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../app/locale_controller.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../../categories/domain/category_defaults.dart';
import '../../dashboard/application/notification_dismissals.dart';
import '../../learning_hub/application/lesson_progress.dart';
import '../../transactions/data/transaction_rule_store.dart';
import '../../transactions/domain/transaction_rule.dart';

/// The preferences used on this device without an account: the language,
/// transaction rules, the travel trip (with its fees), lesson progress and
/// dismissed notifications. Signed out, [SyncedPreferences] keeps them in
/// device storage under their plain keys; signed in, in the account.
///
/// [claim] moves them into the account a guest signs in to and clears them
/// from the device, so the next person to use the app without an account
/// starts afresh.
class GuestPreferences {
  /// [device], [account] and [signedInUserId] default to device storage,
  /// the signed-in user's synced preferences and the Firebase user.
  GuestPreferences({
    SecureStorageService? device,
    SecureStorageService? account,
    String? Function()? signedInUserId,
  }) : _device = device ?? FlutterSecureStorageService(),
       _account = account ?? SyncedPreferences(),
       _signedInUserId = signedInUserId ?? (() => FirebaseBackend.userId);

  final SecureStorageService _device;
  final SecureStorageService _account;
  final String? Function() _signedInUserId;

  /// The travel mode preference (`storedTravelProvider`).
  static const travelKey = 'travel_mode_v1';

  /// The keys of the guest's own data. The language is not among them: it
  /// is also chosen before signing in or continuing without an account.
  static const dataKeys = [
    TransactionRuleStore.storageKey,
    TransactionRuleStore.legacyKey,
    travelKey,
    NotificationDismissalStore.storageKey,
    NotificationDismissalStore.legacyKey,
    LessonProgressStore.storageKey,
    LessonProgressStore.legacyKey,
  ];

  /// Moves this device's preferences into the account [userId], once it is
  /// signed in. The account's own language and trip stay; rules, lesson
  /// progress and dismissals are added to the account's. [categoryId] gives
  /// the account's id for a category a guest rule names (default categories
  /// become the account's clones). Never throws: whatever can't be moved
  /// stays on the device for the next try.
  Future<void> claim(
    String userId, {
    String? Function(String? categoryId)? categoryId,
  }) async {
    if (userId.isEmpty || _signedInUserId() != userId) return;
    final accountCategoryId =
        categoryId ??
        (id) =>
            CategoryDefaults.categoryIdForUser(userId: userId, categoryId: id);
    await _step([AppLocaleController.languageKey], () async {
      final language = await _device.read(AppLocaleController.languageKey);
      if (language == null) return;
      if (await _account.read(AppLocaleController.languageKey) == null) {
        await _account.write(AppLocaleController.languageKey, language);
      }
    });
    await _step([travelKey], () async {
      final travel = await _device.read(travelKey);
      if (travel == null || !_hasTrip(travel)) return;
      final current = await _account.read(travelKey);
      if (current == null || !_hasTrip(current)) {
        await _account.write(travelKey, travel);
      }
    });
    await _step(
      [TransactionRuleStore.storageKey, TransactionRuleStore.legacyKey],
      () async {
        final rules = await TransactionRuleStore(storage: _device).load();
        final account = TransactionRuleStore(storage: _account);
        for (final rule in rules) {
          await account.saveRule(
            rule.copyWith(
              userId: userId,
              targetCategoryId: accountCategoryId(rule.targetCategoryId),
              conditionValue: rule.conditionType == RuleConditionType.category
                  ? accountCategoryId(rule.conditionValue)
                  : null,
            ),
          );
        }
      },
    );
    await _step(
      [LessonProgressStore.storageKey, LessonProgressStore.legacyKey],
      () async {
        final progress = await LessonProgressStore(_device).load();
        final account = LessonProgressStore(_account);
        // Recording keeps the higher level of a lesson.
        for (final MapEntry(:key, :value) in progress.entries) {
          await account.record(key, value);
        }
      },
    );
    await _step(
      [
        NotificationDismissalStore.storageKey,
        NotificationDismissalStore.legacyKey,
      ],
      () async {
        final dismissed = await NotificationDismissalStore(_device).load();
        final account = NotificationDismissalStore(_account);
        for (final id in dismissed) {
          await account.dismiss(id, dismissed);
        }
      },
    );
  }

  /// Deletes the guest's data preferences from this device ([dataKeys]).
  Future<void> clear() async {
    for (final key in dataKeys) {
      try {
        await _device.delete(key);
      } catch (error) {
        debugPrint('[auth] clearing $key failed: $error');
      }
    }
  }

  /// Runs one preference's [move]; the device copy ([keys]) goes once it
  /// has been handed to the account.
  Future<void> _step(List<String> keys, Future<void> Function() move) async {
    try {
      await move();
      for (final key in keys) {
        await _device.delete(key);
      }
    } catch (error) {
      debugPrint('[auth] guest preference ${keys.first} not claimed: $error');
    }
  }

  static bool _hasTrip(String raw) {
    try {
      final data = jsonDecode(raw);
      return data is Map && data['trip'] != null;
    } catch (_) {
      return false;
    }
  }
}
