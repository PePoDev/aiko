import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/synced_preferences.dart';
import '../domain/transaction_rule.dart';

/// Persists the user's [TransactionRule]s as a synced preference, one item per
/// rule (JSON by rule id), so rules added or changed on two devices while
/// offline all survive. Empty until rules are created. Kept out of the record
/// store on purpose — these are small user preferences synchronized by
/// Firebase.
class TransactionRuleStore {
  const TransactionRuleStore({required this.storage});

  final SecureStorageService storage;

  /// The itemized preference (one item per rule id).
  static const storageKey = 'transaction_rules_v2';

  /// The earlier single JSON list, read until the items are first written.
  static const legacyKey = 'transaction_rules_v1';

  ItemizedPreference get _preference => ItemizedPreference(
    storage,
    key: storageKey,
    legacyKey: legacyKey,
    legacyItems: _legacyItems,
  );

  /// Every stored rule by ascending priority; empty when none can be read.
  Future<List<TransactionRule>> load() async {
    try {
      return _rulesOf(await _preference.read());
    } catch (_) {
      return const [];
    }
  }

  /// Adds [rule], or replaces the stored rule with its id.
  Future<void> saveRule(TransactionRule rule) =>
      _preference.write({rule.id: jsonEncode(rule.toJson())});

  /// Removes the rule with [id].
  Future<void> deleteRule(String id) => _preference.write({id: null});

  /// [rules] with [edits] applied (a rule replaces or adds the one with its
  /// id; null removes it), by ascending priority.
  static List<TransactionRule> withEdits(
    List<TransactionRule> rules,
    Map<String, TransactionRule?> edits,
  ) {
    final byId = {for (final rule in rules) rule.id: rule};
    for (final MapEntry(:key, :value) in edits.entries) {
      if (value == null) {
        byId.remove(key);
      } else {
        byId[key] = value;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  static List<TransactionRule> _rulesOf(Map<String, String> items) {
    final rules = <TransactionRule>[];
    for (final value in items.values) {
      try {
        rules.add(
          TransactionRule.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ),
        );
      } catch (_) {
        // An unreadable rule (e.g. from a newer app version) is skipped.
      }
    }
    return rules..sort((a, b) => a.priority.compareTo(b.priority));
  }

  static Map<String, String> _legacyItems(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return {
      for (final item in decoded)
        if (item is Map && item['id'] is String)
          item['id'] as String: jsonEncode(item),
    };
  }
}

/// Active matching rules, sourced from synced preferences. Returns an empty
/// list (never an error) so callers can apply it unconditionally.
final transactionRulesProvider = FutureProvider<List<TransactionRule>>(
  (ref) => TransactionRuleStore(storage: SyncedPreferences()).load(),
  retry: (_, _) => null,
);
