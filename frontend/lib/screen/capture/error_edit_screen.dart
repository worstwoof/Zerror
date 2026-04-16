import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/latex_text.dart';
import '../../core/theme.dart';
import '../../data/ai_api_client.dart';
import '../../data/file_upload_client.dart';
import '../base/error_detail_screen.dart';
import 'html_artifact_preview_screen.dart';

class ErrorEditScreen extends StatefulWidget {
  const ErrorEditScreen({
    super.key,
    required this.imagePath,
    required this.initialText,
    this.initialAnalysis,
  });

  final String imagePath;
  final String initialText;
  final AnalysisResult? initialAnalysis;

  @override
  State<ErrorEditScreen> createState() => _ErrorEditScreenState();
}

class _ErrorEditScreenState extends State<ErrorEditScreen> {
  final AiApiClient _apiClient = const AiApiClient();
  final FileUploadClient _fileUploadClient = const FileUploadClient();
  final List<String> _errorReasons = const [
    '粗心大意',
    '概念模糊',
    '公式遗忘',
    '思路中断',
    '计算错误',
  ];

  late final TextEditingController _questionController;
  late final TextEditingController _reflectionController;

  bool _isAiThinking = true;
  bool _isSaving = false;
  String _selectedErrorReason = '';
  String _subject = '通用';
  String _solutionSummary = '';
  String _mistakeDiagnosis = '';
  String _reviewFocus = '';
  List<int> _reviewSchedule = const [];
  List<String> _knowledgePoints = const [];
  List<String> _solutionSteps = const [];
  List<SimilarQuestionItem> _similarQuestions = const [];
  List<Map<String, dynamic>> _richArtifacts = const [];
  String? _analysisError;
  bool _isGeneratingPhysicsAnimation = false;
  String? _physicsAnimationError;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.initialText);
    _reflectionController = TextEditingController();
    if (widget.initialAnalysis != null) {
      _applyAnalysisResult(widget.initialAnalysis!);
      _isAiThinking = false;
    } else {
      _generateAiAnalysis();
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _generateAiAnalysis() async {
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      setState(() {
        _analysisError = '请先确认题目内容后再生成解析。';
        _isAiThinking = false;
      });
      return;
    }

    setState(() {
      _isAiThinking = true;
      _analysisError = null;
    });

    try {
      final result = await _apiClient.analyzeQuestion(
        questionText: questionText,
        subject: _guessSubject(questionText),
        wrongReasonHint: _selectedErrorReason,
      );

      if (!mounted) return;
      setState(() {
        _applyAnalysisResult(result);
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

  void _applyAnalysisResult(AnalysisResult result) {
    _subject = result.subject;
    _knowledgePoints = result.knowledgePoints;
    _solutionSummary = result.solutionSummary;
    _solutionSteps = result.solutionSteps;
    _mistakeDiagnosis = result.mistakeDiagnosis;
    _reviewFocus = result.reviewFocus;
    _reviewSchedule = result.reviewSchedule;
    _similarQuestions = result.similarQuestions;
    _richArtifacts = result.richArtifacts;
    _isGeneratingPhysicsAnimation = false;
    _physicsAnimationError = null;
  }

  bool _supportsPhysicsAnimation() {
    return _subject.trim().contains('物理');
  }

  bool _hasInteractiveHtmlArtifact() {
    return _findInteractiveHtmlArtifactIndex() != -1;
  }

  int _findInteractiveHtmlArtifactIndex() {
    return _richArtifacts.indexWhere((artifact) {
      final type = (artifact['artifact_type'] ?? '').toString();
      final mimeType = (artifact['mime_type'] ?? '').toString();
      return type == 'interactive_html' || mimeType == 'text/html';
    });
  }

  void _upsertInteractiveHtmlArtifact(Map<String, dynamic> artifact) {
    final normalizedArtifact = artifact.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final updatedArtifacts = List<Map<String, dynamic>>.from(_richArtifacts);
    final existingIndex = _findInteractiveHtmlArtifactIndex();
    if (existingIndex >= 0) {
      updatedArtifacts[existingIndex] = normalizedArtifact;
    } else {
      updatedArtifacts.insert(0, normalizedArtifact);
    }
    _richArtifacts = updatedArtifacts;
  }

  Future<void> _generatePhysicsAnimation() async {
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先确认题目内容，再生成动画演示。')),
      );
      return;
    }

    setState(() {
      _isGeneratingPhysicsAnimation = true;
      _physicsAnimationError = null;
    });

    try {
      final result = await _apiClient.generatePhysicsAnimation(
        PhysicsAnimationPayload(
          cleanedQuestion: questionText,
          subject: _subject,
          knowledgePoints: _knowledgePoints,
          solutionSummary: _solutionSummary,
          solutionSteps: _solutionSteps,
        ),
      );

      if (!mounted) return;
      setState(() {
        _isGeneratingPhysicsAnimation = false;
        if (result.generated && result.artifact != null) {
          _upsertInteractiveHtmlArtifact(result.artifact!);
          _physicsAnimationError = null;
        } else {
          _physicsAnimationError = result.reason.trim().isEmpty
              ? '当前题目暂时无法生成动画演示。'
              : result.reason;
        }
      });

      if (result.generated && result.artifact != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('动画演示已生成，可在下方学科扩展中打开。')),
        );
      }
    } on AiApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isGeneratingPhysicsAnimation = false;
        _physicsAnimationError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGeneratingPhysicsAnimation = false;
        _physicsAnimationError = '动画演示生成失败，请检查后端服务后重试。';
      });
    }
  }

  Future<void> _saveToArchive() async {
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

  Future<void> _saveToArchiveWithUpload() async {
    final question = _questionController.text.trim();
    if (_isSaving) return;
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先确认题目内容')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? imageUrl;
      if (widget.imagePath.isNotEmpty) {
        final store = AppStateScope.of(context);
        final uploaded = await _fileUploadClient.uploadFile(
          filePath: widget.imagePath,
          category: 'error-image',
          syncUserId: store.syncUserId,
          authToken: store.authToken,
        );
        imageUrl = uploaded.fileUrl;
      }

      final draft = _buildDraftWithImage(question, imageUrl: imageUrl);
      final created = AppStateScope.of(context).addErrorRecord(draft);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('错题已加入档案')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ErrorDetailScreen(errorId: created.id),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $error')),
      );
    }
  }

  NewErrorDraft _buildDraftWithImage(String question, {String? imageUrl}) {
    final draft = _buildDraft(question);
    return NewErrorDraft(
      subject: draft.subject,
      topic: draft.topic,
      question: draft.question,
      reason: draft.reason,
      tags: draft.tags,
      myAnswer: draft.myAnswer,
      aiAnalysis: draft.aiAnalysis,
      imageUrl: imageUrl,
      isFavorite: draft.isFavorite,
      isMastered: draft.isMastered,
      dateLabel: draft.dateLabel,
    );
  }

  NewErrorDraft _buildDraft(String question) {
    final subject = _subject == '通用' ? _inferSubject(question) : _subject;
    final topic = _inferTopic(question, subject);
    final reason = _selectedErrorReason.isNotEmpty ? _selectedErrorReason : '概念模糊';
    final reflection = _reflectionController.text.trim();

    final summaryParts = <String>[
      if (_solutionSummary.isNotEmpty) _solutionSummary,
      if (_mistakeDiagnosis.isNotEmpty) '错因诊断：$_mistakeDiagnosis',
      if (_reviewFocus.isNotEmpty)
        _reviewSchedule.isEmpty
            ? '复习建议：$_reviewFocus'
            : '复习建议：$_reviewFocus（${_reviewSchedule.join(' / ')} 天）',
      if (_richArtifacts.isNotEmpty)
        '扩展内容：已生成 ${_richArtifacts.length} 个学科增强模块，可在后续版本接入展示。',
    ];

    return NewErrorDraft(
      subject: subject,
      topic: topic,
      question: question,
      reason: reason,
      tags: _buildTags(subject, topic),
      myAnswer: reflection.isEmpty ? '这道题先加入错题档案，后续复习时继续补充。' : reflection,
      aiAnalysis: summaryParts.isEmpty ? _buildFallbackAnalysis(subject, topic) : summaryParts.join('\n\n'),
      isFavorite: false,
      isMastered: false,
    );
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
    return _subject == '通用' ? '综合复盘' : _subject;
  }

  String _inferTopic(String question, String subject) {
    if (_knowledgePoints.isNotEmpty) {
      return _knowledgePoints.first;
    }
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
      if (_selectedErrorReason.isNotEmpty) _selectedErrorReason,
    ];
  }

  String _buildFallbackAnalysis(String subject, String topic) {
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
        actions: [
          IconButton(
            onPressed: _isAiThinking ? null : _generateAiAnalysis,
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.textPrimary),
            tooltip: '重新生成解析',
          ),
        ],
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 12),
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
                  onPressed: _isSaving ? null : _saveToArchiveWithUpload,
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
          children: [
            const CircularProgressIndicator(color: AppPalette.almondCream),
            const SizedBox(height: 24),
            const Text(
              '知芽 AI 正在深度分析题目...',
              style: TextStyle(color: AppPalette.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedErrorReason.isEmpty
                  ? '正在生成归因、知识点和后续训练建议'
                  : '正在结合“$_selectedErrorReason”重新分析',
              style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisDashboard() {
    final subject = _subject == '通用' ? _inferSubject(_questionController.text) : _subject;
    final topic = _inferTopic(_questionController.text, subject);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 96),
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
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTagChip(subject),
                    _buildTagChip(topic),
                    ..._knowledgePoints.take(2).map(_buildTagChip),
                  ],
                ),
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppPalette.pastelGrey.withValues(alpha: 0.08),
              ),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _questionController,
              builder: (context, value, _) {
                final previewText = value.text.trim();
                if (previewText.isEmpty) {
                  return const Text(
                    '这里会实时显示题干的 LaTeX 渲染效果。',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 13,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '题干渲染预览',
                      style: TextStyle(
                        color: AppPalette.almondCream,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppLatexText(
                      previewText,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSolutionCard(String subject, String topic) {
    return AppPanel(
      color: AppPalette.matchaMist.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_analysisError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x22E17D6B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x55E17D6B)),
              ),
              child: Text(
                'AI 解析暂时失败：$_analysisError',
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const AppSectionTitle(
            title: 'AI 深度解析',
            subtitle: '现在已经接入真实后端结果',
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
            alignment: Alignment.center,
            child: const Text(
              '预留：后续可接入动态板书 / HTML 扩展内容',
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (_supportsPhysicsAnimation()) ...[
            const SizedBox(height: 12),
            _buildPhysicsAnimationActionCard(),
          ],
          if (_richArtifacts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRichArtifactsPreview(),
          ],
          const SizedBox(height: 16),
          _buildSectionLabel('💡 破题技巧'),
          const SizedBox(height: 6),
          AppLatexText(
            _solutionSummary.isEmpty ? '等待 AI 返回解析结果。' : _solutionSummary,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          if (_mistakeDiagnosis.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSectionLabel('⚠️ 错因诊断'),
            const SizedBox(height: 6),
            AppLatexText(
              _mistakeDiagnosis,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ],
          if (_reviewFocus.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSectionLabel('📅 复习建议'),
            const SizedBox(height: 6),
            AppLatexText(
              _reviewSchedule.isEmpty
                  ? _reviewFocus
                  : '$_reviewFocus\n推荐节奏：${_reviewSchedule.join(' / ')} 天',
              style: const TextStyle(
                color: AppPalette.textPrimary,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              iconColor: AppPalette.almondCream,
              collapsedIconColor: AppPalette.almondCream,
              title: const Text(
                '查看详细推导步骤',
                style: TextStyle(
                  color: AppPalette.almondCream,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _solutionSteps.isEmpty
                      ? const Text(
                          '当前没有可展示的详细步骤。',
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            height: 1.6,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _solutionSteps
                              .map(
                                (step) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: AppLatexText(
                                    step,
                                    style: const TextStyle(
                                      color: AppPalette.textPrimary,
                                      height: 1.6,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '归档方向：$subject · $topic',
            style: const TextStyle(
              color: AppPalette.almondCream,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarQuestionsArea(String topic) {
    if (_similarQuestions.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isAiThinking ? null : _generateAiAnalysis,
          icon: const Icon(Icons.hub_rounded, color: AppPalette.almondCream),
          label: const Text(
            '重新生成举一反三练习',
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
            subtitle: '后续可以把这里接到智能组卷或薄弱点训练',
            icon: Icons.explore_rounded,
          ),
          const SizedBox(height: 14),
          Text(
            '变式练习围绕「$topic」继续展开，方便后续直接进入二次练习。',
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
                  AppLatexText(
                    '练习 ${index + 1}：${question.prompt}',
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (question.answerOutline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    AppLatexText(
                      '答案提纲：${question.answerOutline}',
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
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
                selectedColor: AppPalette.matchaMist,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                labelStyle: TextStyle(
                  color: isSelected ? AppPalette.night : AppPalette.textPrimary,
                  fontSize: 13,
                ),
                side: BorderSide.none,
                onSelected: (selected) {
                  if (!selected) return;
                  setState(() => _selectedErrorReason = reason);
                  _generateAiAnalysis();
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
              hintStyle: const TextStyle(color: AppPalette.textSecondary),
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
              icon: const Icon(Icons.auto_awesome, color: AppPalette.matchaMist, size: 18),
              label: const Text(
                '结合当前题目重新分析',
                style: TextStyle(color: AppPalette.matchaMist),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppPalette.almondCream.withValues(alpha: 0.12),
      side: BorderSide.none,
      labelStyle: const TextStyle(
        color: AppPalette.textPrimary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPhysicsAnimationActionCard() {
    final hasArtifact = _hasInteractiveHtmlArtifact();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.night.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.matchaMist.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '物理动画演示',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasArtifact
                          ? '已生成当前题目的 HTML 动画，可重新生成以刷新展示内容。'
                          : '按需调用后端生成与题目对应的 HTML 动画，并复用下方 WebView 预览。',
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingPhysicsAnimation ? null : _generatePhysicsAnimation,
                  icon: _isGeneratingPhysicsAnimation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.animation_rounded,
                          color: AppPalette.almondCream,
                          size: 18,
                        ),
                  label: Text(
                    _isGeneratingPhysicsAnimation
                        ? '生成中...'
                        : hasArtifact
                            ? '重新生成'
                            : '生成动画',
                    style: const TextStyle(color: AppPalette.almondCream),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppPalette.almondCream.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_physicsAnimationError != null) ...[
            const SizedBox(height: 10),
            Text(
              _physicsAnimationError!,
              style: const TextStyle(
                color: Color(0xFFFFC3B8),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppPalette.textPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRichArtifactsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('🧩 学科扩展'),
        const SizedBox(height: 8),
        ..._richArtifacts.map(_buildRichArtifactCard),
      ],
    );
  }

  Widget _buildRichArtifactCard(Map<String, dynamic> artifact) {
    final type = (artifact['artifact_type'] ?? '').toString();
    final title = (artifact['title'] ?? '').toString().trim();
    final description = (artifact['description'] ?? '').toString().trim();
    final mimeType = (artifact['mime_type'] ?? '').toString().trim();
    final content = (artifact['content'] ?? '').toString().trim();

    final displayTitle = title.isEmpty ? _fallbackArtifactTitle(type) : title;
    final displayDescription = description.isEmpty
        ? _fallbackArtifactDescription(type)
        : description;
    final previewText = _artifactPreviewText(type, mimeType, content);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.pastelGrey.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _artifactIcon(type),
                color: AppPalette.almondCream,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayTitle,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            displayDescription,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildRichArtifactBody(
            title: displayTitle,
            type: type,
            mimeType: mimeType,
            content: content,
            previewText: previewText,
          ),
        ],
      ),
    );
  }

  IconData _artifactIcon(String type) {
    switch (type) {
      case 'interactive_html':
        return Icons.motion_photos_auto_rounded;
      case 'chart_spec':
        return Icons.show_chart_rounded;
      case 'code_snippet':
        return Icons.code_rounded;
      case 'timeline':
        return Icons.timeline_rounded;
      case 'study_card':
        return Icons.style_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  String _fallbackArtifactTitle(String type) {
    switch (type) {
      case 'interactive_html':
        return '交互式演示内容';
      case 'chart_spec':
        return '图表可视化内容';
      case 'code_snippet':
        return '代码示例';
      case 'timeline':
        return '流程时间线';
      case 'study_card':
        return '复习卡片';
      default:
        return '扩展内容';
    }
  }

  String _fallbackArtifactDescription(String type) {
    switch (type) {
      case 'interactive_html':
        return '已生成适合接入 WebView 的 HTML 内容，后续可用于播放学科演示动画。';
      case 'chart_spec':
        return '已生成结构化图表配置，后续可对接函数图像或统计图渲染。';
      case 'code_snippet':
        return '已生成关键代码与执行思路，适合编程题扩展展示。';
      case 'timeline':
        return '已生成流程型内容，后续可用于步骤推演或时序复盘。';
      case 'study_card':
        return '已生成可拆分展示的知识卡片，适合移动端碎片化复习。';
      default:
        return '已生成可扩展展示内容。';
    }
  }

  String _artifactPreviewText(String type, String mimeType, String content) {
    if (content.isEmpty) {
      return '';
    }
    if (type == 'interactive_html' || mimeType == 'text/html') {
      return '已生成 HTML 片段，可在后续版本中直接接入 WebView 展示交互动画。';
    }

    final singleLine = content.replaceAll('\n', ' ').trim();
    if (singleLine.length <= 120) {
      return singleLine;
    }
    return '${singleLine.substring(0, 120)}...';
  }

  Widget _buildRichArtifactBody({
    required String title,
    required String type,
    required String mimeType,
    required String content,
    required String previewText,
  }) {
    final parsed = _tryParseArtifactJson(mimeType, content);

    switch (type) {
      case 'chart_spec':
        if (parsed != null) {
          return _buildChartSpecArtifact(parsed);
        }
        break;
      case 'study_card':
        if (parsed != null) {
          return _buildStudyCardArtifact(parsed);
        }
        break;
      case 'code_snippet':
        if (parsed != null) {
          return _buildCodeSnippetArtifact(parsed);
        }
        break;
      case 'timeline':
        if (parsed != null) {
          return _buildTimelineArtifact(parsed);
        }
        break;
      case 'interactive_html':
        return _buildInteractiveHtmlArtifact(
          title: title,
          content: content,
        );
    }

    if (previewText.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppLatexText(
      previewText,
      style: const TextStyle(
        color: AppPalette.textPrimary,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }

  Map<String, dynamic>? _tryParseArtifactJson(String mimeType, String content) {
    if (content.trim().isEmpty) {
      return null;
    }
    if (mimeType != 'application/json') {
      return null;
    }
    try {
      final parsed = jsonDecode(content);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Widget _buildChartSpecArtifact(Map<String, dynamic> data) {
    final scene = (data['scene'] ?? '').toString();
    final knowledgePoints = (data['knowledge_points'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final suggestions = (data['plot_suggestions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final studentTasks = (data['student_tasks'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final stepMapping = (data['step_mapping'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scene.isNotEmpty) _buildArtifactMetaChip('场景', _chartSceneLabel(scene)),
        if (knowledgePoints.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: knowledgePoints.map((item) => _buildArtifactMetaPill(item)).toList(),
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...suggestions.map((item) {
            final label = (item['label'] ?? '').toString();
            final value = (item['value'] ?? '').toString();
            if (value.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildArtifactInfoTile(
                label: label.isEmpty ? '图像提示' : label,
                child: AppLatexText(
                  value,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }),
        ],
        if (studentTasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildArtifactSectionTitle('学生操作建议'),
          const SizedBox(height: 8),
          ...studentTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildArtifactBullet(task),
            ),
          ),
        ],
        if (stepMapping.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildArtifactSectionTitle('和解题步骤的对应关系'),
          const SizedBox(height: 8),
          ...stepMapping.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildArtifactInfoTile(
                label: '步骤 ${entry.key + 1}',
                child: AppLatexText(
                  entry.value,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStudyCardArtifact(Map<String, dynamic> data) {
    final cards = (data['cards'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards.map((card) {
        final front = (card['front'] ?? '').toString();
        final back = (card['back'] ?? '').toString();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                front.isEmpty ? '复习卡片' : front,
                style: const TextStyle(
                  color: AppPalette.almondCream,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (back.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                AppLatexText(
                  back,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCodeSnippetArtifact(Map<String, dynamic> data) {
    final focus = (data['focus'] ?? '').toString();
    final language = (data['language'] ?? '').toString();
    final template = (data['template'] ?? '').toString();
    final traceSteps = (data['trace_steps'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final debugChecklist = (data['debug_checklist'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (focus.isNotEmpty || language.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (focus.isNotEmpty) _buildArtifactMetaChip('核心', focus),
              if (language.isNotEmpty) _buildArtifactMetaChip('语言', language),
            ],
          ),
        if (template.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildArtifactSectionTitle('代码骨架'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.night.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                template,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 12.5,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
        if (traceSteps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildArtifactSectionTitle('执行思路'),
          const SizedBox(height: 8),
          ...traceSteps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildArtifactBullet(step),
              )),
        ],
        if (debugChecklist.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildArtifactSectionTitle('调试清单'),
          const SizedBox(height: 8),
          ...debugChecklist.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildArtifactBullet(item),
              )),
        ],
      ],
    );
  }

  Widget _buildTimelineArtifact(Map<String, dynamic> data) {
    final stages = (data['stages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (stages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: stages.asMap().entries.map((entry) {
        final index = entry.key;
        final stage = entry.value;
        final stageName = (stage['stage'] ?? '').toString();
        final focus = (stage['focus'] ?? '').toString();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppPalette.matchaMist,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppPalette.night,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (index != stages.length - 1)
                  Container(
                    width: 2,
                    height: 42,
                    color: AppPalette.pastelGrey.withValues(alpha: 0.20),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildArtifactInfoTile(
                  label: stageName.isEmpty ? '阶段 ${index + 1}' : stageName,
                  child: AppLatexText(
                    focus,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildInteractiveHtmlArtifact({
    required String title,
    required String content,
  }) {
    final htmlSize = utf8.encode(content).length;
    final kb = (htmlSize / 1024).toStringAsFixed(1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildArtifactMetaChip('类型', 'HTML 动画'),
              _buildArtifactMetaChip('大小', '$kb KB'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '这部分已经不是普通文本，而是一段可嵌入 WebView 的交互页面源码。当前页面先不直接渲染源码，避免出现显示不全的问题。',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '下一步可以把它接到独立的 WebView 预览页，用来播放物理过程动画或交互演示。',
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HtmlArtifactPreviewScreen(
                      title: title,
                      htmlContent: content,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.open_in_browser_rounded,
                color: AppPalette.almondCream,
              ),
              label: const Text(
                '打开交互预览',
                style: TextStyle(color: AppPalette.almondCream),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppPalette.almondCream.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppPalette.almondCream,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildArtifactInfoTile({
    required String label,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildArtifactBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: AppPalette.almondCream,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppLatexText(
            text,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArtifactMetaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.almondCream.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(
          color: AppPalette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildArtifactMetaPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppPalette.textPrimary,
          fontSize: 12,
        ),
      ),
    );
  }

  String _chartSceneLabel(String scene) {
    switch (scene) {
      case 'function':
        return '函数图像';
      case 'geometry':
        return '几何构型';
      case 'statistics':
        return '统计图表';
      default:
        return scene;
    }
  }
}
