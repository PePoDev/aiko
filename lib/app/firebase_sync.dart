import '../features/travel_mode/application/travel_mode_provider.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../core/firebase/firebase_backend.dart';
import '../core/notifications/transaction_reminder_service.dart';
import '../core/offline/firestore_sync_state.dart';
import '../core/offline/offline_store.dart';
import '../core/offline/records/records.dart';
import '../features/dashboard/application/notification_dismissals.dart';
import '../features/investments/application/investments_provider.dart';
import '../features/learning_hub/application/lesson_progress.dart';
import '../features/transactions/data/transaction_rule_store.dart';
import '../features/transactions/domain/transaction.dart';
import 'locale_controller.dart';
import 'providers.dart';
import 'user_session.dart';

/// Holds back collection-change refreshes while an operation rewrites the
/// user's data wholesale. Deleting the account removes every document; a
/// refresh in the middle would re-read the profile and could write it back.
class FirebaseSyncPause {
  FirebaseSyncPause._();

  static var _holds = 0;

  static bool get isPaused => _holds > 0;

  /// Runs [action] with refreshes paused. Changes made meanwhile are not
  /// replayed; the sign-out that follows reloads everything anyway.
  static Future<T> during<T>(Future<T> Function() action) async {
    _holds++;
    try {
      return await action();
    } finally {
      _holds--;
    }
  }
}

/// Whether an auth event changes whose data the providers hold. The first
/// event repeats the user the app started with (screens have already loaded
/// that user's data), so it changes nothing; later events are sign-ins and
/// sign-outs.
@visibleForTesting
bool authEventChangesUser({
  required bool isFirstEvent,
  required String? startupUid,
  required String? eventUid,
}) => !isFirstEvent || eventUid != startupUid;

/// The providers built from each synced preference document, by document id.
Map<String, ProviderOrFamily> get _preferenceProviders => {
  AppLocaleController.languageKey: appLocaleControllerProvider,
  TransactionRuleStore.storageKey: transactionRulesProvider,
  TransactionRuleStore.legacyKey: transactionRulesProvider,
  'travel_mode_v1': storedTravelProvider,
  NotificationDismissalStore.storageKey: notificationDismissalsProvider,
  NotificationDismissalStore.legacyKey: notificationDismissalsProvider,
  LessonProgressStore.storageKey: lessonProgressProvider,
  LessonProgressStore.legacyKey: lessonProgressProvider,
};

/// The providers to reload after the preference documents [changedIds]
/// changed: only the ones built from them, so dismissing a notification
/// doesn't reload the language. Every preference provider when [changedIds]
/// is null (unknown) or names a document none of them is known to read.
@visibleForTesting
Set<ProviderOrFamily> preferenceProvidersToRefresh(Set<String>? changedIds) {
  final byId = _preferenceProviders;
  if (changedIds == null || !changedIds.every(byId.containsKey)) {
    return byId.values.toSet();
  }
  return {for (final id in changedIds) byId[id]!};
}

/// A single collection listener per signed-in app, shared by every screen.
/// Firestore emits local writes, remote edits and deletes, and reconnects itself.
/// While a listener is live, repository reads of its collection come from the
/// SDK cache it keeps current ([FirestoreSyncState]), so they are not billed.
/// The listeners also report what waits to upload (snapshot metadata, which
/// is not billed), and keep this device's reminders in step with
/// transactions changed elsewhere.
final firebaseSyncProvider = Provider<void>((ref) {
  final sync = FirestoreSyncState.instance;
  final subscriptions = <StreamSubscription>[];
  final timers = <String, Timer>{};
  // Documents changed since the last refresh, per collection; collections in
  // [refreshAll] reload everything.
  final changedIds = <String, Set<String>>{};
  final refreshAll = <String>{};
  var disposed = false;
  var generation = 0;
  void invalidateAll(Iterable<ProviderOrFamily> providers) {
    for (final provider in providers) {
      ref.invalidate(provider);
    }
  }

  final refresh = <String, void Function(Set<String>? changedIds)>{
    'profiles': (_) => ref.invalidate(profileProvider),
    'accounts': (_) => ref.invalidate(accountsProvider),
    'categories': (_) => ref.invalidate(categoriesProvider),
    'category_groups': (_) => ref.invalidate(categoryGroupsProvider),
    'transactions': (_) => ref.invalidate(transactionsProvider),
    'investment_holdings': (_) => ref.invalidate(investmentsProvider),
    'preferences': (ids) => invalidateAll(preferenceProvidersToRefresh(ids)),
  };
  // Register before screens start reading, so their first reads wait for the
  // listeners instead of fetching every collection from the server too.
  final signedInUid = FirebaseBackend.userId;
  if (signedInUid != null) sync.beginListening(signedInUid, refresh.keys);
  var isFirstEvent = true;
  final authSubscription = FirebaseBackend.auth?.authStateChanges().listen((
    user,
  ) async {
    final userChanged = authEventChangesUser(
      isFirstEvent: isFirstEvent,
      startupUid: signedInUid,
      eventUid: user?.uid,
    );
    isFirstEvent = false;
    final currentGeneration = ++generation;
    final previous = subscriptions.toList();
    subscriptions.clear();
    for (final subscription in previous) {
      await subscription.cancel();
    }
    for (final timer in timers.values) {
      timer.cancel();
    }
    timers.clear();
    changedIds.clear();
    refreshAll.clear();
    if (disposed || currentGeneration != generation) return;
    if (user == null) {
      sync.stopListening();
    } else {
      sync.beginListening(user.uid, refresh.keys);
      // Writes queued before this session (an earlier launch, offline) wait
      // to upload too.
      try {
        sync.trackWrite(FirebaseBackend.firestore.waitForPendingWrites());
      } catch (_) {
        // Unsupported: the listeners still report documents with changes.
      }
    }
    if (userChanged) {
      for (final callback in refresh.values) {
        callback(null);
      }
      invalidateUserSessionState(ref.invalidate);
    }
    if (user == null) return;
    // Transactions deleted or edited elsewhere (also while this app was
    // closed: the server snapshot after the cached one lists them) take their
    // reminders on this device with them.
    void followReminders(
      QuerySnapshot<Map<String, dynamic>> snapshot, {
      required bool first,
    }) {
      if (first) return;
      final removed = <String>[];
      final changed = <FinanceTransaction>[];
      for (final change in snapshot.docChanges) {
        // This device's own edits already updated their reminders.
        if (change.doc.metadata.hasPendingWrites) continue;
        switch (change.type) {
          case DocumentChangeType.removed:
            removed.add(change.doc.id);
          case DocumentChangeType.modified:
            final data = change.doc.data();
            if (data == null) continue;
            try {
              changed.add(RecordCodecs.transactions.fromRow(data).toDomain());
            } catch (_) {
              // Unreadable: leave its reminder as it is.
            }
          case DocumentChangeType.added:
            break;
        }
      }
      if (removed.isEmpty && changed.isEmpty) return;
      unawaited(
        TransactionReminderService.instance.followRemoteChanges(
          removedIds: removed,
          changed: changed,
        ),
      );
    }

    for (final entry in refresh.entries) {
      final collection = entry.key;
      var initial = true;
      subscriptions.add(
        FirebaseBackend.collection(collection)
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snapshot) {
                final first = initial;
                initial = false;
                final metadata = snapshot.metadata;
                // True when reads were served before this first snapshot.
                final readAgain = sync.markSnapshot(
                  collection,
                  fromCache: metadata.isFromCache,
                  hasPendingWrites: metadata.hasPendingWrites,
                );
                if (collection == 'transactions') {
                  followReminders(snapshot, first: first);
                }
                // Readers waiting on this listener load the initial snapshot
                // themselves, and metadata-only events change no data.
                if (!readAgain && (first || snapshot.docChanges.isEmpty)) {
                  return;
                }
                if (readAgain) {
                  refreshAll.add(collection);
                } else {
                  changedIds.putIfAbsent(collection, () => {}).addAll([
                    for (final change in snapshot.docChanges) change.doc.id,
                  ]);
                }
                timers[collection]?.cancel();
                timers[collection] = Timer(
                  const Duration(milliseconds: 150),
                  () {
                    final all = refreshAll.remove(collection);
                    final ids = changedIds.remove(collection);
                    if (!disposed && !FirebaseSyncPause.isPaused) {
                      entry.value(all ? null : ids);
                    }
                  },
                );
              },
              onError: (Object error) {
                sync.markListenerFailed(collection);
                OfflineStore.errors.add(error);
              },
            ),
      );
    }
  });
  ref.onDispose(() {
    disposed = true;
    sync.stopListening();
    authSubscription?.cancel();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    for (final timer in timers.values) {
      timer.cancel();
    }
  });
});
