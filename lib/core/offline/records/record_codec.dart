import 'account_record.dart';
import 'category_group_record.dart';
import 'category_record.dart';
import 'investment_holding_record.dart';
import 'profile_record.dart';
import 'transaction_record.dart';

/// One stored record: a row of a synced collection, kept on the device by the
/// local record store and in Firestore under `users/{uid}/{collection}/{id}`.
abstract interface class OfflineRecord {
  String get id;

  /// The user the record belongs to (`user_id`; a profile's own id). Null
  /// only for system category groups, which are never stored per user.
  String? get ownerId;
}

/// Converts one record type to and from its document row: the exact map
/// stored in Firestore and, as JSON, in the local record store.
abstract class RecordCodec<T extends OfflineRecord> {
  const RecordCodec();

  /// The Firestore collection (and local store collection) name.
  String get collection;

  T fromRow(Map<String, dynamic> row);

  Map<String, dynamic> toRow(T record);

  String idOf(T record) => record.id;

  String? ownerOf(T record) => record.ownerId;
}

/// The codec of every record type.
abstract final class RecordCodecs {
  static const accounts = AccountCodec();
  static const categories = CategoryCodec();
  static const categoryGroups = CategoryGroupCodec();
  static const investmentHoldings = InvestmentHoldingCodec();
  static const profiles = ProfileCodec();
  static const transactions = TransactionCodec();

  static const all = <RecordCodec<OfflineRecord>>[
    accounts,
    categories,
    categoryGroups,
    investmentHoldings,
    profiles,
    transactions,
  ];

  static const _byType = <Type, RecordCodec<OfflineRecord>>{
    OfflineAccount: accounts,
    OfflineCategory: categories,
    OfflineCategoryGroup: categoryGroups,
    OfflineInvestmentHolding: investmentHoldings,
    OfflineProfile: profiles,
    OfflineTransaction: transactions,
  };

  /// The codec for record type [T].
  static RecordCodec<T> of<T extends OfflineRecord>() {
    final codec = _byType[T];
    if (codec == null) {
      throw ArgumentError.value(T, 'T', 'No record codec for this type.');
    }
    return codec as RecordCodec<T>;
  }

  /// The codec for [record]'s runtime type.
  static RecordCodec<OfflineRecord> forRecord(OfflineRecord record) {
    final codec = _byType[record.runtimeType];
    if (codec == null) {
      throw ArgumentError.value(
        record.runtimeType,
        'record',
        'No record codec for this type.',
      );
    }
    return codec;
  }
}

/// Reads an optional ISO-8601 date field of a row.
DateTime? dateFromRow(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw as String);
