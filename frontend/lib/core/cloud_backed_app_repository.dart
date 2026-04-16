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

  static Future<CloudBackedAppRepository> create(AuthSessionStore sessionStore) async {
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
    try {
      final remoteSnapshot = await _remote.loadSnapshot();
      if (remoteSnapshot != null) {
        await _local.saveSnapshot(remoteSnapshot);
        return remoteSnapshot;
      }
    } catch (error) {
      debugPrint('Cloud snapshot load failed, falling back to local cache: $error');
    }

    final localSnapshot = await _local.loadSnapshot();
    if (localSnapshot != null) {
      try {
        await _remote.saveSnapshot(localSnapshot);
      } catch (error) {
        debugPrint('Initial cloud sync from local cache failed: $error');
      }
    }
    return localSnapshot;
  }

  @override
  Future<void> saveSnapshot(AppPersistenceSnapshot snapshot) async {
    await _local.saveSnapshot(snapshot);
    await _remote.saveSnapshot(snapshot);
  }
}
