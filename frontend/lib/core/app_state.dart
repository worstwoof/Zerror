import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'app_repository.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';
import '../data/auth_api_client.dart';

class ErrorRecord {
  const ErrorRecord({
    required this.id,
    required this.subject,
    required this.topic,
    required this.question,
    required this.reason,
    required this.dateLabel,
    required this.tags,
    required this.myAnswer,
    required this.aiAnalysis,
    this.imageUrl,
    this.isMastered = false,
    this.isFavorite = false,
  });

  final String id;
  final String subject;
  final String topic;
  final String question;
  final String reason;
  final String dateLabel;
  final List<String> tags;
  final String myAnswer;
  final String aiAnalysis;
  final String? imageUrl;
  final bool isMastered;
  final bool isFavorite;

  ErrorRecord copyWith({
    bool? isMastered,
    bool? isFavorite,
    String? imageUrl,
  }) {
    return ErrorRecord(
      id: id,
      subject: subject,
      topic: topic,
      question: question,
      reason: reason,
      dateLabel: dateLabel,
      tags: tags,
      myAnswer: myAnswer,
      aiAnalysis: aiAnalysis,
      imageUrl: imageUrl ?? this.imageUrl,
      isMastered: isMastered ?? this.isMastered,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'topic': topic,
      'question': question,
      'reason': reason,
      'date_label': dateLabel,
      'tags': tags,
      'my_answer': myAnswer,
      'ai_analysis': aiAnalysis,
      'image_url': imageUrl,
      'is_mastered': isMastered,
      'is_favorite': isFavorite,
    };
  }

  factory ErrorRecord.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return ErrorRecord(
      id: json['id'] as String? ?? 'error-record',
      subject: json['subject'] as String? ?? 'General',
      topic: json['topic'] as String? ?? 'Review',
      question: json['question'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      dateLabel: json['date_label'] as String? ?? '',
      tags: rawTags is List ? rawTags.whereType<String>().toList(growable: false) : const [],
      myAnswer: json['my_answer'] as String? ?? '',
      aiAnalysis: json['ai_analysis'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      isMastered: json['is_mastered'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }
}

class LearningTask {
  const LearningTask({
    required this.title,
    required this.note,
    required this.durationMinutes,
  });

  final String title;
  final String note;
  final int durationMinutes;
}

class GoalStepData {
  const GoalStepData({
    required this.title,
    required this.progress,
    required this.note,
  });

  final String title;
  final String progress;
  final String note;
}

class NewErrorDraft {
  const NewErrorDraft({
    required this.subject,
    required this.topic,
    required this.question,
    required this.reason,
    required this.tags,
    required this.myAnswer,
    required this.aiAnalysis,
    this.imageUrl,
    this.isFavorite = false,
    this.isMastered = false,
    this.dateLabel,
  });

  final String subject;
  final String topic;
  final String question;
  final String reason;
  final List<String> tags;
  final String myAnswer;
  final String aiAnalysis;
  final String? imageUrl;
  final bool isFavorite;
  final bool isMastered;
  final String? dateLabel;
}

class WeeklyCalendarEntry {
  const WeeklyCalendarEntry({
    required this.weekday,
    required this.dayLabel,
    required this.state,
  });

  final String weekday;
  final String dayLabel;
  final CalendarState state;
}

enum CalendarState { done, review, today, upcoming, rest }

enum ReviewFeedback { forgot, fuzzy, mastered }

class AppStore extends ChangeNotifier {
  AppStore.seeded({
    AppRepository? repository,
    AppPersistenceSnapshot? snapshot,
    AuthSessionStore? sessionStore,
    AuthApiClient? authApiClient,
    AuthSession? session,
  })  : _repository = repository,
        _sessionStore = sessionStore,
        _authApiClient = authApiClient,
        _session = session,
        _errors = _restoreErrors(snapshot),
        _profile = snapshot?.profile ?? _profileFromSession(session) ?? _defaultProfile,
        _avatarPath = snapshot?.avatarPath,
        _passwordUpdatedAt = snapshot?.passwordUpdatedAt ?? DateTime.now(),
        _devices = snapshot != null && snapshot.devices.isNotEmpty
            ? snapshot.devices.toList(growable: true)
            : _defaultDevices(session);

  static const UserProfileData _defaultProfile = UserProfileData(
    name: '新用户',
    userId: 'guest',
    motto: '从第一道错题开始，慢慢长出自己的知识树。',
    email: '',
  );

  final AppRepository? _repository;
  final AuthSessionStore? _sessionStore;
  final AuthApiClient? _authApiClient;
  final List<ErrorRecord> _errors;
  AuthSession? _session;
  UserProfileData _profile;
  String? _avatarPath;
  DateTime _passwordUpdatedAt;
  List<DeviceSession> _devices;

  static Future<AppStore> bootstrap(
    AppRepository repository, {
    required AuthSessionStore sessionStore,
    required AuthApiClient authApiClient,
  }) async {
    final session = await sessionStore.loadSession();
    AppPersistenceSnapshot? snapshot;
    try {
      snapshot = await repository.loadSnapshot();
    } catch (error) {
      debugPrint('Snapshot bootstrap failed: $error');
    }
    final store = AppStore.seeded(
      repository: repository,
      snapshot: snapshot,
      sessionStore: sessionStore,
      authApiClient: authApiClient,
      session: session,
    );
    if (session != null && (snapshot == null || snapshot.errors.isEmpty)) {
      unawaited(store._persist());
    }
    return store;
  }

  static UserProfileData? _profileFromSession(AuthSession? session) {
    if (session == null) return null;
    return UserProfileData(
      name: session.username,
      userId: session.username,
      motto: _defaultProfile.motto,
      email: session.email,
    );
  }

  static List<DeviceSession> _defaultDevices(AuthSession? session) {
    if (session == null) {
      return <DeviceSession>[];
    }
    return [
      DeviceSession(
        id: 'current-${session.syncUserId}',
        name: '当前设备',
        detail: '本次登录设备',
        isCurrent: true,
        isTrusted: true,
        isOnline: true,
      ),
    ];
  }

  static List<ErrorRecord> _restoreErrors(AppPersistenceSnapshot? snapshot) {
    if (snapshot == null || snapshot.errors.isEmpty) {
      return <ErrorRecord>[];
    }
    return snapshot.errors
        .map(ErrorRecord.fromJson)
        .toList(growable: true);
  }

  AppPersistenceSnapshot get snapshot {
    return AppPersistenceSnapshot(
      favoriteIds: favorites.map((item) => item.id).toSet(),
      masteredIds: masteredErrors.map((item) => item.id).toSet(),
      avatarPath: _avatarPath,
      profile: _profile,
      passwordUpdatedAt: _passwordUpdatedAt,
      devices: _devices,
      errors: _errors.map((item) => item.toJson()).toList(growable: false),
    );
  }

  final List<WeeklyCalendarEntry> weeklyCalendar = const [
    WeeklyCalendarEntry(weekday: '一', dayLabel: '7', state: CalendarState.done),
    WeeklyCalendarEntry(weekday: '二', dayLabel: '8', state: CalendarState.done),
    WeeklyCalendarEntry(weekday: '三', dayLabel: '9', state: CalendarState.review),
    WeeklyCalendarEntry(weekday: '四', dayLabel: '10', state: CalendarState.today),
    WeeklyCalendarEntry(weekday: '五', dayLabel: '11', state: CalendarState.upcoming),
    WeeklyCalendarEntry(weekday: '六', dayLabel: '12', state: CalendarState.upcoming),
    WeeklyCalendarEntry(weekday: '日', dayLabel: '13', state: CalendarState.rest),
  ];

  List<int> get weeklyReviewMinutes {
    if (!hasLearningHistory) {
      return List<int>.filled(7, 0, growable: false);
    }
    return const [18, 32, 24, 40, 28, 16, 36];
  }

  String get userName => _profile.name;
  String get userId => _profile.userId;
  String get userMotto => _profile.motto;
  String get userEmail => _profile.email;
  String? get avatarPath => _avatarPath;
  bool get isAuthenticated => _session != null && !(_session?.isExpired ?? true);
  String? get authToken => _session?.token;
  String? get syncUserId => _session?.syncUserId;

  String get passwordUpdatedLabel {
    final days = DateTime.now().difference(_passwordUpdatedAt).inDays;
    if (days <= 0) return '今天';
    if (days == 1) return '1 天前';
    return '$days 天前';
  }

  String get passwordSecurityStatus {
    final days = DateTime.now().difference(_passwordUpdatedAt).inDays;
    if (days >= 30) return '建议更新';
    if (days >= 7) return '正常';
    return '安全';
  }

  String get deviceSecurityStatus =>
      activeDeviceCount > 2 ? '留意' : '正常';

  String get permissionSummary => '相册、相机权限均可控';

  List<String> get securitySuggestions {
    final items = <String>[
      '定期更新登录密码，避免长期使用相同口令。',
      if (onlineOtherDeviceCount > 0) '保留可信设备即可，陌生设备建议及时退出登录。',
      '导出学习数据前，确认当前网络环境安全。',
    ];
    return items;
  }

  UnmodifiableListView<ErrorRecord> get errors => UnmodifiableListView(_errors);
  UnmodifiableListView<DeviceSession> get devices =>
      UnmodifiableListView(_devices);

  DeviceSession get currentDevice =>
      _devices.firstWhere(
        (item) => item.isCurrent,
        orElse: () => _devices.isNotEmpty
            ? _devices.first
            : const DeviceSession(
                id: 'current-device',
                name: '当前设备',
                detail: '本次登录设备',
                isCurrent: true,
                isTrusted: true,
                isOnline: true,
              ),
      );

  int get activeDeviceCount => _devices.where((item) => item.isOnline).length;
  int get onlineOtherDeviceCount =>
      _devices.where((item) => item.isOnline && !item.isCurrent).length;

  List<ErrorRecord> get favorites =>
      _errors.where((item) => item.isFavorite).toList(growable: false);

  List<ErrorRecord> get pendingReviewErrors =>
      _errors.where((item) => !item.isMastered).toList(growable: false);

  List<ErrorRecord> get masteredErrors =>
      _errors.where((item) => item.isMastered).toList(growable: false);

  List<ErrorRecord> get smartReviewQueue =>
      pendingReviewErrors.take(3).toList(growable: false);

  int get totalErrors => _errors.length;
  int get favoriteCount => favorites.length;
  int get pendingReviewCount => pendingReviewErrors.length;
  int get masteredCount => masteredErrors.length;
  int get knowledgePointCount => _errors.map((item) => item.topic).toSet().length;
  int get subjectCount => _errors.map((item) => item.subject).toSet().length;
  bool get hasLearningHistory => totalErrors > 0;
  int get invitedCount => 0;
  int get pendingInviteCount => 0;
  String get inviteCode {
    final raw = (syncUserId ?? userId)
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (raw.isEmpty) {
      return 'ZERROR-NEW';
    }
    final suffix = raw.length > 6 ? raw.substring(0, 6) : raw;
    return 'ZERROR-$suffix';
  }
  int get unlockedMonths => invitedCount;
  int get completedReviewDaysThisWeek =>
      hasLearningHistory ? weeklyCalendar.where((entry) => entry.state == CalendarState.done).length : 0;
  int get studyStreakDays => hasLearningHistory ? completedReviewDaysThisWeek : 0;
  int get todayPlannedMinutes =>
      todayTasks.fold(0, (sum, task) => sum + task.durationMinutes);
  double get masteryRate => totalErrors == 0 ? 0 : masteredCount / totalErrors;

  String get weakestSubject {
    final counts = <String, int>{};
    for (final item in pendingReviewErrors) {
      counts[item.subject] = (counts[item.subject] ?? 0) + 1;
    }
    if (counts.isEmpty) return '暂无';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int get weakestSubjectPendingCount {
    if (weakestSubject == '暂无') return 0;
    return pendingReviewErrors.where((item) => item.subject == weakestSubject).length;
  }

  String get weakestTopic {
    if (weakestSubject == '暂无') return '核心错题回收';
    final counts = <String, int>{};
    for (final item in pendingReviewErrors.where((item) => item.subject == weakestSubject)) {
      counts[item.topic] = (counts[item.topic] ?? 0) + 1;
    }
    if (counts.isEmpty) return '核心错题回收';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int get weakestTopicPendingCount {
    if (weakestSubject == '暂无') return 0;
    return pendingReviewErrors
        .where(
          (item) =>
              item.subject == weakestSubject && item.topic == weakestTopic,
        )
        .length;
  }

  Map<String, int> get subjectDistribution {
    final result = <String, int>{};
    for (final item in _errors) {
      result[item.subject] = (result[item.subject] ?? 0) + 1;
    }
    return result;
  }

  List<String> get subjectOptions =>
      ['全部', ..._errors.map((item) => item.subject).toSet()];

  int get unlockedBadgeCount {
    var count = 0;
    if (totalErrors >= 5) count++;
    if (studyStreakDays >= 7) count++;
    if (favoriteCount >= 3) count++;
    if (masteredCount >= 3) count++;
    if (knowledgePointCount >= 6) count++;
    return count;
  }

  List<LearningTask> get todayTasks {
    if (!hasLearningHistory) {
      return const [];
    }
    final focusSubject = weakestSubject == '暂无' ? '当前重点模块' : weakestSubject;
    return [
      LearningTask(
        title: '智能复习',
        note: '优先回看 ${smartReviewQueue.length} 道近期最容易遗忘的错题',
        durationMinutes: 20,
      ),
      LearningTask(
        title: '攻克薄弱点',
        note: '继续补强 $focusSubject 相关考点',
        durationMinutes: 25,
      ),
      const LearningTask(
        title: '组一套微练习',
        note: '用 5 题小卷快速验证今天的吸收效果',
        durationMinutes: 15,
      ),
    ];
  }

  List<GoalStepData> get goalSteps {
    if (!hasLearningHistory) {
      return const [];
    }
    return [
      GoalStepData(
        title: '每天完成 1 次智能复习',
        progress: '$completedReviewDaysThisWeek / 7',
        note: '再坚持 ${7 - completedReviewDaysThisWeek} 天，就能完成本周基础节奏。',
      ),
      GoalStepData(
        title: '整理高价值收藏卡片',
        progress: '$favoriteCount / 6',
        note: '把反复出错的题型沉淀成自己的复盘模板。',
      ),
      GoalStepData(
        title: '消化待复习错题',
        progress: '$masteredCount / $totalErrors',
        note: '当前还有 $pendingReviewCount 道错题值得继续回收。',
      ),
    ];
  }

  List<ErrorRecord> favoritesBySubject(String subject) {
    if (subject == '全部') return favorites;
    return favorites.where((item) => item.subject == subject).toList(growable: false);
  }

  List<ErrorRecord> errorsBySubject(String subject) {
    if (subject == '全部') return errors.toList(growable: false);
    return _errors.where((item) => item.subject == subject).toList(growable: false);
  }

  ErrorRecord errorById(String id) {
    return _errors.firstWhere((item) => item.id == id);
  }

  ErrorRecord addErrorRecord(NewErrorDraft draft) {
    final record = ErrorRecord(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}-${_errors.length}',
      subject: draft.subject,
      topic: draft.topic,
      question: draft.question,
      reason: draft.reason,
      dateLabel: draft.dateLabel ?? _buildDateLabel(DateTime.now()),
      tags: draft.tags,
      myAnswer: draft.myAnswer,
      aiAnalysis: draft.aiAnalysis,
      imageUrl: draft.imageUrl,
      isFavorite: draft.isFavorite,
      isMastered: draft.isMastered,
    );
    _errors.insert(0, record);
    _commit();
    return record;
  }

  List<ErrorRecord> addErrorRecords(Iterable<NewErrorDraft> drafts) {
    final created = drafts.map(addErrorRecord).toList(growable: false);
    return created;
  }

  void updateProfile({
    required String name,
    required String userId,
    required String motto,
    required String email,
  }) {
    _profile = _profile.copyWith(
      name: name.trim().isEmpty ? _profile.name : name.trim(),
      userId: userId.trim().isEmpty ? _profile.userId : userId.trim(),
      motto: motto.trim().isEmpty ? _profile.motto : motto.trim(),
      email: email.trim().isEmpty ? _profile.email : email.trim(),
    );
    _commit();
  }

  void toggleFavorite(String id) {
    final index = _errors.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = _errors[index];
    _errors[index] = item.copyWith(isFavorite: !item.isFavorite);
    _commit();
  }

  void toggleMastered(String id) {
    final index = _errors.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = _errors[index];
    _errors[index] = item.copyWith(isMastered: !item.isMastered);
    _commit();
  }

  void applyReviewFeedback(String id, ReviewFeedback feedback) {
    final index = _errors.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = _errors[index];
    _errors[index] = item.copyWith(
      isMastered: feedback == ReviewFeedback.mastered,
    );
    _commit();
  }

  void markPasswordUpdated() {
    _passwordUpdatedAt = DateTime.now();
    _commit();
  }

  bool signOutOtherDevices() {
    var changed = false;
    _devices = _devices
        .map((item) {
          if (item.isCurrent || !item.isOnline) return item;
          changed = true;
          return item.copyWith(isOnline: false);
        })
        .toList(growable: true);
    if (changed) {
      _commit();
    }
    return changed;
  }

  Future<void> loginUser({
    required String identifier,
    required String password,
    bool persistSession = true,
    bool rememberPassword = false,
    bool autoLogin = false,
  }) async {
    final client = _authApiClient;
    final sessionStore = _sessionStore;
    if (client == null || sessionStore == null) {
      throw StateError('Authentication is not configured.');
    }

    final session = await client.login(
      identifier: identifier,
      password: password,
    );
    await sessionStore.saveSession(session, persist: persistSession);
    if (rememberPassword) {
      await sessionStore.saveRememberedLogin(
        RememberedLoginData(
          identifier: identifier,
          password: password,
          rememberPassword: true,
          autoLogin: autoLogin,
        ),
      );
    } else {
      await sessionStore.clearRememberedLogin();
    }
    _session = session;
    await _reloadForCurrentSession();
  }

  Future<void> registerUser({
    required String username,
    required String email,
    required String password,
    bool signInAfterRegister = true,
  }) async {
    final client = _authApiClient;
    final sessionStore = _sessionStore;
    if (client == null || sessionStore == null) {
      throw StateError('Authentication is not configured.');
    }

    final session = await client.register(
      username: username,
      email: email,
      password: password,
    );
    if (!signInAfterRegister) {
      return;
    }
    await sessionStore.saveSession(session);
    _session = session;
    await _reloadForCurrentSession();
  }

  Future<void> signOutUser() async {
    final client = _authApiClient;
    final sessionStore = _sessionStore;
    final currentSession = _session;

    if (client != null && currentSession != null && currentSession.token.isNotEmpty) {
      try {
        await client.logout(currentSession.token);
      } catch (error) {
        debugPrint('Sign out request failed: $error');
      }
    }

    await sessionStore?.clear();
    await sessionStore?.disableAutoLogin();
    _session = null;
    _applySnapshotState(null);
    notifyListeners();
    unawaited(_persist());
  }

  Future<RememberedLoginData?> loadRememberedLogin() async {
    return _sessionStore?.loadRememberedLogin();
  }

  Future<bool> tryAutoLogin() async {
    if (isAuthenticated) {
      return true;
    }

    final remembered = await _sessionStore?.loadRememberedLogin();
    if (remembered == null || !remembered.autoLogin || !remembered.hasCredentials) {
      return false;
    }

    try {
      await loginUser(
        identifier: remembered.identifier,
        password: remembered.password,
        persistSession: true,
        rememberPassword: true,
        autoLogin: true,
      );
      return true;
    } catch (error) {
      debugPrint('Auto login failed: $error');
      return false;
    }
  }

  void setAvatarPath(String? path) {
    _avatarPath = path;
    _commit();
  }

  Future<void> _reloadForCurrentSession() async {
    AppPersistenceSnapshot? loadedSnapshot;
    final repository = _repository;

    if (repository != null) {
      try {
        loadedSnapshot = await repository.loadSnapshot();
      } catch (error) {
        debugPrint('Snapshot reload after auth failed: $error');
      }
    }

    _applySnapshotState(loadedSnapshot);
    notifyListeners();

    if (_session != null && (loadedSnapshot == null || loadedSnapshot.errors.isEmpty)) {
      await _persist();
    }
  }

  void _applySnapshotState(AppPersistenceSnapshot? snapshot) {
    _errors
      ..clear()
      ..addAll(_restoreErrors(snapshot));
    _profile = snapshot?.profile ?? _profileFromSession(_session) ?? _defaultProfile;
    _avatarPath = snapshot?.avatarPath;
    _passwordUpdatedAt = snapshot?.passwordUpdatedAt ?? DateTime.now();
    _devices = snapshot != null && snapshot.devices.isNotEmpty
        ? snapshot.devices.toList(growable: true)
        : _defaultDevices(_session);
  }

  void _commit() {
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.saveSnapshot(snapshot);
    } catch (error) {
      debugPrint('Snapshot persistence failed: $error');
    }
  }

  static String _buildDateLabel(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '今天 $hour:$minute';
  }
}

class AppStateScope extends InheritedNotifier<AppStore> {
  const AppStateScope({
    super.key,
    required AppStore notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree.');
    return scope!.notifier!;
  }
}
