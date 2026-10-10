import '../features/travel_mode/application/travel_mode_provider.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_backend.dart';
import '../core/offline/firestore_sync_state.dart';
import '../core/offline/offline_store.dart';
import '../features/investments/application/investments_provider.dart';
import '../features/transactions/data/transaction_rule_store.dart';
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

/// A single collection listener per signed-in app, shared by every screen.
/// Firestore emits local writes, remote edits and deletes, and reconnects itself.
/// While a listener is live, repository reads of its collection come from the
/// SDK cache it keeps current ([FirestoreSyncState]), so they are not billed.
final firebaseSyncProvider = Provider<void>((ref) {
  final sync = FirestoreSyncState.instance;
  final subscriptions = <StreamSubscription>[];
  final timers = <String, Timer>{};
  var disposed = false;
  var generation = 0;
  final refresh = <String, void Function()>{
    'profiles': () => ref.invalidate(profileProvider),
    'accounts': () => ref.invalidate(accountsProvider),
    'categories': () => ref.invalidate(categoriesProvider),
    'category_groups': () => ref.invalidate(categoryGroupsProvider),
    'transactions': () => ref.invalidate(transactionsProvider),
    'investment_holdings': () => ref.invalidate(investmentsProvider),
    'preferences': () {
      ref.invalidate(transactionRulesProvider);
      ref.invalidate(storedTravelProvider);
      ref.invalidate(appLocaleControllerProvider);
    },
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
    if (disposed || currentGeneration != generation) return;
    if (user == null) {
      sync.stopListening();
    } else {
      sync.beginListening(user.uid, refresh.keys);
    }
    if (userChanged) {
      for (final callback in refresh.values) {
        callback();
      }
      invalidateUserSessionState(ref.invalidate);
    }
    if (user == null) return;
    for (final entry in refresh.entries) {
      var initial = true;
      subscriptions.add(
        FirebaseBackend.collection(entry.key)
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snapshot) {
                final first = initial;
                initial = false;
                if (!snapshot.metadata.isFromCache) {
                  sync.markServerSynced(entry.key);
                }
                // Readers waiting on this listener load the initial snapshot
                // themselves, and metadata-only events change no data.
                if (first || snapshot.docChanges.isEmpty) return;
                timers[entry.key]?.cancel();
                timers[entry.key] = Timer(
                  const Duration(milliseconds: 150),
                  () {
                    if (!disposed && !FirebaseSyncPause.isPaused) {
                      entry.value();
                    }
                  },
                );
              },
              onError: (Object error) {
                sync.markListenerFailed(entry.key);
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
