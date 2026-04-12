import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_repository.dart';

class LocalAppRepository implements AppRepository {
  LocalAppRepository._(this._preferences);

  static const String _snapshotKey = 'app_snapshot_v1';

  final SharedPreferences _preferences;

  static Future<LocalAppRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalAppRepository._(preferences);
  }

  @override
  Future<AppPersistenceSnapshot?> loadSnapshot() async {
    final raw = _preferences.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AppPersistenceSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(AppPersistenceSnapshot snapshot) async {
    await _preferences.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
  }
}
