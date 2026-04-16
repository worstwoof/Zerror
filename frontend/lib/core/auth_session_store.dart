import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

class AuthSessionStore {
  AuthSessionStore._(this._preferences);

  static const String _storageKey = 'auth_session_v1';

  final SharedPreferences _preferences;
  AuthSession? _currentSession;

  AuthSession? get currentSession => _currentSession;

  static Future<AuthSessionStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return AuthSessionStore._(preferences);
  }

  Future<AuthSession?> loadSession() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _currentSession = null;
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _currentSession = null;
        return null;
      }
      final session = AuthSession.fromJson(decoded);
      if (session.token.isEmpty || session.syncUserId.isEmpty || session.isExpired) {
        await clear();
        return null;
      }
      _currentSession = session;
      return session;
    } catch (_) {
      _currentSession = null;
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) async {
    _currentSession = session;
    await _preferences.setString(_storageKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    _currentSession = null;
    await _preferences.remove(_storageKey);
  }
}
