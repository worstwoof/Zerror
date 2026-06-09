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

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AnimationController? _flipController;
  final List<_ChatMessage> _messages = const [
    _ChatMessage(
      text: '我可以帮你拆解错题、安排复习、生成同类题。先把今天最卡的一道题发给我吧。',
      isUser: false,
    ),
  ].toList();
  bool _showChat = false;
  bool _isFlipping = false;
  bool _isThinking = false;

  static const List<String> _prompts = [
    '帮我总结今天的薄弱点',
    '生成 3 道同类变式题',
    '把这道题讲得更简单',
    '安排明天 20 分钟复习',
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            children: [
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
            'Zerror 助手',
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
