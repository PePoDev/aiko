import '../features/travel_mode/application/travel_mode_provider.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_backend.dart';
import '../core/offline/offline_store.dart';
import '../features/investments/application/investments_provider.dart';
import '../features/transactions/data/transaction_rule_store.dart';
import 'locale_controller.dart';
import 'providers.dart';

/// A single collection listener per signed-in app, shared by every screen.
/// Firestore emits local writes, remote edits and deletes, and reconnects itself.
final firebaseSyncProvider = Provider<void>((ref) {
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
  final authSubscription = FirebaseBackend.auth?.authStateChanges().listen((
    user,
  ) async {
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
    for (final callback in refresh.values) {
      callback();
    }
    if (user == null) return;
    for (final entry in refresh.entries) {
      subscriptions.add(
        FirebaseBackend.collection(entry.key).snapshots().listen((_) {
          timers[entry.key]?.cancel();
          timers[entry.key] = Timer(const Duration(milliseconds: 150), () {
            if (!disposed) entry.value();
          });
        }, onError: (Object error) => OfflineStore.errors.add(error)),
      );
    }
  });
  ref.onDispose(() {
    disposed = true;
    authSubscription?.cancel();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    for (final timer in timers.values) {
      timer.cancel();
    }
  });
});
