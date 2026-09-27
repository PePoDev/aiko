// Maintained codecs: preserve the SQLite schema and decimal strings across platforms.
import 'dart:convert';
import 'package:brick_core/core.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;
import '../core/firebase/firestore_adapter.dart';

import '../brick/models/account.model.dart';
import '../brick/models/category.model.dart';
import '../brick/models/category_group.model.dart';
import '../brick/models/investment_holding.model.dart';
import '../brick/models/profile.model.dart';
import '../brick/models/transaction.model.dart';

part 'adapters/offline_account_adapter.dart';
part 'adapters/offline_category_adapter.dart';
part 'adapters/offline_category_group_adapter.dart';
part 'adapters/offline_investment_holding_adapter.dart';
part 'adapters/offline_profile_adapter.dart';
part 'adapters/offline_transaction_adapter.dart';

final Map<Type, FirestoreAdapter<SqliteModel>> firestoreAdapters = {
  OfflineAccount: OfflineAccountAdapter(),
  OfflineCategory: OfflineCategoryAdapter(),
  OfflineCategoryGroup: OfflineCategoryGroupAdapter(),
  OfflineInvestmentHolding: OfflineInvestmentHoldingAdapter(),
  OfflineProfile: OfflineProfileAdapter(),
  OfflineTransaction: OfflineTransactionAdapter(),
};
final sqliteModelDictionary = SqliteModelDictionary(firestoreAdapters);
