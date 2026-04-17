import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

class RememberedLoginData {
  const RememberedLoginData({
    required this.identifier,
    required this.password,
    required this.rememberPassword,
    required this.autoLogin,
  });

  final String identifier;
  final String password;
  final bool rememberPassword;
  final bool autoLogin;

  bool get hasCredentials => identifier.isNotEmpty && password.isNotEmpty;

  RememberedLoginData copyWith({
    String? identifier,
    String? password,
    bool? rememberPassword,
    bool? autoLogin,
  }) {
    return RememberedLoginData(
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      rememberPassword: rememberPassword ?? this.rememberPassword,
      autoLogin: autoLogin ?? this.autoLogin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'password': password,
      'remember_password': rememberPassword,
      'auto_login': autoLogin,
    };
  }

  factory RememberedLoginData.fromJson(Map<String, dynamic> json) {
    final rememberPassword = json['remember_password'] as bool? ?? false;
    final autoLogin = rememberPassword && (json['auto_login'] as bool? ?? false);
    return RememberedLoginData(
      identifier: (json['identifier'] ?? '').toString(),
      password: rememberPassword ? (json['password'] ?? '').toString() : '',
      rememberPassword: rememberPassword,
      autoLogin: autoLogin,
    );
  }
}

class AuthSessionStore {
  AuthSessionStore._(this._preferences);

  static const String _storageKey = 'auth_session_v1';
  static const String _rememberedLoginKey = 'remembered_login_v1';

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

  Future<void> saveSession(AuthSession session, {bool persist = true}) async {
    _currentSession = session;
    if (persist) {
      await _preferences.setString(_storageKey, jsonEncode(session.toJson()));
      return;
    }
    await _preferences.remove(_storageKey);
  }

  Future<void> clear() async {
    _currentSession = null;
    await _preferences.remove(_storageKey);
  }

  Future<RememberedLoginData?> loadRememberedLogin() async {
    final raw = _preferences.getString(_rememberedLoginKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final remembered = RememberedLoginData.fromJson(decoded);
      if (!remembered.rememberPassword || !remembered.hasCredentials) {
        return null;
      }
      return remembered;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRememberedLogin(RememberedLoginData remembered) async {
    if (!remembered.rememberPassword || !remembered.hasCredentials) {
      await clearRememberedLogin();
      return;
    }

    await _preferences.setString(
      _rememberedLoginKey,
      jsonEncode(remembered.toJson()),
    );
  }

  Future<void> clearRememberedLogin() async {
    await _preferences.remove(_rememberedLoginKey);
  }

  Future<void> disableAutoLogin() async {
    final remembered = await loadRememberedLogin();
    if (remembered == null || !remembered.autoLogin) {
      return;
    }
    await saveRememberedLogin(
      remembered.copyWith(autoLogin: false),
    );
  }
}
