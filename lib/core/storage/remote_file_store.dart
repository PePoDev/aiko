import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../firebase/firebase_backend.dart';

/// Firebase Storage as the file sync queue and the attachment viewer use it.
/// Tests replace it.
abstract interface class RemoteFileStore {
  /// Uploads [bytes] to [path], replacing what is there.
  Future<void> put(String path, Uint8List bytes, {required String contentType});

  /// The object at [path], at most [maxBytes] long.
  Future<Uint8List> get(String path, {required int maxBytes});

  /// Deletes the object at [path]; an object that is already gone is fine.
  Future<void> delete(String path);

  /// A download URL for the object at [path].
  Future<String> downloadUrl(String path);

  /// The object path a download URL points at, or null for any other URL.
  String? pathOf(String url);
}

/// Whether [error] is worth retrying later as it is (no connection, a slow
/// network or a token refresh) rather than a rejection that will repeat.
bool isTransientFileError(Object error) {
  if (error is TimeoutException) return true;
  if (error is FirebaseException) {
    return const {
      'retry-limit-exceeded',
      'unknown',
      'canceled',
      'unauthenticated',
      'quota-exceeded',
      'unavailable',
      'deadline-exceeded',
      'network-request-failed',
    }.contains(error.code);
  }
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest');
}

class FirebaseRemoteFileStore implements RemoteFileStore {
  const FirebaseRemoteFileStore();

  /// Storage retries a failed request for 10 minutes (2 for deletes) by
  /// default. Offline, that held Save, the viewer and the upload queue for
  /// minutes; one attempt now gives up after these and the queue tries again
  /// later.
  static const uploadRetryTime = Duration(seconds: 30);
  static const downloadRetryTime = Duration(seconds: 15);
  static const operationRetryTime = Duration(seconds: 15);

  /// Bound on one download, however slow the connection.
  static const downloadTimeout = Duration(seconds: 60);

  static void configureRetries(FirebaseStorage storage) {
    storage
      ..setMaxUploadRetryTime(uploadRetryTime)
      ..setMaxDownloadRetryTime(downloadRetryTime)
      ..setMaxOperationRetryTime(operationRetryTime);
  }

  FirebaseStorage get _storage => FirebaseBackend.storage;

  @override
  Future<void> put(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    await _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
  }

  @override
  Future<Uint8List> get(String path, {required int maxBytes}) async {
    final bytes = await _storage
        .ref(path)
        .getData(maxBytes)
        .timeout(downloadTimeout);
    if (bytes == null) throw StateError('The file is unavailable.');
    return bytes;
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<String> downloadUrl(String path) =>
      _storage.ref(path).getDownloadURL();

  @override
  String? pathOf(String url) {
    try {
      return _storage.refFromURL(url).fullPath;
    } catch (_) {
      return null;
    }
  }
}
