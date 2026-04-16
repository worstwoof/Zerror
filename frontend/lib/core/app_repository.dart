class UserProfileData {
  const UserProfileData({
    required this.name,
    required this.userId,
    required this.motto,
    required this.email,
  });

  final String name;
  final String userId;
  final String motto;
  final String email;

  UserProfileData copyWith({
    String? name,
    String? userId,
    String? motto,
    String? email,
  }) {
    return UserProfileData(
      name: name ?? this.name,
      userId: userId ?? this.userId,
      motto: motto ?? this.motto,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'user_id': userId,
      'motto': motto,
      'email': email,
    };
  }

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      name: json['name'] as String? ?? '新用户',
      userId: json['user_id'] as String? ?? 'guest',
      motto: json['motto'] as String? ?? '从第一道错题开始，慢慢长出自己的知识树。',
      email: json['email'] as String? ?? '',
    );
  }
}

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.name,
    required this.detail,
    this.isCurrent = false,
    this.isTrusted = true,
    this.isOnline = true,
  });

  final String id;
  final String name;
  final String detail;
  final bool isCurrent;
  final bool isTrusted;
  final bool isOnline;

  String get statusLabel {
    if (isCurrent) return 'Current device';
    if (!isOnline) return 'Signed out';
    return isTrusted ? 'Trusted device' : 'Online device';
  }

  DeviceSession copyWith({
    String? id,
    String? name,
    String? detail,
    bool? isCurrent,
    bool? isTrusted,
    bool? isOnline,
  }) {
    return DeviceSession(
      id: id ?? this.id,
      name: name ?? this.name,
      detail: detail ?? this.detail,
      isCurrent: isCurrent ?? this.isCurrent,
      isTrusted: isTrusted ?? this.isTrusted,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'detail': detail,
      'is_current': isCurrent,
      'is_trusted': isTrusted,
      'is_online': isOnline,
    };
  }

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id'] as String? ?? 'device',
      name: json['name'] as String? ?? 'Unnamed device',
      detail: json['detail'] as String? ?? 'Recently active',
      isCurrent: json['is_current'] as bool? ?? false,
      isTrusted: json['is_trusted'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? true,
    );
  }
}

class AppPersistenceSnapshot {
  const AppPersistenceSnapshot({
    required this.favoriteIds,
    required this.masteredIds,
    this.avatarPath,
    this.profile,
    this.passwordUpdatedAt,
    this.devices = const [],
    this.errors = const [],
  });

  final Set<String> favoriteIds;
  final Set<String> masteredIds;
  final String? avatarPath;
  final UserProfileData? profile;
  final DateTime? passwordUpdatedAt;
  final List<DeviceSession> devices;
  final List<Map<String, dynamic>> errors;

  Map<String, dynamic> toJson() {
    return {
      'favorite_ids': favoriteIds.toList(growable: false),
      'mastered_ids': masteredIds.toList(growable: false),
      'avatar_path': avatarPath,
      'profile': profile?.toJson(),
      'password_updated_at': passwordUpdatedAt?.toIso8601String(),
      'devices': devices.map((item) => item.toJson()).toList(growable: false),
      'errors': errors,
    };
  }

  factory AppPersistenceSnapshot.fromJson(Map<String, dynamic> json) {
    final favoriteList = json['favorite_ids'];
    final masteredList = json['mastered_ids'];
    final profileJson = json['profile'];
    final devicesJson = json['devices'];
    final rawPasswordUpdatedAt = json['password_updated_at'] as String?;

    return AppPersistenceSnapshot(
      favoriteIds: favoriteList is List
          ? favoriteList.whereType<String>().toSet()
          : <String>{},
      masteredIds: masteredList is List
          ? masteredList.whereType<String>().toSet()
          : <String>{},
      avatarPath: json['avatar_path'] as String?,
      profile: profileJson is Map<String, dynamic>
          ? UserProfileData.fromJson(profileJson)
          : profileJson is Map
              ? UserProfileData.fromJson(
                  profileJson.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : null,
      passwordUpdatedAt: rawPasswordUpdatedAt == null
          ? null
          : DateTime.tryParse(rawPasswordUpdatedAt),
      devices: devicesJson is List
          ? devicesJson
              .whereType<Map>()
              .map(
                (item) => DeviceSession.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false)
          : const [],
      errors: _toStringMapList(json['errors']),
    );
  }

  static List<Map<String, dynamic>> _toStringMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => item.map((key, mapValue) => MapEntry(key.toString(), mapValue)))
        .toList(growable: false);
  }
}

abstract class AppRepository {
  Future<AppPersistenceSnapshot?> loadSnapshot();

  Future<void> saveSnapshot(AppPersistenceSnapshot snapshot);
}
