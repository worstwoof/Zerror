import 'dart:io';

import 'package:flutter/material.dart';
import '../../data/ai_api_client.dart';

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
  final Color primaryGreen = const Color(0xFF70A88D);
  final AiApiClient _apiClient = const AiApiClient();
  late TextEditingController _questionController;
  late TextEditingController _reflectionController;

  bool _isAiThinking = true; // 控制 AI 分析的加载状态
  String _selectedErrorReason = ''; // 记录选中的错因
  String _subject = '通用';
  String _solutionSummary = '';
  String _mistakeDiagnosis = '';
  String _reviewFocus = '';
  List<int> _reviewSchedule = const [];
  List<String> _knowledgePoints = const [];
  List<String> _solutionSteps = const [];
  List<SimilarQuestionItem> _similarQuestions = const [];
  String? _analysisError;

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
    _generateAiAnalysis(); // 进入页面即开始真实 AI 分析
  }

  Future<void> _generateAiAnalysis() async {
    setState(() {
      _isAiThinking = true;
      _analysisError = null;
    });

    try {
      final result = await _apiClient.analyzeQuestion(
        questionText: _questionController.text.trim(),
        subject: _guessSubject(_questionController.text),
        wrongReasonHint: _selectedErrorReason,
      );

      if (!mounted) return;
      setState(() {
        _subject = result.subject;
        _knowledgePoints = result.knowledgePoints;
        _solutionSummary = result.solutionSummary;
        _solutionSteps = result.solutionSteps;
        _mistakeDiagnosis = result.mistakeDiagnosis;
        _reviewFocus = result.reviewFocus;
        _reviewSchedule = result.reviewSchedule;
        _similarQuestions = result.similarQuestions;
        _isAiThinking = false;
      });
    } on AiApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _analysisError = error.message;
        _isAiThinking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analysisError = 'AI 解析失败，请检查本地后端或 vivo 接口配置。';
        _isAiThinking = false;
      });
    }
  }

  String _guessSubject(String questionText) {
    final content = questionText.toLowerCase();
    if (content.contains('矩阵') || content.contains('特征值') || content.contains('函数') || content.contains('导数')) {
      return '数学';
    }
    if (content.contains('受力') || content.contains('加速度') || content.contains('电路') || content.contains('速度')) {
      return '物理';
    }
    if (content.contains('cache') || content.contains('cpu') || content.contains('算法') || content.contains('java')) {
      return '计算机';
    }
    return '通用';
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
        iconTheme: IconThemeData(color: textColor),
        title: Text('知芽 AI 解析', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            onPressed: _isAiThinking ? null : _generateAiAnalysis,
            icon: Icon(Icons.refresh_rounded, color: textColor),
            tooltip: '重新生成解析',
          ),
        ],
      ),
      body: _isAiThinking
          ? _buildLoadingState(textColor)
          : _buildAnalysisDashboard(textColor, cardColor, isDarkMode),

      // 底部悬浮的保存按钮
      bottomNavigationBar: _isAiThinking ? null : Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('🎉 错题已入库！知芽会在最佳遗忘点提醒你复习。'), backgroundColor: primaryGreen),
            );
            Navigator.pop(context); // 返回主页
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // ================= 模块 0：加载状态 =================
  Widget _buildLoadingState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryGreen),
          const SizedBox(height: 24),
          Text('知芽 AI 正在深度剖析题目...', style: TextStyle(color: textColor, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _selectedErrorReason.isEmpty
                ? '正在生成解答、归类知识点与拓展练习'
                : '正在结合“$_selectedErrorReason”重新分析',
            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

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

              // AI 自动生成的标签 (无论有无图片，标签都正常显示)
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(_subject, style: const TextStyle(fontSize: 12)),
                      backgroundColor: primaryGreen.withOpacity(0.1),
                      side: BorderSide.none,
                    ),
                    ..._knowledgePoints.take(2).map(
                      (point) => Chip(
                        label: Text(point, style: const TextStyle(fontSize: 12)),
                        backgroundColor: primaryGreen.withOpacity(0.1),
                        side: BorderSide.none,
                      ),
                    ),
                  ],
                ),
              )
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
          if (_analysisError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Text(
                'AI 解析暂时失败：$_analysisError',
                style: TextStyle(color: textColor.withOpacity(0.85), height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Icon(Icons.auto_awesome, color: primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text('AI 独家解析', style: TextStyle(color: primaryGreen, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 84,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppPalette.night.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // 解题思路总结
          Text('💡 破题技巧', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            _solutionSummary.isEmpty ? '等待 AI 返回解析结果。' : _solutionSummary,
            style: TextStyle(color: textColor.withOpacity(0.8), height: 1.5, fontSize: 14),
          ),
          if (_mistakeDiagnosis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('⚠️ 错因诊断', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              _mistakeDiagnosis,
              style: TextStyle(color: textColor.withOpacity(0.8), height: 1.5, fontSize: 14),
            ),
          ],
          if (_reviewFocus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('📅 复习建议', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              _reviewSchedule.isEmpty
                  ? _reviewFocus
                  : '$_reviewFocus\n推荐节奏：${_reviewSchedule.join(' / ')} 天',
              style: TextStyle(color: textColor.withOpacity(0.8), height: 1.5, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          // 详细步骤 (这里用 ExpansionTile 折叠，避免太长)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text('查看详细推导步骤', style: TextStyle(color: primaryGreen, fontSize: 14)),
              tilePadding: EdgeInsets.zero,
              children: [
                Text(
                  _solutionSteps.isEmpty ? '当前没有可展示的详细步骤。' : _solutionSteps.join('\n'),
                  style: TextStyle(color: textColor.withOpacity(0.8), height: 1.6),
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

  // ================= 模块 3：举一反三 =================
  Widget _buildSimilarQuestionsArea(Color textColor, Color cardColor) {
    if (_similarQuestions.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isAiThinking ? null : _generateAiAnalysis,
          icon: Icon(Icons.hub_rounded, color: primaryGreen),
          label: Text('重新生成举一反三练习', style: TextStyle(color: primaryGreen)),
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
          const SizedBox(height: 12),
          ..._similarQuestions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index == _similarQuestions.length - 1 ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '练习 ${index + 1}：${question.prompt}',
                    style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 14),
                  ),
                  if (question.answerOutline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '答案提纲：${question.answerOutline}',
                      style: TextStyle(color: textColor.withOpacity(0.65), fontSize: 13, height: 1.4),
                    ),
                  ],
                ],
              ),
            );
          }),
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
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _selectedErrorReason = reason);
                    _generateAiAnalysis();
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isAiThinking ? null : _generateAiAnalysis,
              icon: Icon(Icons.auto_awesome, color: primaryGreen, size: 18),
              label: Text('结合当前题目重新分析', style: TextStyle(color: primaryGreen)),
            ),
          ),
        ],
      ),
    );
  }
}
