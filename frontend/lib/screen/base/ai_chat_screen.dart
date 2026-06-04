import 'dart:async';

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
      return '我先按“概念理解、公式代入、综合应用”三档给你排题。正式接入接口后，这里会结合你的错题档案自动生成题目。';
    }
    if (text.contains('复习') || text.contains('明天')) {
      return '建议明天分三段：5 分钟回看错因，10 分钟做两道同类题，5 分钟复述解题步骤。重点只抓一个薄弱点，效果会更稳。';
    }
    if (text.contains('薄弱')) {
      return '从当前档案看，可以先按学科、题型、错因三类整理。优先复盘重复出错的知识点，再处理偶发失误。';
    }
    return '我会先把题目拆成“题型、条件、关键公式、易错点、复盘动作”五块。你把题干发来后，我就按这个结构帮你整理。';
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                children: [
                  _hero(),
                  const SizedBox(height: 18),
                  _quickPrompts(),
                  const SizedBox(height: 18),
                  ..._messages.map(
                    (message) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: AppChatBubble(
                        text: message.text,
                        isUser: message.isUser,
                        label: message.isUser ? '你' : 'Zerror AI',
                      ),
                    ),
                  ),
                  if (_isThinking)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: AppChatBubble(
                        text: '正在整理思路...',
                        isUser: false,
                        label: 'Zerror AI',
                      ),
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
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      color: AppPalette.moodBlue,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '把错题变成下一次的提示',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '先用模拟对话整理学习路径，后续可以接入真实 AI 服务。',
                  style: TextStyle(
                    color: Color(0xDDEFF2FF),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/ai_chat_illustration.png',
              width: 106,
              height: 106,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}
