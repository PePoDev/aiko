import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/storage/local_file_cache.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/offline/offline_user_context.dart';
import '../../../core/firebase/firebase_backend.dart';

/// A saved avatar: the local cache path is always populated so the UI can
/// render instantly, and the cloud URL is populated when the upload to
/// Firebase Storage succeeded.
class ProfileAvatar {
  const ProfileAvatar({required this.localPath, this.cloudUrl});

  final String localPath;
  final String? cloudUrl;
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

class ProfileAvatarService {
  ProfileAvatarService({Future<String> Function()? resolveUserId})
    : _resolveUserId = resolveUserId ?? OfflineUserContext().resolveUserId;

  final ImagePicker _picker = ImagePicker();
  final Future<String> Function() _resolveUserId;

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

  /// Makes [pending] the saved avatar: moves it to the user's avatar cache key,
  /// drops [replacedPath] (the previous avatar's cache path) when it differs,
  /// and uploads it to Firebase Storage when signed in. Cloud upload failures
  /// are swallowed and the avatar still works on this device.
  Future<ProfileAvatar> commit(
    PendingAvatar pending, {
    String? replacedPath,
  }) async {
    final userId = await _resolveUserId();
    final localPath = await LocalFileCache.write(
      _avatarKey(userId, pending.extension),
      pending.bytes,
    );
    await LocalFileCache.remove(pending.previewPath);
    if (replacedPath != null && replacedPath != localPath) {
      await removeFromCache(replacedPath);
    }
    final cloudUrl = await _uploadToStorage(
      userId,
      pending.extension,
      pending.bytes,
    );
    return ProfileAvatar(localPath: localPath, cloudUrl: cloudUrl);
  }

  /// Drops a picked photo that was never saved.
  Future<void> discard(PendingAvatar pending) =>
      LocalFileCache.remove(pending.previewPath);

  /// Deletes a saved avatar that the user removed: the cached file and, best
  /// effort, the copy in Firebase Storage.
  Future<void> remove({String? localPath, String? cloudUrl}) async {
    await removeFromCache(localPath);
    if (cloudUrl == null || cloudUrl.isEmpty) return;
    if (FirebaseBackend.userId == null) return;
    try {
      await FirebaseBackend.storage.refFromURL(cloudUrl).delete();
    } catch (error) {
      debugPrint('[aiko] avatar delete failed: $error');
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

  static String _avatarKey(String userId, String ext) => 'avatars/$userId.$ext';

  static String _pendingKey(String userId, String ext) =>
      'avatars/pending/$userId.$ext';

  Future<String?> _uploadToStorage(
    String userId,
    String ext,
    List<int> bytes,
  ) async {
    if (FirebaseBackend.userId == null) return null;
    final objectPath = 'users/$userId/avatars/avatar.$ext';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    try {
      final reference = FirebaseBackend.storage.ref(objectPath);
      await reference.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: contentType),
      );
      return await reference.getDownloadURL();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko] avatar upload failed: $error');
      }
      return null;
    }
  }

  String _extensionFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'jpg';
    return 'jpg';
  }
}
