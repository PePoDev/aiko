import '../core/offline/offline_store.dart';
import '../core/storage/file_sync_queue.dart';
import '../core/storage/local_file_cache.dart';
import '../features/settings/application/profile_avatar_service.dart';
import '../features/transactions/data/transaction_attachment_repository.dart';

/// Starts the background queue that uploads attachments and profile photos,
/// and deletes removed ones, while the user is signed in ([FileSyncQueue]).
/// Returns at once; nothing here waits for the network.
void startFileUploads() {
  TransactionAttachmentRepository().registerUploads();
  ProfileAvatarService().registerUploads();
  final queue = FileSyncQueue.instance;
  // A file that keeps failing to upload is reported like a change the
  // server refused (a snackbar); its job waits for the next launch.
  queue.failures.listen(OfflineStore.errors.add);
  queue.start();
}

/// After [userId]'s account was deleted: forgets their waiting uploads and
/// deletes, the attachments kept on this device for them and the cached
/// copies of their files. Before deleting the account, call
/// [FileSyncQueue.suspend] (and [FileSyncQueue.resume] afterwards) so that
/// no upload runs meanwhile (`AccountFileJobs`). [queue] defaults to the
/// app's.
Future<void> forgetFilesOf(String userId, {FileSyncQueue? queue}) async {
  final jobs = queue ?? FileSyncQueue.instance;
  final db = await LocalFileCache.database();
  await db.transaction((txn) async {
    await TransactionAttachmentRepository().forgetOwner(userId, txn: txn);
    await LocalFileCache.removeUnder('avatars/$userId/', txn: txn);
    await jobs.clearOwner(userId, txn: txn);
  });
  jobs.notifyChanged();
}
