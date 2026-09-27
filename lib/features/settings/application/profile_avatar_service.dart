import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/storage/local_file_cache.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/offline/offline_user_context.dart';
import '../../../core/firebase/firebase_backend.dart';

/// Result of picking a new avatar: the local cache path is always populated
/// so the UI can render instantly, and the cloud URL is populated when the
/// upload to Firebase Storage succeeded.
class ProfileAvatar {
  const ProfileAvatar({required this.localPath, this.cloudUrl});

  final String localPath;
  final String? cloudUrl;
}

class ProfileAvatarService {
  ProfileAvatarService();

  final ImagePicker _picker = ImagePicker();

  /// Open the platform camera/gallery picker, persist the chosen image to
  /// the app's documents directory, then attempt to upload it to the
  /// `avatars` Firebase Storage bucket. Returns `null` when the user
  /// cancelled the picker. Throws when the local write fails; cloud
  /// upload failures are swallowed and the avatar still works offline.
  Future<ProfileAvatar?> pickAndUpload({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (picked == null) {
      return null;
    }

    final bytes = await picked.readAsBytes();
    final ext = _extensionFor(picked.name);
    final userId = await OfflineUserContext().resolveUserId();
    final localPath = await _writeToCache(userId, ext, bytes);

    final cloudUrl = await _uploadToStorage(userId, ext, bytes);

    return ProfileAvatar(localPath: localPath, cloudUrl: cloudUrl);
  }

  /// Best-effort delete of the cached file. Safe to call with `null` or a
  /// path that no longer exists.
  Future<void> removeFromCache(String? localPath) async {
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    await LocalFileCache.remove(localPath);
  }

  Future<String> _writeToCache(String userId, String ext, List<int> bytes) =>
      LocalFileCache.write('avatars/$userId.$ext', bytes);

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
