import '../../../brick/offline_model_mappers.dart';
import '../../../brick/repository.dart';
import '../../../brick/models/account.model.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../domain/account.dart';

class AccountRepository {
  const AccountRepository();

  Future<List<Account>> list() async {
    final userId = await OfflineUserContext().resolveUserId();
    final accounts = await OfflineStore().get<OfflineAccount>(
      query: Query(
        where: [Where.exact('userId', userId)],
        orderBy: const [OrderBy.asc('name')],
      ),
    );

    return accounts
        .map((account) => account.toDomain())
        .toList(growable: false);
  }

  Future<Account> save(Account account) async {
    final userId = await OfflineUserContext().resolveUserId();
    final saved = await OfflineStore().upsert(
      account.toOffline(userId: userId),
    );
    return saved.toDomain();
  }

  Future<void> archive(String id) async {
    final userId = await OfflineUserContext().resolveUserId();
    final accounts = await OfflineStore().get<OfflineAccount>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (accounts.isEmpty) {
      return;
    }
    final account = accounts.first.toDomain();
    await save(account.copyWith(isActive: false));
  }

  Future<void> delete(String id) async {
    final userId = await OfflineUserContext().resolveUserId();
    final accounts = await OfflineStore().get<OfflineAccount>(
      query: Query(
        where: [Where.exact('id', id), Where.exact('userId', userId)],
        limit: 1,
      ),
    );
    if (accounts.isEmpty) {
      return;
    }
    await OfflineStore().delete(accounts.first);
  }
}
