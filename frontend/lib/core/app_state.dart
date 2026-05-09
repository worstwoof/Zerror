import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'app_repository.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';
import '../data/ai_api_client.dart';
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
    this.richArtifacts = const [],
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
  final List<Map<String, dynamic>> richArtifacts;
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
      richArtifacts: richArtifacts,
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
      'rich_artifacts': richArtifacts,
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
      tags: rawTags is List
          ? rawTags.whereType<String>().toList(growable: false)
          : const [],
      myAnswer: json['my_answer'] as String? ?? '',
      aiAnalysis: json['ai_analysis'] as String? ?? '',
      richArtifacts: _mapList(json['rich_artifacts']),
      imageUrl: json['image_url'] as String?,
      isMastered: json['is_mastered'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) =>
          item.map((key, mapValue) => MapEntry(key.toString(), mapValue)))
      .toList(growable: false);
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
    this.richArtifacts = const [],
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
  final List<Map<String, dynamic>> richArtifacts;
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

enum AnalysisTaskStatus { queued, analyzing, completed, failed }

typedef AnalysisCompletionNotifier = Future<void> Function({
  required String taskId,
  required String extractedText,
});

typedef AnalysisProgressNotifier = Future<void> Function({
  required String taskId,
  required int progress,
  required String statusMessage,
  required String extractedText,
});

typedef AnalysisFailureNotifier = Future<void> Function({
  required String taskId,
  required String message,
});

typedef AnalysisNotificationCanceller = Future<void> Function(String taskId);

class BackgroundAnalysisTask {
  const BackgroundAnalysisTask({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    required this.status,
    this.serverJobId,
    this.serverJobCreated = false,
    this.progress = 0,
    this.statusMessage,
    this.extractedText = '',
    this.analysis,
    this.errorMessage,
  });

  final String id;
  final String imagePath;
  final DateTime createdAt;
  final AnalysisTaskStatus status;
  final String? serverJobId;
  final bool serverJobCreated;
  final int progress;
  final String? statusMessage;
  final String extractedText;
  final AnalysisResult? analysis;
  final String? errorMessage;

  bool get isActive =>
      status == AnalysisTaskStatus.queued ||
      status == AnalysisTaskStatus.analyzing;
  bool get isCompleted => status == AnalysisTaskStatus.completed;
  bool get isFailed => status == AnalysisTaskStatus.failed;

  BackgroundAnalysisTask copyWith({
    AnalysisTaskStatus? status,
    String? serverJobId,
    bool? serverJobCreated,
    int? progress,
    String? statusMessage,
    String? extractedText,
    AnalysisResult? analysis,
    String? errorMessage,
    bool clearStatusMessage = false,
    bool clearErrorMessage = false,
  }) {
    return BackgroundAnalysisTask(
      id: id,
      imagePath: imagePath,
      createdAt: createdAt,
      status: status ?? this.status,
      serverJobId: serverJobId ?? this.serverJobId,
      serverJobCreated: serverJobCreated ?? this.serverJobCreated,
      progress: progress ?? this.progress,
      statusMessage:
          clearStatusMessage ? null : statusMessage ?? this.statusMessage,
      extractedText: extractedText ?? this.extractedText,
      analysis: analysis ?? this.analysis,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AppStore extends ChangeNotifier {
  static const Duration _analysisPollInterval = Duration(seconds: 3);

  AppStore.seeded({
    AppRepository? repository,
    AppPersistenceSnapshot? snapshot,
    AuthSessionStore? sessionStore,
    AuthApiClient? authApiClient,
    AuthSession? session,
    AnalysisCompletionNotifier? analysisCompletionNotifier,
    AnalysisProgressNotifier? analysisProgressNotifier,
    AnalysisFailureNotifier? analysisFailureNotifier,
    AnalysisNotificationCanceller? analysisNotificationCanceller,
  })  : _repository = repository,
        _sessionStore = sessionStore,
        _authApiClient = authApiClient,
        _analysisCompletionNotifier = analysisCompletionNotifier,
        _analysisProgressNotifier = analysisProgressNotifier,
        _analysisFailureNotifier = analysisFailureNotifier,
        _analysisNotificationCanceller = analysisNotificationCanceller,
        _session = session,
        _errors = _restoreErrors(snapshot),
        _profile = snapshot?.profile ??
            _profileFromSession(session) ??
            _defaultProfile,
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
  final AnalysisCompletionNotifier? _analysisCompletionNotifier;
  final AnalysisProgressNotifier? _analysisProgressNotifier;
  final AnalysisFailureNotifier? _analysisFailureNotifier;
  final AnalysisNotificationCanceller? _analysisNotificationCanceller;
  final AiApiClient _aiApiClient = const AiApiClient();
  final List<ErrorRecord> _errors;
  final List<BackgroundAnalysisTask> _analysisTasks =
      <BackgroundAnalysisTask>[];
  final Set<String> _backgroundedAnalysisTaskIds = <String>{};
  final Set<String> _notifiedCompletedAnalysisTaskIds = <String>{};
  AuthSession? _session;
  UserProfileData _profile;
  String? _avatarPath;
  DateTime _passwordUpdatedAt;
  List<DeviceSession> _devices;
  bool _isAnalysisQueueRunning = false;

  static Future<AppStore> bootstrap(
    AppRepository repository, {
    required AuthSessionStore sessionStore,
    required AuthApiClient authApiClient,
    AnalysisCompletionNotifier? analysisCompletionNotifier,
    AnalysisProgressNotifier? analysisProgressNotifier,
    AnalysisFailureNotifier? analysisFailureNotifier,
    AnalysisNotificationCanceller? analysisNotificationCanceller,
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
      analysisCompletionNotifier: analysisCompletionNotifier,
      analysisProgressNotifier: analysisProgressNotifier,
      analysisFailureNotifier: analysisFailureNotifier,
      analysisNotificationCanceller: analysisNotificationCanceller,
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
    return snapshot.errors.map(ErrorRecord.fromJson).toList(growable: true);
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
    WeeklyCalendarEntry(
        weekday: '三', dayLabel: '9', state: CalendarState.review),
    WeeklyCalendarEntry(
        weekday: '四', dayLabel: '10', state: CalendarState.today),
    WeeklyCalendarEntry(
        weekday: '五', dayLabel: '11', state: CalendarState.upcoming),
    WeeklyCalendarEntry(
        weekday: '六', dayLabel: '12', state: CalendarState.upcoming),
    WeeklyCalendarEntry(
        weekday: '日', dayLabel: '13', state: CalendarState.rest),
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
  bool get isAuthenticated =>
      _session != null && !(_session?.isExpired ?? true);
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

  String get deviceSecurityStatus => activeDeviceCount > 2 ? '留意' : '正常';

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
  UnmodifiableListView<BackgroundAnalysisTask> get analysisTasks =>
      UnmodifiableListView(_analysisTasks);

  DeviceSession get currentDevice => _devices.firstWhere(
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
  int get activeAnalysisTaskCount =>
      _analysisTasks.where((item) => item.isActive).length;
  int get completedAnalysisTaskCount =>
      _analysisTasks.where((item) => item.isCompleted).length;
  int get failedAnalysisTaskCount =>
      _analysisTasks.where((item) => item.isFailed).length;
  bool get hasAnalysisTasks => _analysisTasks.isNotEmpty;

  int analysisTaskQueuePosition(String id) {
    final activeOldestFirst = _analysisTasks
        .where((item) => item.isActive)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    final index = activeOldestFirst.indexWhere((item) => item.id == id);
    return index == -1 ? 0 : index + 1;
  }

  int get knowledgePointCount =>
      _errors.map((item) => item.topic).toSet().length;
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
  int get completedReviewDaysThisWeek => hasLearningHistory
      ? weeklyCalendar
          .where((entry) => entry.state == CalendarState.done)
          .length
      : 0;
  int get studyStreakDays =>
      hasLearningHistory ? completedReviewDaysThisWeek : 0;
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
    return pendingReviewErrors
        .where((item) => item.subject == weakestSubject)
        .length;
  }

  String get weakestTopic {
    if (weakestSubject == '暂无') return '核心错题回收';
    final counts = <String, int>{};
    for (final item in pendingReviewErrors
        .where((item) => item.subject == weakestSubject)) {
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
    return favorites
        .where((item) => item.subject == subject)
        .toList(growable: false);
  }

  List<ErrorRecord> errorsBySubject(String subject) {
    if (subject == '全部') return errors.toList(growable: false);
    return _errors
        .where((item) => item.subject == subject)
        .toList(growable: false);
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
      richArtifacts: draft.richArtifacts,
      imageUrl: draft.imageUrl,
      isFavorite: draft.isFavorite,
      isMastered: draft.isMastered,
    );
    _errors.insert(0, record);
    _commit();
    return record;
  }

  BackgroundAnalysisTask enqueueImageAnalysisTask({
    required String imagePath,
  }) {
    final task = BackgroundAnalysisTask(
      id: 'analysis-${DateTime.now().microsecondsSinceEpoch}-${_analysisTasks.length}',
      imagePath: imagePath,
      createdAt: DateTime.now(),
      status: AnalysisTaskStatus.queued,
    );
    _analysisTasks.insert(0, task);
    notifyListeners();
    unawaited(
      _notifyAnalysisProgress(
        task.copyWith(progress: 1, statusMessage: '已加入后台解析队列'),
      ),
    );
    unawaited(_pumpAnalysisQueue());
    return task;
  }

  void retryAnalysisTask(String id) {
    final index = _analysisTasks.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final retryJobId = '$id-retry-${DateTime.now().microsecondsSinceEpoch}';
    _backgroundedAnalysisTaskIds.remove(id);
    _notifiedCompletedAnalysisTaskIds.remove(id);
    _analysisTasks[index] = _analysisTasks[index].copyWith(
      status: AnalysisTaskStatus.queued,
      serverJobId: retryJobId,
      serverJobCreated: false,
      progress: 0,
      clearStatusMessage: true,
      clearErrorMessage: true,
    );
    notifyListeners();
    unawaited(
      _notifyAnalysisProgress(
        _analysisTasks[index].copyWith(statusMessage: '正在重新提交后台解析任务'),
      ),
    );
    unawaited(_pumpAnalysisQueue());
  }

  void dismissAnalysisTask(
    String id, {
    bool cleanupGeneratedContent = true,
  }) {
    final index = _analysisTasks.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final task = _analysisTasks[index];
    if (cleanupGeneratedContent && task.analysis != null) {
      unawaited(
          _aiApiClient.cleanupManimArtifacts(task.analysis!.richArtifacts));
    }
    _backgroundedAnalysisTaskIds.remove(id);
    _notifiedCompletedAnalysisTaskIds.remove(id);
    _analysisTasks.removeAt(index);
    notifyListeners();
    unawaited(_cancelAnalysisNotification(id));
  }

  void updateAnalysisTaskAnalysis(String id, AnalysisResult analysis) {
    _replaceAnalysisTask(
      id,
      (task) => task.copyWith(
        status: AnalysisTaskStatus.completed,
        analysis: analysis,
        clearErrorMessage: true,
      ),
    );
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
    _devices = _devices.map((item) {
      if (item.isCurrent || !item.isOnline) return item;
      changed = true;
      return item.copyWith(isOnline: false);
    }).toList(growable: true);
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

    if (client != null &&
        currentSession != null &&
        currentSession.token.isNotEmpty) {
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
    _analysisTasks.clear();
    _backgroundedAnalysisTaskIds.clear();
    _notifiedCompletedAnalysisTaskIds.clear();
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
    if (remembered == null ||
        !remembered.autoLogin ||
        !remembered.hasCredentials) {
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

  void updateAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (!isForeground) {
      _backgroundedAnalysisTaskIds.addAll(
        _analysisTasks.where((item) => item.isActive).map((item) => item.id),
      );
    }
    if (isForeground) {
      resumeAnalysisQueue();
    }
  }

  void resumeAnalysisQueue() {
    if (_analysisTasks.any((item) => item.isActive)) {
      unawaited(_pumpAnalysisQueue());
    }
  }

  Future<void> _pumpAnalysisQueue() async {
    if (_isAnalysisQueueRunning) return;

    _isAnalysisQueueRunning = true;
    try {
      while (true) {
        final nextIndex = _analysisTasks.lastIndexWhere(
          (item) => item.isActive,
        );
        if (nextIndex == -1) {
          return;
        }

        final task = _analysisTasks[nextIndex];
        if (task.status == AnalysisTaskStatus.queued ||
            !task.serverJobCreated) {
          await _ensureImageAnalysisJob(task);
        } else {
          await _pollImageAnalysisJob(task);
        }

        if (_analysisTasks.any((item) => item.isActive)) {
          await Future<void>.delayed(_analysisPollInterval);
        }
      }
    } finally {
      _isAnalysisQueueRunning = false;
      if (_analysisTasks.any((item) => item.isActive)) {
        unawaited(_pumpAnalysisQueue());
      }
    }
  }

  Future<void> _ensureImageAnalysisJob(BackgroundAnalysisTask task) async {
    final serverJobId =
        (task.serverJobId == null || task.serverJobId!.trim().isEmpty)
            ? task.id
            : task.serverJobId!.trim();
    final nextProgress = task.progress == 0 ? 5 : task.progress;
    _replaceAnalysisTask(
      task.id,
      (current) => current.copyWith(
        status: AnalysisTaskStatus.analyzing,
        serverJobId: serverJobId,
        progress: current.progress == 0 ? 5 : current.progress,
        statusMessage: '正在提交后台解析任务',
        clearErrorMessage: true,
      ),
    );
    unawaited(
      _notifyAnalysisProgress(
        task.copyWith(
          status: AnalysisTaskStatus.analyzing,
          serverJobId: serverJobId,
          progress: nextProgress,
          statusMessage: '正在提交后台解析任务',
          clearErrorMessage: true,
        ),
      ),
    );

    if (task.serverJobId != null && !task.serverJobCreated) {
      final recovered = await _tryRecoverImageAnalysisJob(task.id, serverJobId);
      if (recovered) {
        return;
      }
    }

    try {
      final job = await _aiApiClient.createImageAnalysisJob(
        imagePath: task.imagePath,
        clientJobId: serverJobId,
        enableSubjectExtensions: true,
      );
      _applyImageAnalysisJob(task.id, job);
    } on AiApiException catch (error) {
      if (_isRecoverableAnalysisError(error)) {
        _markAnalysisTaskRecovering(
          task.id,
          serverJobId: serverJobId,
          serverJobCreated: false,
          error: error,
        );
        return;
      }
      _markAnalysisTaskFailed(task.id, error.message);
    } catch (error) {
      _markAnalysisTaskRecovering(
        task.id,
        serverJobId: serverJobId,
        serverJobCreated: false,
        error: error,
      );
    }
  }

  Future<bool> _tryRecoverImageAnalysisJob(
    String taskId,
    String serverJobId,
  ) async {
    try {
      final job = await _aiApiClient.fetchImageAnalysisJob(serverJobId);
      _applyImageAnalysisJob(taskId, job);
      return true;
    } on AiApiException catch (error) {
      if (error.statusCode == 404) {
        return false;
      }
      if (_isRecoverableAnalysisError(error)) {
        _markAnalysisTaskRecovering(
          taskId,
          serverJobId: serverJobId,
          serverJobCreated: false,
          error: error,
        );
        return true;
      }
      _markAnalysisTaskFailed(taskId, error.message);
      return true;
    } catch (error) {
      _markAnalysisTaskRecovering(
        taskId,
        serverJobId: serverJobId,
        serverJobCreated: false,
        error: error,
      );
      return true;
    }
  }

  Future<void> _pollImageAnalysisJob(BackgroundAnalysisTask task) async {
    final serverJobId = task.serverJobId;
    if (serverJobId == null || serverJobId.trim().isEmpty) {
      _replaceAnalysisTask(
        task.id,
        (current) => current.copyWith(
          status: AnalysisTaskStatus.queued,
          serverJobCreated: false,
        ),
      );
      return;
    }

    try {
      final job = await _aiApiClient.fetchImageAnalysisJob(serverJobId);
      _applyImageAnalysisJob(task.id, job);
    } on AiApiException catch (error) {
      if (error.statusCode == 404) {
        _replaceAnalysisTask(
          task.id,
          (current) => current.copyWith(
            status: AnalysisTaskStatus.queued,
            serverJobCreated: false,
            statusMessage: '后台任务已过期，正在重新提交',
            clearErrorMessage: true,
          ),
        );
        return;
      }
      if (_isRecoverableAnalysisError(error)) {
        _markAnalysisTaskRecovering(
          task.id,
          serverJobId: serverJobId,
          serverJobCreated: true,
          error: error,
        );
        return;
      }
      _markAnalysisTaskFailed(task.id, error.message);
    } catch (error) {
      _markAnalysisTaskRecovering(
        task.id,
        serverJobId: serverJobId,
        serverJobCreated: true,
        error: error,
      );
    }
  }

  void _applyImageAnalysisJob(String taskId, ImageAnalysisJob job) {
    final payload = job.result ?? job.partialResult;
    final extractedText = payload?.extractedText;
    final hasFinalResult = job.status == 'completed' && job.result != null;
    if (hasFinalResult) {
      BackgroundAnalysisTask? completedTask;
      _replaceAnalysisTask(
        taskId,
        (current) {
          completedTask = current.copyWith(
            status: AnalysisTaskStatus.completed,
            serverJobId: job.jobId,
            serverJobCreated: true,
            progress: 100,
            statusMessage: job.displayMessage,
            extractedText: job.result!.extractedText,
            analysis: job.result!.analysis,
            clearErrorMessage: true,
          );
          return completedTask!;
        },
      );
      final taskToNotify = completedTask;
      if (taskToNotify != null && _shouldNotifyAnalysisCompletion(taskId)) {
        unawaited(_notifyAnalysisCompleted(taskToNotify));
      }
      return;
    }

    final hasTerminalError = job.status == 'failed' ||
        job.status == 'need_retry' ||
        (job.status == 'partial_success' && job.error.trim().isNotEmpty);
    if (hasTerminalError) {
      _markAnalysisTaskFailed(
        taskId,
        job.error.trim().isNotEmpty ? job.error : job.displayMessage,
        serverJobId: job.jobId,
        serverJobCreated: true,
        progress: job.progress,
        extractedText: extractedText,
      );
      return;
    }

    BackgroundAnalysisTask? activeTask;
    _replaceAnalysisTask(
      taskId,
      (current) {
        activeTask = current.copyWith(
          status: AnalysisTaskStatus.analyzing,
          serverJobId: job.jobId,
          serverJobCreated: true,
          progress: job.progress,
          statusMessage: job.displayMessage,
          extractedText: extractedText,
          clearErrorMessage: true,
        );
        return activeTask!;
      },
    );
    final taskToNotify = activeTask;
    if (taskToNotify != null) {
      unawaited(_notifyAnalysisProgress(taskToNotify));
    }
  }

  void _markAnalysisTaskRecovering(
    String taskId, {
    required String serverJobId,
    required bool serverJobCreated,
    required Object error,
  }) {
    debugPrint('Image analysis polling will resume: $error');
    BackgroundAnalysisTask? recoveringTask;
    _replaceAnalysisTask(
      taskId,
      (current) {
        recoveringTask = current.copyWith(
          status: AnalysisTaskStatus.analyzing,
          serverJobId: serverJobId,
          serverJobCreated: serverJobCreated,
          progress: current.progress == 0 ? 5 : current.progress,
          statusMessage: '网络切换中，稍后继续检查后台结果',
          clearErrorMessage: true,
        );
        return recoveringTask!;
      },
    );
    final taskToNotify = recoveringTask;
    if (taskToNotify != null) {
      unawaited(_notifyAnalysisProgress(taskToNotify));
    }
  }

  void _markAnalysisTaskFailed(
    String taskId,
    String message, {
    String? serverJobId,
    bool? serverJobCreated,
    int? progress,
    String? extractedText,
  }) {
    BackgroundAnalysisTask? failedTask;
    _replaceAnalysisTask(
      taskId,
      (current) {
        failedTask = current.copyWith(
          status: AnalysisTaskStatus.failed,
          serverJobId: serverJobId,
          serverJobCreated: serverJobCreated,
          progress: progress ?? current.progress,
          extractedText: extractedText,
          errorMessage: message,
        );
        return failedTask!;
      },
    );
    final taskToNotify = failedTask;
    if (taskToNotify != null) {
      unawaited(_notifyAnalysisFailed(taskToNotify));
    }
  }

  bool _shouldNotifyAnalysisCompletion(String taskId) {
    if (_notifiedCompletedAnalysisTaskIds.contains(taskId)) {
      return false;
    }

    _backgroundedAnalysisTaskIds.remove(taskId);
    _notifiedCompletedAnalysisTaskIds.add(taskId);
    return true;
  }

  Future<void> _notifyAnalysisProgress(BackgroundAnalysisTask task) async {
    try {
      await _analysisProgressNotifier?.call(
        taskId: task.id,
        progress: task.progress,
        statusMessage: task.statusMessage ?? '正在整理这道错题',
        extractedText: task.extractedText,
      );
    } catch (error) {
      debugPrint('Analysis progress notifier failed: $error');
    }
  }

  Future<void> _notifyAnalysisCompleted(BackgroundAnalysisTask task) async {
    try {
      await _analysisCompletionNotifier?.call(
        taskId: task.id,
        extractedText: task.extractedText,
      );
    } catch (error) {
      debugPrint('Analysis completion notifier failed: $error');
    }
  }

  Future<void> _notifyAnalysisFailed(BackgroundAnalysisTask task) async {
    try {
      await _analysisFailureNotifier?.call(
        taskId: task.id,
        message: task.errorMessage ?? '这道题暂时没有整理成功，请稍后重试。',
      );
    } catch (error) {
      debugPrint('Analysis failure notifier failed: $error');
    }
  }

  Future<void> _cancelAnalysisNotification(String taskId) async {
    try {
      await _analysisNotificationCanceller?.call(taskId);
    } catch (error) {
      debugPrint('Analysis notification cancel failed: $error');
    }
  }

  bool _isRecoverableAnalysisError(AiApiException error) {
    final statusCode = error.statusCode;
    return statusCode == null ||
        statusCode == 408 ||
        statusCode == 429 ||
        statusCode >= 500;
  }

  void _replaceAnalysisTask(
    String id,
    BackgroundAnalysisTask Function(BackgroundAnalysisTask task) update,
  ) {
    final index = _analysisTasks.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _analysisTasks[index] = update(_analysisTasks[index]);
    notifyListeners();
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

    if (_session != null &&
        (loadedSnapshot == null || loadedSnapshot.errors.isEmpty)) {
      await _persist();
    }
  }

  void _applySnapshotState(AppPersistenceSnapshot? snapshot) {
    _errors
      ..clear()
      ..addAll(_restoreErrors(snapshot));
    _analysisTasks.clear();
    _profile =
        snapshot?.profile ?? _profileFromSession(_session) ?? _defaultProfile;
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
