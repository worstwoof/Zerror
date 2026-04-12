import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';
import '../base/error_detail_screen.dart';

class ErrorEditScreen extends StatefulWidget {
  const ErrorEditScreen({
    super.key,
    required this.imagePath,
    required this.initialText,
  });

  final String imagePath;
  final String initialText;

  @override
  State<ErrorEditScreen> createState() => _ErrorEditScreenState();
}

class _ErrorEditScreenState extends State<ErrorEditScreen> {
  final Color primaryGreen = AppPalette.matchaMist;

  late final TextEditingController _questionController;
  late final TextEditingController _reflectionController;

  bool _isAiThinking = true;
  bool _showSimilarQuestions = false;
  String _selectedErrorReason = '';

  final List<String> _errorReasons = const [
    '粗心大意',
    '概念模糊',
    '公式遗忘',
    '思路中断',
    '计算错误',
  ];

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.initialText);
    _reflectionController = TextEditingController();
    _simulateAiAnalysis();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _simulateAiAnalysis() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isAiThinking = false);
  }

  void _saveToArchive() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先确认题目内容')),
      );
      return;
    }

    try {
      final draft = _buildDraft(question);
      final created = AppStateScope.of(context).addErrorRecord(draft);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错题已加入档案，并进入后续复习链路')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ErrorDetailScreen(errorId: created.id),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  NewErrorDraft _buildDraft(String question) {
    final subject = _inferSubject(question);
    final topic = _inferTopic(question, subject);
    final reason = _selectedErrorReason.isNotEmpty
        ? _selectedErrorReason
        : '概念模糊';
    final reflection = _reflectionController.text.trim();
    final note = reflection.isEmpty ? '这道题先加入错题档案，后续复习时继续补充。' : reflection;

    return NewErrorDraft(
      subject: subject,
      topic: topic,
      question: question,
      reason: reason,
      tags: _buildTags(subject, topic),
      myAnswer: note,
      aiAnalysis: _buildAiAnalysis(subject, topic),
      isFavorite: false,
      isMastered: false,
    );
  }

  String _inferSubject(String question) {
    final lower = question.toLowerCase();
    if (question.contains('矩阵') || question.contains('特征值') || question.contains('线代')) {
      return '线性代数';
    }
    if (lower.contains('kmp') || question.contains('数据结构')) {
      return '数据结构';
    }
    if (lower.contains('java') || question.contains('接口') || question.contains('策略')) {
      return 'Java';
    }
    if (question.contains('贝叶斯') || question.contains('概率')) {
      return '概率论';
    }
    return '综合复盘';
  }

  String _inferTopic(String question, String subject) {
    if (question.contains('特征值') || question.contains('伴随矩阵')) {
      return '矩阵特征值与相似对角化';
    }
    if (question.toLowerCase().contains('kmp')) {
      return 'KMP next 数组构造';
    }
    if (question.contains('接口') || question.contains('策略')) {
      return '策略模式与接口抽象';
    }
    if (question.contains('贝叶斯')) {
      return '贝叶斯公式应用';
    }
    return '$subject 重点错题回收';
  }

  List<String> _buildTags(String subject, String topic) {
    return [
      subject,
      topic,
      '新录入',
    ];
  }

  String _buildAiAnalysis(String subject, String topic) {
    return '这道题已归入「$subject」中的「$topic」。建议先弄清楚题目考的核心定义，再把关键推理步骤拆成 2 到 3 个可复述的小步骤，后续复习时更容易真正回收。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          '知芽 AI 解析',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AppSurface(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: _isAiThinking ? _buildLoadingState() : _buildAnalysisDashboard(),
      ),
      bottomNavigationBar: _isAiThinking
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: AppPalette.night.withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: AppPalette.pastelGrey.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: '生成我的错题档案',
                  icon: Icons.library_add_check_rounded,
                  onPressed: _saveToArchive,
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: AppPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: AppPalette.almondCream),
            SizedBox(height: 24),
            Text(
              '知芽 AI 正在深度分析题目...',
              style: TextStyle(color: AppPalette.textPrimary, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '正在生成归因、知识点和后续训练建议',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisDashboard() {
    final question = _questionController.text.trim();
    final subject = _inferSubject(question);
    final topic = _inferTopic(question, subject);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 72, bottom: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOriginalQuestionCard(subject, topic),
          const SizedBox(height: 18),
          _buildAiSolutionCard(subject, topic),
          const SizedBox(height: 18),
          _buildSimilarQuestionsArea(topic),
          const SizedBox(height: 18),
          _buildUserReflectionCard(),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildOriginalQuestionCard(String subject, String topic) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: '原题与识别结果',
            subtitle: '这里可以继续修正识别文本，再收入档案',
            icon: Icons.document_scanner_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.imagePath.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TagChip(label: subject),
                  _TagChip(label: topic),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _questionController,
            maxLines: null,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 15,
              height: 1.6,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSolutionCard(String subject, String topic) {
    return AppPanel(
      color: primaryGreen.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'AI 解题摘要',
            subtitle: '先看归因，再决定是否继续补训练',
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 16),
          Container(
            height: 84,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppPalette.night.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppPalette.textPrimary,
                  size: 36,
                ),
                SizedBox(width: 12),
                Text(
                  '播放 AI 动态讲解',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '归档方向：$subject · $topic',
            style: const TextStyle(
              color: AppPalette.almondCream,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _buildAiAnalysis(subject, topic),
            style: const TextStyle(
              color: AppPalette.textPrimary,
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarQuestionsArea(String topic) {
    if (!_showSimilarQuestions) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _showSimilarQuestions = true),
          icon: const Icon(Icons.hub_rounded, color: AppPalette.almondCream),
          label: const Text(
            '生成举一反三练习',
            style: TextStyle(color: AppPalette.almondCream),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: AppPalette.almondCream.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: '举一反三',
            subtitle: '后续可以直接把这里接入智能组卷或薄弱点训练',
            icon: Icons.explore_rounded,
          ),
          const SizedBox(height: 14),
          Text(
            '变式练习：围绕「$topic」再补一题，重点检查你是否能自己复述关键推理步骤。',
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text(
                '稍后去组卷练习',
                style: TextStyle(color: AppPalette.matchaMist),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserReflectionCard() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: '自我复盘',
            subtitle: '记录为什么错，以及下次怎么避坑',
            icon: Icons.rate_review_rounded,
          ),
          const SizedBox(height: 16),
          const Text(
            '这次为什么做错了？',
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _errorReasons.map((reason) {
              final isSelected = _selectedErrorReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: isSelected,
                selectedColor: primaryGreen,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                labelStyle: TextStyle(
                  color: isSelected ? AppPalette.night : AppPalette.textPrimary,
                  fontSize: 13,
                ),
                side: BorderSide.none,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedErrorReason = reason);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reflectionController,
            maxLines: 3,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: '写下你自己的避坑笔记...',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.matchaMist.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.matchaMist,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
