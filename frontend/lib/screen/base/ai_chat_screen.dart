import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';
import '../../data/ai_api_client.dart';
import '../capture/html_artifact_preview_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiApiClient _aiApiClient = const AiApiClient();
  AnimationController? _flipController;
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  _AssistantMode _activeMode = _AssistantMode.quickAnswer;
  bool _showChat = false;
  bool _isFlipping = false;
  bool _isThinking = false;

  static const List<_AssistantQuickAction> _quickActions = [
    _AssistantQuickAction(
      mode: _AssistantMode.quickAnswer,
      title: '快问快答',
      note: '先给短结论',
      prompt: '用 3 句话快速回答我现在最该补什么',
      icon: Icons.flash_on_rounded,
      color: AppPalette.mint,
    ),
    _AssistantQuickAction(
      mode: _AssistantMode.errorMemory,
      title: '错题记忆',
      note: '读取档案上下文',
      prompt: '根据我的错题档案，找出最近反复犯的错',
      icon: Icons.folder_special_rounded,
      color: AppPalette.peach,
    ),
    _AssistantQuickAction(
      mode: _AssistantMode.knowledgeLink,
      title: '关联知识点',
      note: '主动连前后内容',
      prompt: '帮我把这些错题关联到前后知识点',
      icon: Icons.hub_rounded,
      color: AppPalette.blush,
    ),
    _AssistantQuickAction(
      mode: _AssistantMode.examSprint,
      title: '考前短复习',
      note: '10-45 分钟冲刺',
      prompt: '我考前只有 30 分钟，帮我安排冲刺复习',
      icon: Icons.timer_rounded,
      color: AppPalette.leaf,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ensureFlipController();
  }

  AnimationController _ensureFlipController() {
    final existing = _flipController;
    if (existing != null) return existing;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )
      ..addListener(() {
        if (!_showChat && _flipController!.value >= 0.5) {
          setState(() => _showChat = true);
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _isFlipping) {
          setState(() => _isFlipping = false);
        }
      });
    _flipController = controller;
    return controller;
  }

  @override
  void dispose() {
    _flipController?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startChat() {
    if (_showChat || _isFlipping) return;
    setState(() => _isFlipping = true);
    _ensureFlipController().forward(from: 0);
  }

  Future<void> _send({
    String? preset,
    _AssistantMode? mode,
  }) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isThinking) return;
    final selectedMode = mode ?? _activeMode;
    final store = AppStateScope.of(context);
    final lectureIntent = _detectLectureHandoutIntent(text);

    if (lectureIntent.shouldGenerate) {
      final task = store.enqueueLectureHandoutTask(
        prompt: text,
        subject: lectureIntent.subject,
        topic: lectureIntent.topic,
      );
      setState(() {
        _activeMode = selectedMode;
        _messages.add(_ChatMessage.user(text));
        _messages.add(_ChatMessage.lectureHandout(task.id));
        _controller.clear();
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _activeMode = selectedMode;
      _messages.add(_ChatMessage.user(text));
      _controller.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    late final AssistantChatReply reply;
    try {
      reply = await _aiApiClient.askAssistant(
        message: text,
        mode: selectedMode.apiName,
        context: _assistantContext(store),
        errors: _assistantErrors(store, selectedMode),
      );
    } on AiApiException catch (error) {
      reply = _fallbackAssistantReply(
        text,
        selectedMode,
        store,
        error.message,
      );
    } catch (error) {
      reply = _fallbackAssistantReply(
        text,
        selectedMode,
        store,
        'AI 助教暂时不可用，我先按本地错题档案整理。',
      );
    }
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage.assistant(reply));
      _isThinking = false;
    });
    _scrollToBottom();
  }

  Map<String, dynamic> _assistantContext(AppStore store) {
    return {
      'total_errors': store.totalErrors,
      'pending_review_count': store.pendingReviewCount,
      'mastered_count': store.masteredCount,
      'weakest_subject': store.weakestSubject,
      'weakest_topic': store.weakestTopic,
      'weakest_subject_pending_count': store.weakestSubjectPendingCount,
      'weakest_topic_pending_count': store.weakestTopicPendingCount,
      'subject_distribution': store.subjectDistribution,
    };
  }

  List<Map<String, dynamic>> _assistantErrors(
    AppStore store,
    _AssistantMode mode,
  ) {
    final pool = <ErrorRecord>[
      if (mode != _AssistantMode.quickAnswer) ...store.pendingReviewErrors,
      ...store.errors,
    ];
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final item in pool) {
      if (!seen.add(item.id)) continue;
      result.add({
        'id': item.id,
        'subject': item.subject,
        'topic': item.topic,
        'question': _clipForAssistant(item.question, 260),
        'reason': _clipForAssistant(item.reason, 120),
        'tags': item.tags.take(6).toList(growable: false),
        'my_answer': _clipForAssistant(item.myAnswer, 120),
        'ai_analysis': _clipForAssistant(item.aiAnalysis, 220),
        'is_mastered': item.isMastered,
      });
      if (result.length >= 10) break;
    }
    return result;
  }

  AssistantChatReply _fallbackAssistantReply(
    String text,
    _AssistantMode mode,
    AppStore store,
    String reason,
  ) {
    final topic = store.weakestTopic == '核心错题回收' ? '当前错题' : store.weakestTopic;
    final subject =
        store.weakestSubject == '暂无' ? '当前学科' : store.weakestSubject;
    final summary = store.hasLearningHistory
        ? '先按本地错题档案看，当前最该回收的是「$subject · $topic」。'
        : '先把题干或你的错误步骤发来，我会从第一道题开始建立上下文记忆。';

    return AssistantChatReply(
      mode: mode.apiName,
      title: '${mode.title} · 本地整理',
      summary: summary,
      sections: [
        AssistantReplySection(
          title: '服务状态',
          body: reason,
          bullets: const ['我先用本地错题档案生成建议，稍后可继续追问。'],
        ),
        AssistantReplySection(
          title: mode.sectionTitle,
          body: _fallbackBodyForMode(mode, text, subject, topic),
          bullets: _fallbackBulletsForMode(mode),
        ),
      ],
      linkedKnowledge: store.hasLearningHistory ? [topic, subject] : const [],
      followUpPrompts: [
        '把这个知识点讲得更简单',
        '按错题档案生成 3 个追问题',
        '给我安排 20 分钟复习',
      ],
      sprintMinutes: mode == _AssistantMode.examSprint ? 30 : 0,
      fallback: true,
      rawModelOutput: '',
    );
  }

  String _fallbackBodyForMode(
    _AssistantMode mode,
    String text,
    String subject,
    String topic,
  ) {
    switch (mode) {
      case _AssistantMode.errorMemory:
        return '这次先从「$subject · $topic」里找重复错因，再把你问的“$text”接到最近错题上。';
      case _AssistantMode.knowledgeLink:
        return '围绕「$topic」先补定义和公式条件，再连接相邻题型，最后检查易混边界。';
      case _AssistantMode.examSprint:
        return '考前不要铺太开，只抓「$topic」做回看、同类题和步骤复述。';
      case _AssistantMode.quickAnswer:
        return '先给结论，再找题干条件，最后决定是算、判定，还是回到错题档案补同类练习。';
    }
  }

  List<String> _fallbackBulletsForMode(_AssistantMode mode) {
    switch (mode) {
      case _AssistantMode.examSprint:
        return const [
          '0-8 分钟：回看错因和公式条件',
          '8-22 分钟：做 2 道同类题',
          '22-30 分钟：复述步骤和检查点',
        ];
      case _AssistantMode.knowledgeLink:
        return const ['前置定义', '相邻题型', '最容易混淆的条件'];
      case _AssistantMode.errorMemory:
        return const ['找重复错因', '对照最近错题', '用一句话复述修正动作'];
      case _AssistantMode.quickAnswer:
        return const ['先判断题型', '再列已知条件', '最后给下一步动作'];
    }
  }

  String _clipForAssistant(String text, int limit) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= limit) return normalized;
    return '${normalized.substring(0, limit - 1)}…';
  }

  ({bool shouldGenerate, String subject, String topic})
      _detectLectureHandoutIntent(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    final hasDirectHandout = normalized.contains('讲义');
    final hasKnowledgeKeyword = normalized.contains('知识点') ||
        normalized.contains('知识梳理') ||
        normalized.contains('考点梳理');
    final hasOrganizeKeyword = normalized.contains('帮我整理') ||
        normalized.contains('整理一下') ||
        normalized.contains('梳理一下') ||
        normalized.contains('总结一下') ||
        normalized.contains('整理');
    final shouldGenerate =
        hasDirectHandout || (hasKnowledgeKeyword && hasOrganizeKeyword);
    if (!shouldGenerate) {
      return (shouldGenerate: false, subject: '', topic: '');
    }
    final subject = _extractSubject(text);
    final topic = _extractLectureTopic(text, subject);
    return (shouldGenerate: true, subject: subject, topic: topic);
  }

  String _extractSubject(String text) {
    const subjects = [
      '数学',
      '语文',
      '英语',
      '物理',
      '化学',
      '生物',
      '历史',
      '地理',
      '政治',
    ];
    for (final subject in subjects) {
      if (text.contains(subject)) {
        return subject;
      }
    }
    return '';
  }

  String _extractLectureTopic(String text, String subject) {
    var topic = text;
    final removals = [
      '帮我',
      '请',
      '整理一下',
      '帮我整理',
      '梳理一下',
      '总结一下',
      '整理',
      '生成',
      '一份',
      '知识讲义',
      '讲义',
      '知识点',
      '知识梳理',
      '考点梳理',
      '可以下载',
      '下载',
    ];
    for (final removal in removals) {
      topic = topic.replaceAll(removal, ' ');
    }
    if (subject.isNotEmpty) {
      topic = topic.replaceAll(subject, ' ');
    }
    topic = topic.replaceAll(RegExp(r'[\s，。；;、]+'), ' ').trim();
    if (topic.isEmpty) {
      return subject.isEmpty ? '核心知识点' : '$subject核心知识点';
    }
    return topic.length > 32 ? topic.substring(0, 32) : topic;
  }

  void _openLectureHandoutTask(BackgroundLectureHandoutTask task) {
    final handout = task.handout;
    if (handout == null) return;
    final html = handout.printableHtml.trim();
    if (html.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前讲义没有可预览的打印内容')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HtmlArtifactPreviewScreen(
          title: handout.title.isEmpty ? '知识讲义' : handout.title,
          htmlContent: html,
          infoTitle: 'A4 知识讲义预览',
          infoNote: '这份讲义已在后台生成，可用右上角 PDF 按钮导出。',
          scrollable: true,
          exportable: true,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _assistantBubbleText(AssistantChatReply reply) {
    final parts = <String>[];
    final summary = reply.summary.trim();
    if (summary.isNotEmpty) {
      parts.add(summary);
    }

    for (final section in reply.sections) {
      final body = section.body.trim();
      if (body.isNotEmpty && body != summary) {
        parts.add(body);
      }
      for (final bullet in section.bullets) {
        final cleaned = bullet.trim();
        if (cleaned.isNotEmpty) {
          parts.add('• $cleaned');
        }
      }
    }

    final text = parts.join('\n').trim();
    if (text.isNotEmpty) return text;
    final title = reply.title.trim();
    return title.isEmpty ? '我在。' : title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.cream,
      resizeToAvoidBottomInset: true,
      body: AppSurface(
        topSafe: false,
        bottomSafe: false,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(child: _flippingBody()),
            _floatingBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _floatingBackButton() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, top: 8),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppPalette.textPrimary,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _flippingBody() {
    final flipController = _ensureFlipController();
    return AnimatedBuilder(
      animation: flipController,
      builder: (context, child) {
        final progress = flipController.value;
        final angle =
            progress < 0.5 ? progress * math.pi : progress * math.pi - math.pi;
        final scale = 1 - math.sin(progress * math.pi) * 0.025;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..scaleByDouble(scale, scale, 1, 1)
            ..rotateY(angle),
          child: _showChat ? _chatFace() : _introFace(),
        );
      },
    );
  }

  Widget _introFace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelHeight = math.max(0.0, constraints.maxHeight);
        final topInset = MediaQuery.paddingOf(context).top;
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: _hero(math.max(620.0, panelHeight), topInset),
        );
      },
    );
  }

  Widget _chatFace() {
    final store = AppStateScope.of(context);
    final topPadding = MediaQuery.paddingOf(context).top + 70;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(20, topPadding, 20, 22),
            children: [
              _assistantModePanel(store),
              const SizedBox(height: 18),
              ..._messages.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: message.isUser
                      ? AppChatBubble(
                          text: message.text,
                          isUser: true,
                          label: '你',
                        )
                      : message.lectureHandoutTaskId != null
                          ? _LectureHandoutChatTaskCard(
                              task: store.lectureHandoutTaskById(
                                message.lectureHandoutTaskId!,
                              ),
                              onOpen: _openLectureHandoutTask,
                              onRetry: store.retryLectureHandoutTask,
                            )
                          : AppChatBubble(
                              text: _assistantBubbleText(message.reply!),
                              isUser: false,
                            ),
                ),
              ),
              if (_isThinking)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: _AssistantThinkingCard(),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: AppChatInputBar(
            controller: _controller,
            onSend: () => _send(),
            hintText: '${_activeMode.title}：输入题干、错因或复习目标',
          ),
        ),
      ],
    );
  }

  Widget _hero(double height, double topInset) {
    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(22, topInset + 86, 22, 104),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFB),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.white.withOpacity(0.92), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: AppPalette.moodBlue.withOpacity(0.10),
            blurRadius: 36,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        children: [
          const _HeroTitle(),
          const SizedBox(height: 26),
          const SizedBox(
            height: 300,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _FloatingSlimeOrb(size: 250),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            '随时陪你拆解问题\n把任务一步步变轻松',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _startChat,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.inkBlue.withOpacity(0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '开始对话',
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppPalette.textPrimary,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _assistantModePanel(AppStore store) {
    return AppPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 26,
      color: Colors.white.withOpacity(0.78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.moodBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: AppPalette.moodBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 助教',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      store.hasLearningHistory
                          ? '${store.totalErrors} 道错题 · ${store.pendingReviewCount} 道待复习 · 重点 ${store.weakestTopic}'
                          : '先发题干也可以，我会从第一题开始建立记忆',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth > 420
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _quickActions.map((action) {
                  return SizedBox(
                    width: itemWidth,
                    child: _AssistantModeButton(
                      action: action,
                      selected: _activeMode == action.mode,
                      busy: _isThinking,
                      onTap: () {
                        setState(() => _activeMode = action.mode);
                        _send(preset: action.prompt, mode: action.mode);
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  static const Color _accent = Color(0xFF6257D9);

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          color: AppPalette.textPrimary,
          fontSize: 36,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        children: [
          TextSpan(text: '你的 '),
          TextSpan(
            text: 'ZERROR',
            style: TextStyle(color: _accent),
          ),
          TextSpan(text: '\n陪你完成任务'),
        ],
      ),
    );
  }
}

class _AssistantModeButton extends StatelessWidget {
  const _AssistantModeButton({
    required this.action,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final _AssistantQuickAction action;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppPalette.moodBlue.withOpacity(0.38)
        : AppPalette.inkBlue.withOpacity(0.06);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: busy ? null : onTap,
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? action.color.withOpacity(0.62)
                : action.color.withOpacity(0.28),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(selected ? 0.78 : 0.54),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  action.icon,
                  color: AppPalette.inkBlue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantThinkingCard extends StatelessWidget {
  const _AssistantThinkingCard();

  @override
  Widget build(BuildContext context) {
    return const AppPanel(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: _FloatingSlimeOrb(size: 46, compact: true),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '正在整理思路...',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LectureHandoutChatTaskCard extends StatelessWidget {
  const _LectureHandoutChatTaskCard({
    required this.task,
    required this.onOpen,
    required this.onRetry,
  });

  final BackgroundLectureHandoutTask? task;
  final ValueChanged<BackgroundLectureHandoutTask> onOpen;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    final current = task;
    if (current == null) {
      return const AppPanel(
        padding: EdgeInsets.all(16),
        child: Text(
          '讲义任务已从队列移除',
          style: TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final status = _status(current);
    return AppPanel(
      padding: const EdgeInsets.all(16),
      color: Colors.white.withOpacity(0.76),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.leaf.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  status.icon,
                  color: status.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.title,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(current),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (current.isActive) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: current.progress > 0 ? current.progress / 100 : null,
                color: AppPalette.leaf,
                backgroundColor: AppPalette.leaf.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              current.statusMessage ?? 'AI 正在整理讲义，你可以继续问其他问题',
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (current.isCompleted && current.handout != null) ...[
            TextButton.icon(
              onPressed: () => onOpen(current),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('打开讲义并导出 PDF'),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.leaf,
                padding: EdgeInsets.zero,
              ),
            ),
          ] else if (current.isFailed) ...[
            Text(
              current.errorMessage ?? '讲义生成失败，请稍后重试。',
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => onRetry(current.id),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试生成'),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.warmAccentText,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({IconData icon, Color color, String title}) _status(
    BackgroundLectureHandoutTask task,
  ) {
    if (task.isCompleted) {
      return (
        icon: Icons.check_circle_rounded,
        color: AppPalette.leaf,
        title: '讲义已生成',
      );
    }
    if (task.isFailed) {
      return (
        icon: Icons.error_outline_rounded,
        color: AppPalette.warmAccentText,
        title: '讲义生成失败',
      );
    }
    return (
      icon: Icons.auto_awesome_rounded,
      color: AppPalette.leaf,
      title: '正在生成讲义',
    );
  }

  String _subtitle(BackgroundLectureHandoutTask task) {
    final handout = task.handout;
    if (handout != null) {
      final topic = handout.topic.trim().isEmpty ? task.topic : handout.topic;
      return topic.trim().isEmpty ? handout.title : '${handout.title} · $topic';
    }
    final topic = task.topic.trim().isEmpty ? task.prompt : task.topic;
    return topic.length > 44 ? '${topic.substring(0, 43)}…' : topic;
  }
}

class _FloatingSlimeOrb extends StatefulWidget {
  const _FloatingSlimeOrb({
    required this.size,
    this.compact = false,
  });

  final double size;
  final bool compact;

  @override
  State<_FloatingSlimeOrb> createState() => _FloatingSlimeOrbState();
}

class _FloatingSlimeOrbState extends State<_FloatingSlimeOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;
  late final Animation<double> _scale;
  Animation<double>? _shadowScaleX;
  Animation<double>? _shadowScaleY;
  Animation<double>? _shadowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _float = Tween<double>(
      begin: widget.compact ? -1.2 : -7,
      end: widget.compact ? 1.2 : 7,
    ).animate(curve);
    _scale = Tween<double>(
      begin: widget.compact ? 0.995 : 0.982,
      end: widget.compact ? 1.005 : 1.018,
    ).animate(curve);
    _ensureShadowAnimations();
  }

  void _ensureShadowAnimations() {
    if (_shadowScaleX != null &&
        _shadowScaleY != null &&
        _shadowOpacity != null) {
      return;
    }
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _shadowScaleX = Tween<double>(
      begin: widget.compact ? 1 : 0.92,
      end: widget.compact ? 1 : 1.08,
    ).animate(curve);
    _shadowScaleY = Tween<double>(
      begin: widget.compact ? 1 : 0.84,
      end: widget.compact ? 1 : 1.04,
    ).animate(curve);
    _shadowOpacity = Tween<double>(
      begin: widget.compact ? 1 : 0.68,
      end: widget.compact ? 1 : 0.96,
    ).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget orbImage() {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _float.value),
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
        child: Image.asset(
          'assets/images/ai_slime_orb.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      );
    }

    if (widget.compact) {
      return ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: orbImage(),
          ),
        ),
      );
    }

    final shadowHeight = widget.size * 0.46;
    _ensureShadowAnimations();
    final shadowScaleX = _shadowScaleX!;
    final shadowScaleY = _shadowScaleY!;
    final shadowOpacity = _shadowOpacity!;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size + shadowHeight * 0.94,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: widget.size * 0.94,
                left: widget.size * 0.02,
                right: widget.size * 0.02,
                height: shadowHeight,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: shadowOpacity.value,
                      child: Transform.scale(
                        alignment: Alignment.center,
                        scaleX: shadowScaleX.value,
                        scaleY: shadowScaleY.value,
                        child: child,
                      ),
                    );
                  },
                  child: const CustomPaint(
                    painter: _OrbGroundShadowPainter(),
                  ),
                ),
              ),
              orbImage(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbGroundShadowPainter extends CustomPainter {
  const _OrbGroundShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.58);
    final colorShadow = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x55DD6EAA),
          Color(0x356D5DE6),
          Color(0x00FFFFFF),
        ],
        stops: [0.0, 0.50, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: size.width * 0.66,
        ),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height * 0.54,
      ),
      colorShadow,
    );

    final baseShadow = Paint()
      ..color = const Color(0x16F18BA7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.68),
        width: size.width * 1.02,
        height: size.height * 0.40,
      ),
      baseShadow,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbGroundShadowPainter oldDelegate) {
    return false;
  }
}

class _ChatMessage {
  const _ChatMessage.user(this.text)
      : isUser = true,
        reply = null,
        lectureHandoutTaskId = null;

  const _ChatMessage.assistant(this.reply)
      : text = '',
        isUser = false,
        lectureHandoutTaskId = null;

  const _ChatMessage.lectureHandout(this.lectureHandoutTaskId)
      : text = '',
        isUser = false,
        reply = null;

  final String text;
  final bool isUser;
  final AssistantChatReply? reply;
  final String? lectureHandoutTaskId;
}

enum _AssistantMode { quickAnswer, errorMemory, knowledgeLink, examSprint }

extension _AssistantModeInfo on _AssistantMode {
  String get apiName {
    switch (this) {
      case _AssistantMode.quickAnswer:
        return 'quick_answer';
      case _AssistantMode.errorMemory:
        return 'error_memory';
      case _AssistantMode.knowledgeLink:
        return 'knowledge_link';
      case _AssistantMode.examSprint:
        return 'exam_sprint';
    }
  }

  String get title {
    switch (this) {
      case _AssistantMode.quickAnswer:
        return '快问快答';
      case _AssistantMode.errorMemory:
        return '错题记忆';
      case _AssistantMode.knowledgeLink:
        return '关联知识点';
      case _AssistantMode.examSprint:
        return '考前短复习';
    }
  }

  String get sectionTitle {
    switch (this) {
      case _AssistantMode.quickAnswer:
        return '快答路径';
      case _AssistantMode.errorMemory:
        return '错题档案记忆';
      case _AssistantMode.knowledgeLink:
        return '主动关联知识点';
      case _AssistantMode.examSprint:
        return '考前短时复习';
    }
  }
}

class _AssistantQuickAction {
  const _AssistantQuickAction({
    required this.mode,
    required this.title,
    required this.note,
    required this.prompt,
    required this.icon,
    required this.color,
  });

  final _AssistantMode mode;
  final String title;
  final String note;
  final String prompt;
  final IconData icon;
  final Color color;
}
