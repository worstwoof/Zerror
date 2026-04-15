import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'app_repository.dart';

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
  })  : _repository = repository,
        _errors = _restoreErrors(snapshot),
        _profile = snapshot?.profile ?? _defaultProfile,
        _avatarPath = snapshot?.avatarPath,
        _passwordUpdatedAt = snapshot?.passwordUpdatedAt ??
            DateTime.now().subtract(const Duration(days: 7)),
        _devices = snapshot != null && snapshot.devices.isNotEmpty
            ? snapshot.devices.toList(growable: true)
            : _seedDevices();

  static const UserProfileData _defaultProfile = UserProfileData(
    name: 'Zander',
    userId: 'zerror_001',
    motto: '让错误再次发芽，让理解长出来',
    email: 'zander@example.com',
  );

  final AppRepository? _repository;
  final List<ErrorRecord> _errors;
  UserProfileData _profile;
  String? _avatarPath;
  DateTime _passwordUpdatedAt;
  List<DeviceSession> _devices;

  static Future<AppStore> bootstrap(AppRepository repository) async {
    AppPersistenceSnapshot? snapshot;
    try {
      snapshot = await repository.loadSnapshot();
    } catch (error) {
      debugPrint('Snapshot bootstrap failed: $error');
    }
    final store = AppStore.seeded(repository: repository, snapshot: snapshot);
    if (snapshot == null || snapshot.errors.isEmpty) {
      unawaited(store._persist());
    }
    return store;
  }

  static List<ErrorRecord> _seedErrors() {
    return const [
      ErrorRecord(
        id: 'linear-eigen',
        subject: '线性代数',
        topic: '矩阵特征值与相似对角化',
        question: '已知矩阵 A 的特征值为 λ1、λ2、λ3，且 A 可逆。证明伴随矩阵 A* 的特征值为 |A|/λi。',
        reason: '概念联系还不够牢',
        dateLabel: '今天 14:30',
        tags: ['线性代数', '特征值', '一轮复习'],
        myAnswer: '我知道 A* 和 A^-1 有关系，但没有把特征值变换这一步写清楚。',
        aiAnalysis: '先写出 A* = |A|A^-1。因为 A^-1 的特征值是 1/λi，所以 A* 的特征值就是 |A|/λi。',
      ),
      ErrorRecord(
        id: 'graph-euler',
        subject: '离散数学',
        topic: '欧拉回路判定',
        question: '无向连通图存在欧拉回路的充要条件是什么？',
        reason: '定义记混了',
        dateLabel: '今天 10:12',
        tags: ['离散数学', '图论', '二轮复习'],
        myAnswer: '我记得和点的度数有关，但容易和欧拉路径混在一起。',
        aiAnalysis: '无向连通图存在欧拉回路，当且仅当图连通且所有顶点度数都为偶数。',
      ),
      ErrorRecord(
        id: 'kmp-next',
        subject: '数据结构',
        topic: 'KMP next 数组构造',
        question: 'KMP 中 next 数组的含义是什么，构造时为什么可以在失配后跳转？',
        reason: '边界条件总漏看',
        dateLabel: '昨天 20:15',
        tags: ['数据结构', 'KMP', '算法实现'],
        myAnswer: '我知道是在比前后缀，但一写代码就容易在 i、j 的变化上出错。',
        aiAnalysis: 'next 数组保存的是最长相等前后缀长度，失配后会跳到对应前缀位置继续比较。',
      ),
      ErrorRecord(
        id: 'java-strategy',
        subject: 'Java',
        topic: '策略模式与接口抽象',
        question: '如何通过接口统一管理不同的业务策略，并避免条件分支不断膨胀？',
        reason: '思路中途断开',
        dateLabel: '4 月 6 日',
        tags: ['Java', '设计模式', '接口抽象'],
        myAnswer: '我知道应该上接口，但没把上下文类和策略实现拆清楚。',
        aiAnalysis: '把共同行为抽成策略接口，再由具体实现负责不同规则，调用方只依赖接口即可扩展。',
      ),
      ErrorRecord(
        id: 'function-extreme',
        subject: '高等数学',
        topic: '二次函数最值',
        question: '已知顶点坐标和定义域时，如何快速判断二次函数最值所在的位置？',
        reason: '边界条件漏检',
        dateLabel: '4 月 5 日',
        tags: ['高等数学', '函数', '最值'],
        myAnswer: '我先找了顶点，但忘了回去检查定义域的边界点。',
        aiAnalysis: '这类题先看开口方向和顶点位置，再结合定义域检查边界点，很多失分都发生在最后一步。',
      ),
      ErrorRecord(
        id: 'politics-history',
        subject: '考研政治',
        topic: '近代史时间线梳理',
        question: '如何快速区分几次重要会议在近代史时间线中的先后顺序？',
        reason: '记忆链条断点太多',
        dateLabel: '4 月 4 日',
        tags: ['考研政治', '时间线', '记忆卡'],
        myAnswer: '单个事件我能记住，但一连起来就会前后颠倒。',
        aiAnalysis: '先抓关键年份，再把会议挂到核心节点上，用时间链代替碎片记忆。',
      ),
      ErrorRecord(
        id: 'probability-bayes',
        subject: '概率论',
        topic: '贝叶斯公式应用',
        question: '遇到条件概率反推原因的题，如何快速判断应该使用贝叶斯公式？',
        reason: '题型识别不够快',
        dateLabel: '4 月 3 日',
        tags: ['概率论', '条件概率', '专项训练'],
        myAnswer: '看到条件概率我知道大概相关，但总拿不准是顺推还是反推。',
        aiAnalysis: '如果题目给的是结果，要求你反推原因，就优先想贝叶斯。先写目标概率，再拆先验和似然。',
      ),
      ErrorRecord(
        id: 'os-scheduling',
        subject: '操作系统',
        topic: '进程调度策略比较',
        question: '时间片轮转和优先级调度在响应时间、吞吐量、公平性上的差异是什么？',
        reason: '对比维度没有搭起来',
        dateLabel: '4 月 2 日',
        tags: ['操作系统', '调度', '系统基础'],
        myAnswer: '我能背定义，但一到优缺点对比就容易混。',
        aiAnalysis: '比较时固定三个维度来记：调度目标、适用场景、潜在问题，会更稳定。',
      ),
    ];
  }

  static List<DeviceSession> _seedDevices() {
    return const [
      DeviceSession(
        id: 'pixel-emulator',
        name: 'Pixel 模拟器',
        detail: 'Android · 上海 · 刚刚活跃',
        isCurrent: true,
        isTrusted: true,
        isOnline: true,
      ),
      DeviceSession(
        id: 'windows-desktop',
        name: 'Windows 桌面端',
        detail: 'Windows · 上次登录于昨天 21:34',
        isCurrent: false,
        isTrusted: true,
        isOnline: true,
      ),
    ];
  }

  static List<ErrorRecord> _restoreErrors(AppPersistenceSnapshot? snapshot) {
    if (snapshot != null && snapshot.errors.isNotEmpty) {
      return snapshot.errors
          .map(ErrorRecord.fromJson)
          .toList(growable: true);
    }
    return _applySnapshot(_seedErrors(), snapshot);
  }

  static List<ErrorRecord> _applySnapshot(
    List<ErrorRecord> seed,
    AppPersistenceSnapshot? snapshot,
  ) {
    if (snapshot == null) return seed.toList(growable: true);
    return seed
        .map(
          (item) => item.copyWith(
            isFavorite: snapshot.favoriteIds.contains(item.id),
            isMastered: snapshot.masteredIds.contains(item.id),
          ),
        )
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

  final List<int> weeklyReviewMinutes = const [18, 32, 24, 40, 28, 16, 36];
  final int studyStreakDays = 14;
  final int invitedCount = 3;
  final int pendingInviteCount = 2;
  final String inviteCode = 'ZERROR-2026';

  String get userName => _profile.name;
  String get userId => _profile.userId;
  String get userMotto => _profile.motto;
  String get userEmail => _profile.email;
  String? get avatarPath => _avatarPath;

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
      _devices.firstWhere((item) => item.isCurrent, orElse: () => _devices.first);

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
  int get unlockedMonths => invitedCount;
  int get completedReviewDaysThisWeek =>
      weeklyCalendar.where((entry) => entry.state == CalendarState.done).length;
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

  void setAvatarPath(String? path) {
    _avatarPath = path;
    _commit();
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
