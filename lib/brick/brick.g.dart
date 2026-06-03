// ignore: unused_import, unused_shown_name, unnecessary_import
import 'package:brick_core/query.dart';
// ignore: unused_import, unused_shown_name, unnecessary_import
import 'package:brick_sqlite/db.dart';
// ignore: unused_import, unused_shown_name, unnecessary_import
import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
// ignore: unused_import, unused_shown_name, unnecessary_import
import 'package:brick_sqlite/brick_sqlite.dart';
// ignore: unused_import, unused_shown_name, unnecessary_import
import 'package:brick_supabase/brick_supabase.dart';// GENERATED CODE DO NOT EDIT
// ignore: unused_import
import 'dart:convert';
import 'package:brick_sqlite/brick_sqlite.dart' show SqliteModel, SqliteAdapter, SqliteModelDictionary, RuntimeSqliteColumnDefinition, SqliteProvider;
import 'package:brick_supabase/brick_supabase.dart' show SupabaseProvider, SupabaseModel, SupabaseAdapter, SupabaseModelDictionary;
// ignore: unused_import, unused_shown_name
import 'package:brick_offline_first/brick_offline_first.dart' show RuntimeOfflineFirstDefinition;
// ignore: unused_import, unused_shown_name
import 'package:sqflite_common/sqlite_api.dart' show DatabaseExecutor;

import '../brick/models/account.model.dart';
import '../brick/models/budget.model.dart';
import '../brick/models/category.model.dart';
import '../brick/models/goal.model.dart';
import '../brick/models/profile.model.dart';
import '../brick/models/transaction.model.dart';

part 'adapters/offline_account_adapter.g.dart';
part 'adapters/offline_budget_adapter.g.dart';
part 'adapters/offline_category_adapter.g.dart';
part 'adapters/offline_goal_adapter.g.dart';
part 'adapters/offline_profile_adapter.g.dart';
part 'adapters/offline_transaction_adapter.g.dart';

/// Supabase mappings should only be used when initializing a [SupabaseProvider]
final Map<Type, SupabaseAdapter<SupabaseModel>> supabaseMappings = {
  OfflineAccount: OfflineAccountAdapter(),
  OfflineBudget: OfflineBudgetAdapter(),
  OfflineCategory: OfflineCategoryAdapter(),
  OfflineGoal: OfflineGoalAdapter(),
  OfflineProfile: OfflineProfileAdapter(),
  OfflineTransaction: OfflineTransactionAdapter()
};
final supabaseModelDictionary = SupabaseModelDictionary(supabaseMappings);

/// Sqlite mappings should only be used when initializing a [SqliteProvider]
final Map<Type, SqliteAdapter<SqliteModel>> sqliteMappings = {
  OfflineAccount: OfflineAccountAdapter(),
  OfflineBudget: OfflineBudgetAdapter(),
  OfflineCategory: OfflineCategoryAdapter(),
  OfflineGoal: OfflineGoalAdapter(),
  OfflineProfile: OfflineProfileAdapter(),
  OfflineTransaction: OfflineTransactionAdapter()
};
final sqliteModelDictionary = SqliteModelDictionary(sqliteMappings);
