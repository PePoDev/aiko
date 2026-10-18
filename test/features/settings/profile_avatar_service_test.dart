import 'dart:async';
import 'dart:typed_data';

import 'package:aiko/core/storage/file_sync_queue.dart';
import 'package:aiko/core/storage/local_file_cache.dart';
import 'package:aiko/features/settings/application/profile_avatar_service.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/storage/file_store_harness.dart';

/// The stored profile, in memory.
class _Profiles implements ProfileRepository {
  _Profiles(this.profile);

  Profile profile;
  int saves = 0;

  @override
  Future<Profile> load() async => profile;

  @override
  Future<Profile> save(Profile next) async {
    saves++;
    return profile = next;
  }
}

/// Storage shared with [shared] whose uploads are slower, or wait for
/// [release] when [hold].
class _SlowRemote extends FakeRemoteFileStore {
  _SlowRemote(this.shared, this.putDelay, {this.hold = false});

  final FakeRemoteFileStore shared;
  final Duration putDelay;
  final bool hold;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> put(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    if (!started.isCompleted) started.complete();
    if (hold) await release.future;
    await Future<void>.delayed(putDelay);
    await shared.put(path, bytes, contentType: contentType);
  }

  @override
  Future<void> delete(String path) => shared.delete(path);

  @override
  Future<String> downloadUrl(String path) => shared.downloadUrl(path);

  @override
  String? pathOf(String url) => shared.pathOf(url);
}

const _uid = 'uid-1';
const _oldUrl = 'https://files.test/users/uid-1/avatars/old.jpg';

void main() {
  late Database db;
  late FakeRemoteFileStore remote;
  late FileSyncQueue queue;
  late _Profiles profiles;
  String? signedIn;

  ProfileAvatarService service({String owner = _uid}) => ProfileAvatarService(
    resolveUserId: () async => signedIn ?? owner,
    signedInUserId: () => signedIn,
    queue: queue,
    profiles: profiles,
  )..registerUploads();

  setUp(() async {
    db = await openMemoryFileCache();
    remote = FakeRemoteFileStore();
    signedIn = null;
    queue = testQueue(remote, signedInUserId: () => signedIn);
    profiles = _Profiles(
      const Profile(
        id: _uid,
        displayName: 'Nok',
        email: 'nok@example.com',
        baseCurrency: 'THB',
        country: 'TH',
        securityStatus: SecurityStatus.notConfigured,
      ),
    );
  });

  tearDown(() async {
    await queue.dispose();
    await closeMemoryFileCache(db);
  });

  /// What the Profile screen does on Save with a new photo.
  Future<ProfileAvatar> saveNewPhoto(
    ProfileAvatarService avatars,
    List<int> bytes,
  ) async {
    final pending = await avatars.stage(bytes, fileName: 'new.jpg');
    final stored = profiles.profile;
    final avatar = await avatars.commit(
      pending,
      replacedPath: stored.avatarPath,
    );
    await profiles.save(stored.copyWith(avatarPath: () => avatar.localPath));
    await avatars.queueUpload(avatar);
    return avatar;
  }

  test('a picked photo leaves the saved avatar alone until commit', () async {
    final avatars = service(owner: 'local:u1');
    final saved = await LocalFileCache.write('avatars/local:u1.jpg', [1, 1]);

    final pending = await avatars.stage([2, 2], fileName: 'new.JPG');

    expect(pending.previewPath, isNot(saved));
    expect(await LocalFileCache.read(saved), [1, 1]);
    expect(await LocalFileCache.read(pending.previewPath), [2, 2]);

    final committed = await avatars.commit(pending, replacedPath: saved);

    expect(committed.localPath, startsWith('aiko-cache:avatars/local:u1/'));
    expect(await LocalFileCache.read(committed.localPath), [2, 2]);
    await expectLater(LocalFileCache.read(saved), throwsStateError);
    await expectLater(
      LocalFileCache.read(pending.previewPath),
      throwsStateError,
    );
    // Not signed in: nothing to upload.
    await avatars.queueUpload(committed);
    expect(await queue.pending(), isEmpty);
  });

  test('every save gets its own cache path', () async {
    final avatars = service(owner: 'local:u1');
    final first = await avatars.commit(
      await avatars.stage([1], fileName: 'a.png'),
    );
    final second = await avatars.commit(
      await avatars.stage([2], fileName: 'b.png'),
      replacedPath: first.localPath,
    );

    expect(second.localPath, isNot(first.localPath));
    expect(second.localPath, endsWith('.png'));
    expect(second.contentType, 'image/png');
    await expectLater(LocalFileCache.read(first.localPath), throwsStateError);
  });

  test('discard removes only the preview', () async {
    final avatars = service(owner: 'local:u1');
    final saved = await LocalFileCache.write('avatars/local:u1.webp', [5]);
    final pending = await avatars.stage([6], fileName: 'x.webp');

    await avatars.discard(pending);

    await expectLater(
      LocalFileCache.read(pending.previewPath),
      throwsStateError,
    );
    expect(await LocalFileCache.read(saved), [5]);
  });

  group('signed in', () {
    setUp(() {
      signedIn = _uid;
      profiles.profile = profiles.profile.copyWith(
        avatarPath: () => 'aiko-cache:avatars/uid-1/old.jpg',
        avatarUrl: () => _oldUrl,
      );
      remote.files['users/uid-1/avatars/old.jpg'] = Uint8List.fromList([0]);
    });

    test('saving keeps the old URL until the upload finishes', () async {
      final avatars = service();
      remote.failure = FakeRemoteFileStore.offline;

      final avatar = await saveNewPhoto(avatars, [3, 3]);
      await queue.process();

      // Offline: the profile shows the new photo here and keeps the old URL.
      expect(profiles.profile.avatarPath, avatar.localPath);
      expect(profiles.profile.avatarUrl, _oldUrl);
      expect(await queue.pendingCount(_uid), 1);

      remote.failure = null;
      await queue.process();
      // The follow-up delete (the queue runs it right after in the app).
      await queue.process();

      expect(remote.files[avatar.remotePath], [3, 3]);
      expect(
        profiles.profile.avatarUrl,
        'https://files.test/${avatar.remotePath}',
      );
      expect(profiles.profile.avatarPath, avatar.localPath);
      // The previous photo is deleted from Storage afterwards.
      expect(remote.files.keys, [avatar.remotePath]);
      expect(await queue.pending(), isEmpty);
    });

    test('a newer photo replaces a waiting upload', () async {
      final avatars = service();
      remote.failure = FakeRemoteFileStore.offline;
      final first = await saveNewPhoto(avatars, [1]);
      final second = await saveNewPhoto(avatars, [2]);

      expect(
        (await queue.pending()).single.data['remote_path'],
        second.remotePath,
      );
      remote.failure = null;
      await queue.process();

      expect(remote.files.containsKey(first.remotePath), isFalse);
      expect(remote.files[second.remotePath], [2]);
      expect(
        profiles.profile.avatarUrl,
        'https://files.test/${second.remotePath}',
      );
    });

    test('removing the photo offline deletes the cloud copy later', () async {
      final avatars = service();
      remote.failure = FakeRemoteFileStore.offline;
      final stored = profiles.profile;
      await profiles.save(
        stored.copyWith(avatarPath: () => null, avatarUrl: () => null),
      );

      await avatars.remove(
        localPath: stored.avatarPath,
        cloudUrl: stored.avatarUrl,
      );
      await queue.process();

      expect(profiles.profile.hasAvatar, isFalse);
      expect(remote.files, isNotEmpty);
      expect(await queue.pendingCount(_uid), 1);

      remote.failure = null;
      await queue.process();
      expect(remote.files, isEmpty);
    });

    test('removing the photo cancels its waiting upload', () async {
      final avatars = service();
      remote.failure = FakeRemoteFileStore.offline;
      final avatar = await saveNewPhoto(avatars, [4]);
      await profiles.save(
        profiles.profile.copyWith(
          avatarPath: () => null,
          avatarUrl: () => null,
        ),
      );

      await avatars.remove(localPath: avatar.localPath, cloudUrl: _oldUrl);
      remote.failure = null;
      await queue.process();

      expect(remote.calls, isNot(contains('put ${avatar.remotePath}')));
      expect(remote.files, isEmpty);
      expect(profiles.profile.avatarUrl, isNull);
    });

    test('two tabs running the same upload never delete the photo the '
        'profile shows', () async {
      // Both tabs share the database; the second one's upload is slower.
      FileSyncQueue tab(Duration putDelay) => FileSyncQueue(
        remote: _SlowRemote(remote, putDelay),
        signedInUserId: () => signedIn,
        retryDelay: (_) => null,
        autoProcess: false,
      );
      final tab1 = tab(Duration.zero);
      final tab2 = tab(const Duration(milliseconds: 50));
      ProfileAvatarService tabService(FileSyncQueue tabQueue) =>
          ProfileAvatarService(
            resolveUserId: () async => _uid,
            signedInUserId: () => signedIn,
            queue: tabQueue,
            profiles: profiles,
          )..registerUploads();
      final avatars = tabService(tab1);
      tabService(tab2);
      remote.failure = FakeRemoteFileStore.offline;
      final avatar = await saveNewPhoto(avatars, [6, 6]);
      remote.failure = null;

      // Back online: both tabs run a pass, then the deletes they queued.
      await Future.wait([tab1.process(), tab2.process()]);
      await tab1.process();
      await tab2.process();

      final url = 'https://files.test/${avatar.remotePath}';
      expect(profiles.profile.avatarUrl, url);
      expect(remote.files.keys, [avatar.remotePath]);
      await tab1.dispose();
      await tab2.dispose();
    });

    test('a sign-out during the upload leaves the profile and the job for '
        'the owner', () async {
      final avatars = service();
      final slow = _SlowRemote(remote, Duration.zero, hold: true);
      final slowQueue = testQueue(slow, signedInUserId: () => signedIn);
      // The same app's uploads, run by a queue whose upload is held.
      ProfileAvatarService(
        resolveUserId: () async => signedIn ?? 'local:guest',
        signedInUserId: () => signedIn,
        queue: slowQueue,
        profiles: profiles,
      ).registerUploads();
      final avatar = await saveNewPhoto(avatars, [7]);

      final pass = slowQueue.process();
      await slow.started.future;
      signedIn = null; // Log out while the photo uploads.
      slow.release.complete();
      await pass;

      expect(profiles.profile.avatarUrl, _oldUrl);
      expect(remote.files.keys, contains(avatar.remotePath));
      final job = (await slowQueue.pending()).single;
      expect(job.kind, ProfileAvatarService.uploadKind);
      expect(job.attempts, 0);

      signedIn = _uid;
      await slowQueue.process();
      await slowQueue.process();
      expect(
        profiles.profile.avatarUrl,
        'https://files.test/${avatar.remotePath}',
      );
      expect(remote.files.keys, [avatar.remotePath]);
      await slowQueue.dispose();
    });

    test('a photo changed during its upload is not linked', () async {
      final avatars = service();
      final avatar = await saveNewPhoto(avatars, [5]);
      // Another save moved the profile on before this upload ran.
      await profiles.save(
        profiles.profile.copyWith(avatarPath: () => 'aiko-cache:other.jpg'),
      );

      await queue.process();
      await queue.process();

      expect(profiles.profile.avatarUrl, _oldUrl);
      expect(remote.files.containsKey(avatar.remotePath), isFalse);
    });
  });
}
