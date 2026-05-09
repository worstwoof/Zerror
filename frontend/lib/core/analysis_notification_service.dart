import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AnalysisNotificationService {
  static const String _channelId = 'analysis_completion_v1';
  static const String _channelName = '错题整理提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _foregroundServiceActive = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();
    await _requestPermissions();
  }

  Future<void> notifyAnalysisCompleted({
    required String taskId,
    required String extractedText,
  }) async {
    await initialize();
    final summary = _questionSummaryForNotification(extractedText);
    final body =
        summary.isEmpty ? '这道题的讲解已整理好，点开知芽确认入档。' : '$summary\n点开知芽确认入档。';

    try {
      await _stopForegroundServiceIfNeeded();
      await _plugin.show(
        id: taskId.hashCode & 0x7fffffff,
        title: '这道题的讲解已整理好',
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '后台错题整理完成提醒',
            importance: Importance.high,
            priority: Priority.high,
            ticker: '这道题的讲解已整理好',
            category: AndroidNotificationCategory.status,
            visibility: NotificationVisibility.public,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: taskId,
      );
    } catch (error) {
      debugPrint('Analysis completion notification failed: $error');
    }
  }

  Future<void> showAnalysisProgress({
    required String taskId,
    required int progress,
    required String statusMessage,
    required String extractedText,
  }) async {
    await initialize();
    final clampedProgress = progress.clamp(0, 99);
    final message = _polishedProgressMessage(statusMessage);
    final summary = _questionSummaryForNotification(extractedText);
    final body = summary.isEmpty
        ? '$message · $clampedProgress%'
        : '$message · $clampedProgress%\n$summary';

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '后台错题整理进度提醒',
        importance: Importance.high,
        priority: Priority.high,
        ticker: '正在整理这道错题',
        category: AndroidNotificationCategory.progress,
        visibility: NotificationVisibility.public,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: clampedProgress,
      );
      if (android != null) {
        await android.startForegroundService(
          id: taskId.hashCode & 0x7fffffff,
          title: '正在整理这道错题',
          body: body,
          notificationDetails: androidDetails,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeDataSync,
          },
          payload: taskId,
        );
        _foregroundServiceActive = true;
        return;
      }

      await _plugin.show(
        id: taskId.hashCode & 0x7fffffff,
        title: '正在整理这道错题',
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
          ),
          macOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
          ),
        ),
        payload: taskId,
      );
    } catch (error) {
      debugPrint('Analysis progress notification failed: $error');
    }
  }

  Future<void> notifyAnalysisFailed({
    required String taskId,
    required String message,
  }) async {
    await initialize();
    try {
      await _stopForegroundServiceIfNeeded();
      await _plugin.show(
        id: taskId.hashCode & 0x7fffffff,
        title: '这道题需要重新整理',
        body: message.trim().isEmpty
            ? '点开知芽重新整理。'
            : _polishedFailureMessage(message),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '后台错题整理提醒',
            importance: Importance.high,
            priority: Priority.high,
            ticker: '这道题需要重新整理',
            category: AndroidNotificationCategory.status,
            visibility: NotificationVisibility.public,
            enableVibration: true,
            ongoing: false,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: taskId,
      );
    } catch (error) {
      debugPrint('Analysis failure notification failed: $error');
    }
  }

  Future<void> cancelAnalysisNotification(String taskId) async {
    await initialize();
    try {
      await _stopForegroundServiceIfNeeded();
      await _plugin.cancel(id: taskId.hashCode & 0x7fffffff);
    } catch (error) {
      debugPrint('Analysis notification cancel failed: $error');
    }
  }

  Future<void> _requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macOS = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macOS?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _stopForegroundServiceIfNeeded() async {
    if (!_foregroundServiceActive) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.stopForegroundService();
    _foregroundServiceActive = false;
  }

  String _questionSummaryForNotification(String value) {
    final plain = _plainChineseQuestionText(value);
    final topic = _topicLabelForNotification(plain);
    if (topic.isNotEmpty) {
      return '关于$topic的题目已整理好。';
    }
    if (plain.isEmpty) {
      return '';
    }
    return '这道题的讲解已整理好。';
  }

  String _polishedProgressMessage(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'\bAI\b', caseSensitive: false), '')
        .replaceAll('解析', '整理')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return '正在整理这道错题';
    }
    return cleaned;
  }

  String _polishedFailureMessage(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'\bAI\b', caseSensitive: false), '')
        .replaceAll('解析', '整理')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return '点开知芽重新整理。';
    }
    return cleaned;
  }

  String _plainChineseQuestionText(String value) {
    return value
        .replaceAll(RegExp(r'\${1,2}.*?\${1,2}'), ' ')
        .replaceAll(RegExp(r'\\\(.+?\\\)'), ' ')
        .replaceAll(RegExp(r'\\\[.+?\\\]'), ' ')
        .replaceAll(RegExp(r'\\[a-zA-Z]+(\s*\{[^{}]*\}){0,2}'), ' ')
        .replaceAll(RegExp(r'[A-Za-z0-9_{}^=+\-*/<>|()[\],.:;]+'), ' ')
        .replaceAll(RegExp(r'[×÷√≤≥≠≈∞∴∵→⇒πθλμσΔΩαβγ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _topicLabelForNotification(String text) {
    final normalized = text.toLowerCase();
    final topics = <({String label, List<String> keywords})>[
      (label: '圆锥曲线', keywords: ['圆锥', '椭圆', '双曲线', '抛物线', '焦点', '准线']),
      (label: '函数图像', keywords: ['函数', '导数', '单调', '极值', '最值', '零点']),
      (label: '几何证明', keywords: ['几何', '三角形', '圆', '切线', '相似', '全等']),
      (label: '数列', keywords: ['数列', '等差', '等比', '通项', '递推']),
      (label: '概率统计', keywords: ['概率', '随机', '统计', '期望', '方差']),
      (
        label: '力学',
        keywords: ['物理', '力', '受力', '摩擦', '速度', '加速度', '斜面', '木板', '滑块']
      ),
      (label: '电学', keywords: ['电路', '电流', '电压', '电阻', '电场', '磁场']),
      (label: '光学', keywords: ['光学', '透镜', '反射', '折射', '成像']),
      (label: '化学反应', keywords: ['化学', '反应', '溶液', '离子', '方程式']),
      (label: '英语阅读', keywords: ['english', '阅读', '完形', '语法', '单词']),
    ];
    for (final topic in topics) {
      if (topic.keywords.any(normalized.contains)) {
        return topic.label;
      }
    }
    return '';
  }
}
