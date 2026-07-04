import 'package:flutter/foundation.dart';

import 'app_repository.dart';
import 'auth_session_store.dart';
import 'constants.dart';
import 'local_app_repository.dart';
import 'remote_app_repository.dart';

class CloudBackedAppRepository implements AppRepository {
  CloudBackedAppRepository._({
    required LocalAppRepository local,
    required RemoteAppRepository remote,
  })  : _local = local,
        _remote = remote;

  final LocalAppRepository _local;
  final RemoteAppRepository _remote;

  static Future<CloudBackedAppRepository> create(
    AuthSessionStore sessionStore,
  ) async {
    final local = await LocalAppRepository.create(
      snapshotKeyProvider: () => AppConstants.snapshotStorageKey(
        sessionStore.currentSession?.syncUserId,
      ),
    );
    final remote = RemoteAppRepository(sessionStore: sessionStore);
    return CloudBackedAppRepository._(
      local: local,
      remote: remote,
    );
  }

  @override
  Future<AppPersistenceSnapshot?> loadSnapshot() async {
    AppPersistenceSnapshot? localSnapshot;
    try {
      final remoteSnapshot = await _remote.loadSnapshot();
      if (remoteSnapshot != null) {
        localSnapshot = await _local.loadSnapshot();
        final mergedSnapshot = _mergeLocalBackgroundTasks(
          remoteSnapshot,
          localSnapshot,
        );
        await _local.saveSnapshot(mergedSnapshot);
        return mergedSnapshot;
      }
    } catch (error) {
      debugPrint(
        'Cloud snapshot load failed, falling back to local cache: $error',
      );
    }

    localSnapshot ??= await _local.loadSnapshot();
    if (localSnapshot != null) {
      try {
        await _remote.saveSnapshot(_stripLocalBackgroundTasks(localSnapshot));
      } catch (error) {
        debugPrint('Initial cloud sync from local cache failed: $error');
      }
    }
    return localSnapshot;
  }

  @override
  Future<void> saveSnapshot(AppPersistenceSnapshot snapshot) async {
    await _local.saveSnapshot(snapshot);
    await _remote.saveSnapshot(_stripLocalBackgroundTasks(snapshot));
  }

  AppPersistenceSnapshot _mergeLocalBackgroundTasks(
    AppPersistenceSnapshot remote,
    AppPersistenceSnapshot? local,
  ) {
    final localTasks =
        local?.practicePaperTasks ?? const <Map<String, dynamic>>[];
    final localHandoutTasks =
        local?.lectureHandoutTasks ?? const <Map<String, dynamic>>[];
    final localVideoTasks =
        local?.lectureVideoTasks ?? const <Map<String, dynamic>>[];
    final localAssistantChatMessages =
        local?.assistantChatMessages ?? const <Map<String, dynamic>>[];
    if (localTasks.isEmpty &&
        localHandoutTasks.isEmpty &&
        localVideoTasks.isEmpty &&
        localAssistantChatMessages.isEmpty) {
      return remote;
    }
    return AppPersistenceSnapshot(
      favoriteIds: remote.favoriteIds,
      masteredIds: remote.masteredIds,
      avatarPath: remote.avatarPath,
      profile: remote.profile,
      passwordUpdatedAt: remote.passwordUpdatedAt,
      devices: remote.devices,
      errors: remote.errors,
      practicePaperTasks: localTasks,
      lectureHandoutTasks: localHandoutTasks,
      lectureVideoTasks: localVideoTasks,
      assistantChatMessages: localAssistantChatMessages,
    );
  }

  AppPersistenceSnapshot _stripLocalBackgroundTasks(
    AppPersistenceSnapshot snapshot,
  ) {
    return AppPersistenceSnapshot(
      favoriteIds: snapshot.favoriteIds,
      masteredIds: snapshot.masteredIds,
      avatarPath: snapshot.avatarPath,
      profile: snapshot.profile,
      passwordUpdatedAt: snapshot.passwordUpdatedAt,
      devices: snapshot.devices,
      errors: snapshot.errors,
      practicePaperTasks: const [],
      lectureHandoutTasks: const [],
      lectureVideoTasks: const [],
      assistantChatMessages: const [],
    );
  }
}
