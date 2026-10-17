import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firebase/firebase_backend.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/storage/file_sync_queue.dart';
import '../../../core/storage/local_file_cache.dart';
import '../data/profile_repository.dart';

/// A saved avatar on this device. Each save gets its own cache path, so
/// another device that cached an earlier photo falls back to the profile's
/// URL instead of showing its stale copy.
class ProfileAvatar {
  const ProfileAvatar({
    required this.ownerId,
    required this.localPath,
    required this.remotePath,
    required this.contentType,
  });

  final String ownerId;

  /// Cache path, stored as the profile's `avatarPath`.
  final String localPath;

  /// Where [ProfileAvatarService.queueUpload] uploads it in Firebase Storage.
  final String remotePath;
  final String contentType;
}

/// A photo picked on the Profile screen but not saved yet. It is cached under
/// a temporary key for the preview; the saved avatar (cache and cloud) only
/// changes on [ProfileAvatarService.commit], so leaving without saving keeps
/// the old photo.
class PendingAvatar {
  const PendingAvatar({
    required this.previewPath,
    required this.extension,
    required this.bytes,
  });

  /// Cache path of the preview copy, shown as the draft profile's avatar.
  final String previewPath;
  final String extension;
  final Uint8List bytes;
}

/// Profile photos: the bytes in [LocalFileCache], the shared copy in Firebase
/// Storage. Saving never waits for the network: the upload is queued in
/// [FileSyncQueue] and the profile keeps its previous URL (so other devices
/// keep the previous photo) until the new one is uploaded. Removing a photo
/// clears the profile at once and queues deleting the cloud copy.
class ProfileAvatarService {
  /// [resolveUserId], [signedInUserId], [queue] and [profiles] default to the
  /// app's; tests replace them.
  ProfileAvatarService({
    Future<String> Function()? resolveUserId,
    String? Function()? signedInUserId,
    FileSyncQueue? queue,
    ProfileRepository? profiles,
  }) : _resolveUserId = resolveUserId ?? OfflineUserContext().resolveUserId,
       _signedInUserId = signedInUserId ?? (() => FirebaseBackend.userId),
       _queueOverride = queue,
       _profiles = profiles ?? const ProfileRepository();

  final ImagePicker _picker = ImagePicker();
  final Future<String> Function() _resolveUserId;
  final String? Function() _signedInUserId;
  final FileSyncQueue? _queueOverride;
  final ProfileRepository _profiles;

  FileSyncQueue get _queue => _queueOverride ?? FileSyncQueue.instance;

  /// Queue job kind that uploads the saved photo.
  static const uploadKind = 'avatar-upload';

  /// One waiting photo upload per user: a newer photo replaces it.
  static String uploadJobId(String userId) => 'avatar:$userId';

  /// Lets the queue run this service's uploads.
  void registerUploads() => _queue.register(uploadKind, _upload);

  String? get _uid {
    final uid = _signedInUserId();
    return uid == null || uid.isEmpty ? null : uid;
  }

  /// Opens the platform picker and stages the chosen image ([stage]).
  /// Returns `null` when the user cancelled the picker.
  Future<PendingAvatar?> pick({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (picked == null) {
      return null;
    }
    return stage(await picked.readAsBytes(), fileName: picked.name);
  }

  /// Caches [bytes] under the user's temporary avatar key for a preview.
  /// Throws when the local write fails.
  Future<PendingAvatar> stage(
    List<int> bytes, {
    required String fileName,
  }) async {
    final extension = _extensionFor(fileName);
    final userId = await _resolveUserId();
    final previewPath = await LocalFileCache.write(
      _pendingKey(userId, extension),
      bytes,
    );
    return PendingAvatar(
      previewPath: previewPath,
      extension: extension,
      bytes: Uint8List.fromList(bytes),
    );
  }

  /// Makes [pending] the saved avatar on this device: caches it under a new
  /// avatar path and drops the preview and [replacedPath] (the previous
  /// avatar's cache path). Save the profile with [ProfileAvatar.localPath],
  /// keeping its current URL, then call [queueUpload].
  Future<ProfileAvatar> commit(
    PendingAvatar pending, {
    String? replacedPath,
  }) async {
    final userId = await _resolveUserId();
    final name =
        '${DateTime.now().microsecondsSinceEpoch}.${pending.extension}';
    final localPath = await LocalFileCache.write(
      'avatars/$userId/$name',
      pending.bytes,
    );
    await LocalFileCache.remove(pending.previewPath);
    if (replacedPath != null && replacedPath != localPath) {
      await removeFromCache(replacedPath);
    }
    return ProfileAvatar(
      ownerId: userId,
      localPath: localPath,
      remotePath: 'users/$userId/avatars/$name',
      contentType: _contentTypeFor(pending.extension),
    );
  }

  /// Queues uploading [avatar] once the profile was saved with it (signed
  /// in only; a guest's photo stays on the device). When the upload is done
  /// the profile gets the new URL and the previous photo is deleted from
  /// Storage.
  Future<void> queueUpload(ProfileAvatar avatar) async {
    if (_uid != avatar.ownerId) return;
    await _queue.enqueue(
      FileJob(
        id: uploadJobId(avatar.ownerId),
        ownerId: avatar.ownerId,
        kind: uploadKind,
        data: {
          'local_path': avatar.localPath,
          'remote_path': avatar.remotePath,
          'content_type': avatar.contentType,
        },
      ),
    );
  }

  /// Drops a picked photo that was never saved.
  Future<void> discard(PendingAvatar pending) =>
      LocalFileCache.remove(pending.previewPath);

  /// Deletes a saved avatar that the user removed (after the profile was
  /// saved without it): the cached file at once and, signed in, a waiting
  /// upload; deleting the Storage copy at [cloudUrl] is queued.
  Future<void> remove({String? localPath, String? cloudUrl}) async {
    await removeFromCache(localPath);
    final uid = _uid;
    if (uid == null) return;
    await _queue.remove(uploadJobId(uid));
    if (cloudUrl == null || cloudUrl.isEmpty) return;
    final path = _queue.remote.pathOf(cloudUrl);
    if (path != null && path.startsWith('users/$uid/')) {
      await _queue.enqueueDelete(uid, path);
    }
  }

  /// Best-effort delete of the cached file. Safe to call with `null` or a
  /// path that no longer exists.
  Future<void> removeFromCache(String? localPath) async {
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    await LocalFileCache.remove(localPath);
  }

  /// Uploads the saved photo ([uploadKind] job), then points the profile at
  /// it, unless a newer photo or a removal came first.
  Future<void> _upload(FileJob job, FileJobRun run) async {
    final localPath = job.data['local_path'] as String;
    final remotePath = job.data['remote_path'] as String;
    final Uint8List bytes;
    try {
      bytes = await LocalFileCache.read(localPath);
    } catch (_) {
      return; // Replaced or removed since: nothing to upload.
    }
    final remote = _queue.remote;
    await remote.put(
      remotePath,
      bytes,
      contentType: job.data['content_type'] as String,
    );
    final url = await remote.downloadUrl(remotePath);
    final profile = await _profiles.load();
    if (!await run.isCurrent() || profile.avatarPath != localPath) {
      await _queue.enqueueDelete(job.ownerId, remotePath);
      return;
    }
    final previousUrl = profile.avatarUrl;
    if (previousUrl != url) {
      await _profiles.save(profile.copyWith(avatarUrl: () => url));
    }
    final previousPath = previousUrl == null || previousUrl.isEmpty
        ? null
        : remote.pathOf(previousUrl);
    if (previousPath != null &&
        previousPath != remotePath &&
        previousPath.startsWith('users/${job.ownerId}/')) {
      await _queue.enqueueDelete(job.ownerId, previousPath);
    }
  }

  static String _pendingKey(String userId, String ext) =>
      'avatars/pending/$userId.$ext';

  static String _contentTypeFor(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  String _extensionFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'jpg';
    return 'jpg';
  }
}
