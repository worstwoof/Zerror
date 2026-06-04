import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = const [
    _ChatMessage(
      text: '我可以帮你拆解错题、安排复习、生成同类题。先把今天最卡的一道题发给我吧。',
      isUser: false,
    ),
    _ChatMessage(
      text: '帮我把这道错题拆成三步讲清楚',
      isUser: true,
    ),
    _ChatMessage(
      text: '可以。第一步先定位题型和已知条件；第二步把公式写成可代入的结构；第三步检查单位、符号和边界条件。你也可以把题干粘过来，我会按这个节奏继续。',
      isUser: false,
    ),
  ].toList();
  bool _isThinking = false;

  static const List<String> _prompts = [
    '帮我总结今天的薄弱点',
    '生成 3 道同类变式题',
    '把这道题讲得更简单',
    '安排明天 20 分钟复习',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 760));
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: _mockReply(text), isUser: false));
      _isThinking = false;
    });
    _scrollToBottom();
  }

  String _mockReply(String text) {
    if (text.contains('同类') || text.contains('变式')) {
      return '我会按三档给你排题：概念理解、公式代入、综合应用。先做 1 道基础题找手感，再做 2 道变式题检查迁移能力。';
    }
    if (text.contains('复习') || text.contains('明天')) {
      return '明天建议分三段：5 分钟回看错因，10 分钟做两道同类题，5 分钟复述解题步骤。重点只抓一个薄弱点，效果会更稳。';
    }
    if (text.contains('薄弱')) {
      return '从当前档案看，可以先按学科、题型、错因三类整理。优先复盘重复出错的知识点，再处理偶发失误。';
    }
    return '我会先把题目拆成题型、条件、关键公式、易错点、复盘动作五块。你把题干发来后，我就按这个结构帮你整理。';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.cream,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        centerTitle: true,
        title: const Text(
          'AI 助教',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AppSurface(
        topSafe: false,
        bottomSafe: false,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                children: [
                  _hero(),
                  const SizedBox(height: 18),
                  _quickPrompts(),
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
                          : _AssistantAnswerCard(text: message.text),
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
                hintText: '输入题干、错因或复习目标',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: AppPalette.paper.withOpacity(0.82),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppPalette.inkBlue.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.moodBlue.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppFlatIconButton(
                icon: Icons.auto_awesome_rounded,
                onTap: null,
                color: AppPalette.mint.withOpacity(0.58),
                iconColor: AppPalette.inkBlue,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppPalette.mint.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Study Pulse',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '你的错题 AI 助手',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '把题目、错因和复习目标交给我，我会整理成更容易执行的学习路径。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          const _FloatingSlimeOrb(size: 188),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: _HeroMetricCard(
                  color: AppPalette.peach,
                  icon: Icons.psychology_alt_rounded,
                  title: '拆题',
                  value: '5 步',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _HeroMetricCard(
                  color: AppPalette.mint,
                  icon: Icons.edit_note_rounded,
                  title: '练习',
                  value: '3 题',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickPrompts() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _prompts.map((prompt) {
        return ActionChip(
          avatar: const Icon(
            Icons.auto_awesome_rounded,
            color: AppPalette.inkBlue,
            size: 16,
          ),
          label: Text(prompt),
          backgroundColor: AppPalette.paper.withOpacity(0.94),
          side: BorderSide(color: AppPalette.inkBlue.withOpacity(0.06)),
          labelStyle: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          onPressed: () => _send(prompt),
        );
      }).toList(),
    );
  }
}

class _AssistantAnswerCard extends StatelessWidget {
  const _AssistantAnswerCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: Text(
            'Zerror AI',
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.74),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppPalette.inkBlue.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: AppPalette.inkBlue.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: _FloatingSlimeOrb(size: 34, compact: true),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '我先帮你把思路整理成卡片',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnswerSection(section: section),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_AnswerSectionData> _buildSections(String text) {
    return [
      _AnswerSectionData(
        icon: Icons.search_rounded,
        title: '题目理解',
        body: text,
        color: AppPalette.mint,
      ),
      const _AnswerSectionData(
        icon: Icons.route_rounded,
        title: '解题步骤',
        body: '先定位题型，再列出已知条件，最后把公式或方法代入到可检查的结构里。',
        color: AppPalette.peach,
      ),
      const _AnswerSectionData(
        icon: Icons.warning_amber_rounded,
        title: '易错提醒',
        body: '注意符号、单位、边界条件和题干里的隐藏限制，做完后用一句话复述你的解法。',
        color: AppPalette.blush,
      ),
      const _AnswerSectionData(
        icon: Icons.refresh_rounded,
        title: '复盘动作',
        body: '把这道题加入同类练习，间隔 1 天再做一次，确认不是靠记忆答对。',
        color: AppPalette.leaf,
      ),
    ];
  }
}

class _AssistantThinkingCard extends StatelessWidget {
  const _AssistantThinkingCard();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: const [
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

class _AnswerSection extends StatelessWidget {
  const _AnswerSection({required this.section});

  final _AnswerSectionData section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: section.color.withOpacity(0.42),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.56),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(section.icon, color: AppPalette.inkBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  section.body,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 13,
                    height: 1.48,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppPalette.inkBlue, size: 20),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * math.pi * 2;
        final floatY = math.sin(t) * (widget.compact ? 1.8 : 9.0);
        final scaleX = 1 + math.sin(t + 0.7) * 0.026;
        final scaleY = 1 + math.cos(t + 0.2) * 0.032;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _SlimeOrbPainter(
                phase: _controller.value,
                compact: widget.compact,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlimeOrbPainter extends CustomPainter {
  const _SlimeOrbPainter({
    required this.phase,
    required this.compact,
  });

  final double phase;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    final radius = shortest * (compact ? 0.38 : 0.32);
    final pulse = math.sin(phase * math.pi * 2);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppPalette.mint.withOpacity(0.0),
          AppPalette.mint.withOpacity(0.18),
          AppPalette.blush.withOpacity(0.0),
        ],
        stops: const [0.25, 0.58, 1],
      ).createShader(Rect.fromCircle(center: center, radius: shortest * 0.48));
    canvas.drawCircle(center, shortest * (compact ? 0.46 : 0.44), glowPaint);

    final shadowPaint = Paint()
      ..color = AppPalette.moodBlue.withOpacity(compact ? 0.06 : 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.88),
        width: radius * 1.42,
        height: radius * 0.28,
      ),
      shadowPaint,
    );

    final path = Path();
    const points = 56;
    for (var i = 0; i <= points; i++) {
      final angle = i / points * math.pi * 2;
      final wobble = math.sin(angle * 3 + phase * math.pi * 2) * 0.035 +
          math.cos(angle * 2 - phase * math.pi * 2.4) * 0.026;
      final r = radius * (1 + wobble + pulse * 0.012);
      final dx = math.cos(angle) * r;
      final dy = math.sin(angle) * r * (1 + math.sin(phase * math.pi * 2) * 0.02);
      final point = center.translate(dx, dy);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final bodyPaint = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(phase * math.pi * 2),
        colors: const [
          Color(0xFF6FE7E3),
          Color(0xFFFFD770),
          Color(0xFFFF7DB5),
          Color(0xFF755CE8),
          Color(0xFF6FE7E3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.25));
    canvas.drawPath(path, bodyPaint);

    final softOverlay = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.86,
        colors: [
          Colors.white.withOpacity(0.82),
          Colors.white.withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, softOverlay);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 1.2 : 2.2
      ..color = Colors.white.withOpacity(0.34);
    canvas.drawPath(path, rimPaint);

    if (!compact) {
      final eyePaint = Paint()..color = Colors.white.withOpacity(0.92);
      final eyeY = center.dy - radius * 0.12 + pulse * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx - radius * 0.28, eyeY),
            width: radius * 0.18,
            height: radius * 0.32,
          ),
          Radius.circular(radius * 0.12),
        ),
        eyePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx + radius * 0.28, eyeY),
            width: radius * 0.18,
            height: radius * 0.32,
          ),
          Radius.circular(radius * 0.12),
        ),
        eyePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SlimeOrbPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.compact != compact;
  }
}

class _AnswerSectionData {
  const _AnswerSectionData({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}
