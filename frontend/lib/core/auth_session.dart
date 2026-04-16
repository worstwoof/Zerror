class AuthSession {
  const AuthSession({
    required this.token,
    required this.tokenType,
    required this.expiresAt,
    required this.userId,
    required this.username,
    required this.email,
    required this.syncUserId,
  });

  final String token;
  final String tokenType;
  final DateTime expiresAt;
  final int userId;
  final String username;
  final String email;
  final String syncUserId;

  bool get isExpired => expiresAt.isBefore(DateTime.now().toUtc());

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'token_type': tokenType,
      'expires_at': expiresAt.toIso8601String(),
      'user': {
        'id': userId,
        'username': username,
        'email': email,
        'sync_user_id': syncUserId,
      },
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final user = rawUser is Map<String, dynamic>
        ? rawUser
        : rawUser is Map
            ? rawUser.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : const <String, dynamic>{};

    return AuthSession(
      token: (json['token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      expiresAt:
          DateTime.tryParse((json['expires_at'] ?? '').toString())?.toUtc() ??
              DateTime.now().toUtc(),
      userId: int.tryParse((user['id'] ?? '0').toString()) ?? 0,
      username: (user['username'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      syncUserId: (user['sync_user_id'] ?? '').toString(),
    );
  }
}
