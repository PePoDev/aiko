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
/// from the device (the language stays), so the next person to use the app
/// without an account starts afresh.
class GuestPreferences {
  /// [device], [account] and [signedInUserId] default to device storage,
  /// the signed-in user's synced preferences and the Firebase user.
  GuestPreferences({
    SecureStorageService? device,
    SyncedPreferences? account,
    String? Function()? signedInUserId,
  }) : _device = device ?? FlutterSecureStorageService(),
       _account = account ?? SyncedPreferences(),
       _signedInUserId = signedInUserId ?? (() => FirebaseBackend.userId);

  final SecureStorageService _device;
  final SyncedPreferences _account;
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
  /// signed in. The account's own language and trip stay, and so do ones
  /// that can't be read yet (offline, nothing cached); rules, lesson
  /// progress and dismissals are added to the account's. [categoryId] gives
  /// the account's id for a category a guest rule names (default categories
  /// become the account's clones). The device keeps its language (Welcome
  /// and the login screen use it). Never throws: whatever can't be moved
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
    await _step(const [], name: AppLocaleController.languageKey, () async {
      final language = await _device.read(AppLocaleController.languageKey);
      if (language == null) return true;
      final current = await _account.readState(AppLocaleController.languageKey);
      if (current.known && current.value == null) {
        await _account.write(AppLocaleController.languageKey, language);
      }
      return true;
    });
    await _step([travelKey], () async {
      final travel = await _device.read(travelKey);
      if (travel == null || !_hasTrip(travel)) return true;
      final current = await _account.readState(travelKey);
      if (!current.known) return false;
      final trip = current.value;
      if (trip == null || !_hasTrip(trip)) {
        await _account.write(travelKey, travel);
      }
      return true;
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
        return true;
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
        return true;
      },
    );
    await _step(
      [
        NotificationDismissalStore.storageKey,
        NotificationDismissalStore.legacyKey,
      ],
      () async {
        // One write, dropping none of the account's own dismissals.
        await NotificationDismissalStore(
          _account,
        ).addFrom(NotificationDismissalStore(_device));
        return true;
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

  /// Runs one preference's [move] ([name] in logs, else the first of
  /// [keys]); the device copy ([keys]) goes once it has been handed to the
  /// account, unless [move] returns false: it waits for the next try.
  Future<void> _step(
    List<String> keys,
    Future<bool> Function() move, {
    String? name,
  }) async {
    try {
      if (!await move()) return;
      for (final key in keys) {
        await _device.delete(key);
      }
    } catch (error) {
      debugPrint(
        '[auth] guest preference ${name ?? keys.first} not claimed: $error',
      );
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
