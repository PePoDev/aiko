import '../../../core/storage/synced_preferences.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../domain/transaction_rule.dart';

/// Persists the user's [TransactionRule]s as JSON in secure storage. Empty
/// until rules are created. Kept off Brick on purpose — these are small,
/// user preferences synchronized by Firebase.
class TransactionRuleStore {
  const TransactionRuleStore({required this.storage});

  final SecureStorageService storage;
  static const _key = 'transaction_rules_v1';

  Future<List<TransactionRule>> load() async {
    try {
      final raw = await storage.read(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (item) => TransactionRule.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<TransactionRule> rules) async {
    await storage.write(
      _key,
      jsonEncode([for (final rule in rules) rule.toJson()]),
    );
  }
}

/// Active matching rules, sourced from local storage. Returns an empty list
/// (never an error) so callers can apply it unconditionally.
final transactionRulesProvider = FutureProvider<List<TransactionRule>>((
  ref,
) async {
  return TransactionRuleStore(storage: SyncedPreferences()).load();
});
