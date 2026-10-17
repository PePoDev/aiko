import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../domain/account.dart';

class AccountRepository {
  const AccountRepository({
    OfflineStore? store,
    OfflineUserContext? userContext,
  }) : _storeOverride = store,
       _userContextOverride = userContext;

  final OfflineStore? _storeOverride;
  final OfflineUserContext? _userContextOverride;

  OfflineStore get _store => _storeOverride ?? OfflineStore();
  OfflineUserContext get _userContext =>
      _userContextOverride ?? OfflineUserContext();

  Future<List<Account>> list() async {
    final userId = await _userContext.resolveUserId();
    final accounts = await _store.get<OfflineAccount>(
      query: RecordQuery(ownerId: userId, orderBy: 'name'),
    );

    return accounts
        .map((account) => account.toDomain())
        .toList(growable: false);
  }

  /// Saves [account] for the current user. With a [batch], the write is
  /// staged there for the caller to commit instead.
  Future<Account> save(Account account, {RecordBatch? batch}) async {
    final userId = await _userContext.resolveUserId();
    final record = account.toOffline(userId: userId);
    if (batch != null) {
      batch.upsert(record);
    } else {
      await _store.upsert(record);
    }
    return record.toDomain();
  }

  Future<void> archive(String id) async {
    final userId = await _userContext.resolveUserId();
    final accounts = await _store.get<OfflineAccount>(
      query: RecordQuery(ownerId: userId, id: id, limit: 1),
    );
    if (accounts.isEmpty) {
      return;
    }
    final account = accounts.first.toDomain();
    await save(account.copyWith(isActive: false));
  }

  /// Deletes the current user's account [id]. With a [batch], the delete is
  /// staged there for the caller to commit instead.
  Future<void> delete(String id, {RecordBatch? batch}) async {
    final userId = await _userContext.resolveUserId();
    final target = batch ?? RecordBatch();
    target.deleteById<OfflineAccount>(id, ownerId: userId);
    if (batch == null) await _store.commit(target);
  }
}
