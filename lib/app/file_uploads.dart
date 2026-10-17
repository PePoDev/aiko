import '../core/storage/file_sync_queue.dart';
import '../features/settings/application/profile_avatar_service.dart';
import '../features/transactions/data/transaction_attachment_repository.dart';

/// Starts the background queue that uploads attachments and profile photos,
/// and deletes removed ones, while the user is signed in ([FileSyncQueue]).
/// Returns at once; nothing here waits for the network.
void startFileUploads() {
  TransactionAttachmentRepository().registerUploads();
  ProfileAvatarService().registerUploads();
  FileSyncQueue.instance.start();
}
