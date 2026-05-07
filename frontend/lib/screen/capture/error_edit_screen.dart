import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/latex_text.dart';
import '../../core/rose_three_loader.dart';
import '../../core/theme.dart';
import '../../data/ai_api_client.dart';
import '../../data/file_upload_client.dart';
import '../base/error_detail_screen.dart';
import 'geogebra_scene_preview_screen.dart';
import 'html_artifact_preview_screen.dart';
import 'manim_video_preview_screen.dart';

class ErrorEditScreen extends StatefulWidget {
  const ErrorEditScreen({
    super.key,
    required this.imagePath,
    required this.initialText,
    this.initialAnalysis,
    this.onArchived,
  });

  final String imagePath;
  final String initialText;
  final AnalysisResult? initialAnalysis;
  final VoidCallback? onArchived;

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
  String _sceneBrief = '';
  String _mistakeDiagnosis = '';
  String _reviewFocus = '';
  List<int> _reviewSchedule = const [];
  List<String> _knowledgePoints = const [];
  List<String> _solutionSteps = const [];
  List<SimilarQuestionItem> _similarQuestions = const [];
  List<Map<String, dynamic>> _richArtifacts = const [];
  String? _analysisError;
  bool _isGeneratingPhysicsAnimation = false;
  bool _isPollingManimJob = false;
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
    _sceneBrief = result.sceneBrief;
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
    return _resolvedPhysicsSubject().contains('物理');
  }

  String _resolvedPhysicsSubject() {
    final combined = [
      _subject.trim(),
      _questionController.text.trim(),
      _knowledgePoints.join(' '),
      _solutionSummary,
    ].join(' ').toLowerCase();

    const physicsKeywords = <String>[
      '物理',
      '力学',
      '运动',
      '速度',
      '加速度',
      '受力',
      '摩擦',
      '木板',
      '物块',
      '板块',
      '斜面',
      '平抛',
      '碰撞',
      '电路',
      '光学',
      '透镜',
      '反射',
      '折射',
    ];

    final matchesPhysics = physicsKeywords.any(combined.contains);
    if (_subject.trim().contains('物理') || matchesPhysics) {
      return '物理';
    }
    return _subject;
  }

  bool _hasPhysicsAnimationArtifact() {
    return _findPhysicsAnimationArtifactIndex() != -1;
  }

  int _findPhysicsAnimationArtifactIndex() {
    return _richArtifacts.indexWhere((artifact) {
      final type = (artifact['artifact_type'] ?? '').toString();
      return type == 'geogebra_scene' ||
          type == 'manim_job' ||
          type == 'manim_video' ||
          type == 'physics_scene_spec';
    });
  }

  void _upsertPhysicsAnimationArtifact(Map<String, dynamic> artifact) {
    final normalizedArtifact = artifact.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final updatedArtifacts = List<Map<String, dynamic>>.from(_richArtifacts);
    final existingIndex = _findPhysicsAnimationArtifactIndex();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先确认题目内容，再生成动画演示。')));
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
          sceneBrief: _sceneBrief,
          subject: _resolvedPhysicsSubject(),
          knowledgePoints: _knowledgePoints,
          solutionSummary: _solutionSummary,
          solutionSteps: _solutionSteps,
        ),
      );

      if (!mounted) return;
      setState(() {
        _isGeneratingPhysicsAnimation = false;
        if (result.generated && result.artifact != null) {
          _upsertPhysicsAnimationArtifact(result.artifact!);
          _physicsAnimationError = null;
        } else {
          _physicsAnimationError =
              result.reason.trim().isEmpty ? '当前题目暂时无法生成动画演示。' : result.reason;
        }
      });

      if (result.generated && result.artifact != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('动画演示已生成，可在下方学科扩展中打开。')));
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

  Future<void> _pollManimJob(String jobId) async {
    if (_isPollingManimJob) {
      return;
    }
    setState(() {
      _isPollingManimJob = true;
    });
    try {
      for (var attempt = 0; attempt < 20; attempt += 1) {
        final job = await _apiClient.fetchManimJob(jobId);
        if (!mounted) return;
        _applyManimJobUpdate(jobId, job);
        if (job.isFinished) {
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } on AiApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPollingManimJob = false;
        });
      }
    }
  }

  void _applyManimJobUpdate(String jobId, ManimRenderJob job) {
    setState(() {
      final updatedArtifacts = List<Map<String, dynamic>>.from(_richArtifacts);
      final index = updatedArtifacts.indexWhere((artifact) {
        if ((artifact['artifact_type'] ?? '').toString() != 'manim_job') {
          return false;
        }
        final parsed = _tryParseArtifactJson(
          (artifact['mime_type'] ?? '').toString(),
          (artifact['content'] ?? '').toString(),
        );
        return (parsed?['job_id'] ?? '').toString() == jobId;
      });
      if (index < 0) {
        return;
      }
      if (job.status == 'succeeded' && job.videoUrl.isNotEmpty) {
        updatedArtifacts[index] = {
          'artifact_type': 'manim_video',
          'title': 'Manim 讲解视频',
          'description': 'Manim 已生成讲解视频。',
          'mime_type': 'application/json',
          'content': jsonEncode({
            'url': job.videoUrl,
            'duration': null,
            'thumbnail_url': null,
          }),
        };
      } else {
        final current = Map<String, dynamic>.from(updatedArtifacts[index]);
        current['content'] = jsonEncode(job.toArtifactContent());
        updatedArtifacts[index] = current;
      }
      _richArtifacts = updatedArtifacts;
    });
  }

  Future<void> _saveToArchiveWithUpload() async {
    final question = _questionController.text.trim();
    if (_isSaving) return;
    if (question.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先确认题目内容')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final store = AppStateScope.of(context);

    try {
      String? imageUrl;
      if (widget.imagePath.isNotEmpty) {
        final uploaded = await _fileUploadClient.uploadFile(
          filePath: widget.imagePath,
          category: 'error-image',
          syncUserId: store.syncUserId,
          authToken: store.authToken,
        );
        imageUrl = uploaded.fileUrl;
      }

      final draft = _buildDraftWithImage(question, imageUrl: imageUrl);
      final created = store.addErrorRecord(draft);
      widget.onArchived?.call();

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('错题已加入档案')));

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $error')));
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
    final reason =
        _selectedErrorReason.isNotEmpty ? _selectedErrorReason : '概念模糊';
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
      aiAnalysis: summaryParts.isEmpty
          ? _buildFallbackAnalysis(subject, topic)
          : summaryParts.join('\n\n'),
      isFavorite: false,
      isMastered: false,
    );
  }

  String _guessSubject(String questionText) {
    final content = questionText.toLowerCase();
    if (content.contains('矩阵') ||
        content.contains('特征值') ||
        content.contains('函数') ||
        content.contains('导数')) {
      return '数学';
    }
    if (content.contains('受力') ||
        content.contains('加速度') ||
        content.contains('电路') ||
        content.contains('速度')) {
      return '物理';
    }
    if (content.contains('cache') ||
        content.contains('cpu') ||
        content.contains('算法') ||
        content.contains('java')) {
      return '计算机';
    }
    return '通用';
  }

  String _inferSubject(String question) {
    final lower = question.toLowerCase();
    if (question.contains('矩阵') ||
        question.contains('特征值') ||
        question.contains('线代')) {
      return '线性代数';
    }
    if (lower.contains('kmp') || question.contains('数据结构')) {
      return '数据结构';
    }
    if (lower.contains('java') ||
        question.contains('接口') ||
        question.contains('策略')) {
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
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: AppPalette.night,
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
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppPalette.textPrimary,
            ),
            tooltip: '重新生成解析',
          ),
        ],
      ),
      body: AppSurface(
        topSafe: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
            const RoseThreeLoader(size: 156),
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
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisDashboard() {
    final subject =
        _subject == '通用' ? _inferSubject(_questionController.text) : _subject;
    final topic = _inferTopic(_questionController.text, subject);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOriginalQuestionCard(),
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

  Widget _buildOriginalQuestionCard() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: '原题与识别结果',
            subtitle: '点击渲染结果即可修正题干',
            icon: Icons.document_scanner_rounded,
          ),
          const SizedBox(height: 16),
          if (widget.imagePath.isNotEmpty) ...[
            _buildOriginalImagePreview(),
            const SizedBox(height: 14),
          ],
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _questionController,
            builder: (context, value, _) {
              final previewText = value.text.trim();
              final renderPreviewText = _sanitizeQuestionTextForPreview(
                previewText,
              );
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openQuestionTextEditor,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppPalette.pastelGrey.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '题干渲染预览',
                                style: TextStyle(
                                  color: AppPalette.almondCream,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit_rounded,
                              color: AppPalette.textSecondary
                                  .withValues(alpha: 0.82),
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (previewText.isEmpty)
                          const Text(
                            '点击这里补充题干内容。',
                            style: TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 13,
                            ),
                          )
                        else
                          AppLatexText(
                            renderPreviewText,
                            style: const TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openQuestionTextEditor() async {
    final updatedText = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QuestionTextEditorScreen(
          initialText: _questionController.text,
        ),
      ),
    );
    if (!mounted || updatedText == null) {
      return;
    }
    _questionController.text = updatedText;
  }

  Widget _buildOriginalImagePreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppPalette.night.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.pastelGrey.withValues(alpha: 0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: Image.file(
            File(widget.imagePath),
            width: double.infinity,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
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
                              .map(_buildSolutionStep)
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_supportsPhysicsAnimation() || _visibleRichArtifacts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSectionLabel('学科拓展'),
            const SizedBox(height: 8),
            if (_supportsPhysicsAnimation()) _buildPhysicsAnimationActionCard(),
            if (_supportsPhysicsAnimation() && _visibleRichArtifacts.isNotEmpty)
              const SizedBox(height: 12),
            if (_visibleRichArtifacts.isNotEmpty) _buildRichArtifactsPreview(),
          ],
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

  Widget _buildSolutionStep(String step) {
    final parts = _splitDisplayMath(step);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: parts.map((part) {
          final text = part.text.trim();
          if (text.isEmpty) {
            return const SizedBox.shrink();
          }
          if (part.isFormula) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.night.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.pastelGrey.withValues(alpha: 0.08),
                ),
              ),
              child: AppLatexText(
                r'$$' + text + r'$$',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  height: 1.7,
                  fontSize: 15,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AppLatexText(
              text,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                height: 1.65,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_SolutionStepPart> _splitDisplayMath(String text) {
    final normalized = text
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .trim();
    final parts = <_SolutionStepPart>[];
    final pattern = RegExp(r'\$\$(.*?)\$\$', dotAll: true);
    var cursor = 0;
    for (final match in pattern.allMatches(normalized)) {
      if (match.start > cursor) {
        parts.add(_SolutionStepPart(normalized.substring(cursor, match.start)));
      }
      parts.add(_SolutionStepPart(match.group(1) ?? '', isFormula: true));
      cursor = match.end;
    }
    if (cursor < normalized.length) {
      parts.add(_SolutionStepPart(normalized.substring(cursor)));
    }
    if (parts.isEmpty) {
      parts.add(_SolutionStepPart(normalized));
    }
    return parts;
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
              padding: EdgeInsets.only(
                bottom: index == _similarQuestions.length - 1 ? 0 : 12,
              ),
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
            style: const TextStyle(color: AppPalette.textPrimary, fontSize: 14),
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
              icon: const Icon(
                Icons.auto_awesome,
                color: AppPalette.matchaMist,
                size: 18,
              ),
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

  Widget _buildPhysicsAnimationActionCard() {
    final hasArtifact = _hasPhysicsAnimationArtifact();
    final geogebraArtifact = _findGeoGebraArtifact();

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
                      'GeoGebra 交互演示',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasArtifact
                          ? '已生成当前题目的 GeoGebra 交互图，可重新生成以刷新参数和图形。'
                          : '按需生成 GeoGebra 交互图；Manim 讲解视频后续会在后台异步生成。',
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
                  onPressed: _isGeneratingPhysicsAnimation
                      ? null
                      : _generatePhysicsAnimation,
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
          if (geogebraArtifact != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GeoGebraScenePreviewScreen(
                        title: (geogebraArtifact['title'] ?? 'GeoGebra graph')
                            .toString(),
                        spec: geogebraArtifact['spec'] as Map<String, dynamic>,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.open_in_browser_rounded,
                  color: AppPalette.almondCream,
                ),
                label: const Text(
                  'Open GeoGebra graph',
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
        ],
      ),
    );
  }

  Map<String, dynamic>? _findGeoGebraArtifact() {
    for (final artifact in _richArtifacts) {
      final type = (artifact['artifact_type'] ?? '').toString();
      if (type != 'geogebra_scene' && type != 'physics_scene_spec') {
        continue;
      }
      final parsed = _tryParseArtifactJson(
        (artifact['mime_type'] ?? '').toString(),
        (artifact['content'] ?? '').toString(),
      );
      if (parsed == null) {
        continue;
      }
      return {
        'title': (artifact['title'] ?? 'GeoGebra graph').toString(),
        'spec': parsed,
      };
    }
    return null;
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
        ..._visibleRichArtifacts.map(_buildRichArtifactCard),
      ],
    );
  }

  List<Map<String, dynamic>> get _visibleRichArtifacts {
    return _richArtifacts.where(_shouldDisplayRichArtifact).toList();
  }

  bool _shouldDisplayRichArtifact(Map<String, dynamic> artifact) {
    final type = (artifact['artifact_type'] ?? '').toString();
    final mimeType = (artifact['mime_type'] ?? '').toString().trim();
    final content = (artifact['content'] ?? '').toString().trim();
    if (type == 'study_card') {
      return false;
    }
    if (type == 'chart_spec') {
      final parsed = _tryParseArtifactJson(mimeType, content);
      return parsed?['coordinate_graph'] is Map<String, dynamic>;
    }
    return content.isNotEmpty;
  }

  Widget _buildRichArtifactCard(Map<String, dynamic> artifact) {
    final type = (artifact['artifact_type'] ?? '').toString();
    final title = (artifact['title'] ?? '').toString().trim();
    final description = (artifact['description'] ?? '').toString().trim();
    final mimeType = (artifact['mime_type'] ?? '').toString().trim();
    final content = (artifact['content'] ?? '').toString().trim();

    final displayTitle = title.isEmpty ? _fallbackArtifactTitle(type) : title;
    final displayDescription =
        description.isEmpty ? _fallbackArtifactDescription(type) : description;
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
      case 'geogebra_scene':
        return Icons.dynamic_form_rounded;
      case 'manim_job':
        return Icons.movie_filter_rounded;
      case 'manim_video':
        return Icons.play_circle_fill_rounded;
      case 'text_explanation':
        return Icons.notes_rounded;
      case 'image_analysis':
        return Icons.image_search_rounded;
      case 'physics_scene_spec':
        return Icons.dynamic_form_rounded;
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
      case 'geogebra_scene':
        return 'GeoGebra 交互图';
      case 'manim_job':
        return 'Manim 讲解视频生成中';
      case 'manim_video':
        return 'Manim 讲解视频';
      case 'text_explanation':
        return '补充说明';
      case 'image_analysis':
        return '图像识别分析';
      case 'physics_scene_spec':
        return 'GeoGebra 交互图';
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
      case 'geogebra_scene':
        return '已生成 GeoGebra 交互图，可拖动点或调节参数观察变化。';
      case 'manim_job':
        return '已创建 Manim 讲解视频任务，完成后可播放视频。';
      case 'manim_video':
        return '已生成 Manim 讲解视频，可直接播放或复习。';
      case 'text_explanation':
        return '当前题目暂时不适合生成可靠图形，先展示文字降级说明。';
      case 'image_analysis':
        return '来自图片内容的结构化识别与分析。';
      case 'physics_scene_spec':
        return '旧版场景规格将使用 GeoGebra 交互图打开。';
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
    if (type == 'geogebra_scene') {
      return '已生成 GeoGebra 交互图配置，可打开交互预览。';
    }
    if (type == 'manim_job') {
      return 'Manim 讲解视频正在等待后台生成。';
    }
    if (type == 'manim_video') {
      return 'Manim 讲解视频已生成。';
    }
    if (type == 'physics_scene_spec') {
      return '旧版场景规格可使用 GeoGebra 交互图打开。';
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
      case 'geogebra_scene':
        if (parsed != null) {
          return _buildGeoGebraSceneArtifact(title: title, spec: parsed);
        }
        break;
      case 'manim_job':
        if (parsed != null) {
          return _buildManimJobArtifact(parsed);
        }
        break;
      case 'manim_video':
        return _buildManimVideoArtifact(title: title, content: content);
      case 'physics_scene_spec':
        if (parsed != null) {
          return _buildGeoGebraSceneArtifact(title: title, spec: parsed);
        }
        break;
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
        return _buildInteractiveHtmlArtifact(title: title, content: content);
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
    final topicType = (data['topic_type'] ?? scene).toString();
    final coreIdea = (data['core_idea'] ?? '').toString().trim();
    final expressions = _artifactStringList(data['expressions']);
    final formulaTransformations = _artifactMapList(
      data['formula_transformations'],
    );
    final solutionPath = _artifactMapList(data['solution_path']);
    final mistakeTraps = _artifactStringList(data['mistake_traps']);
    final reviewChecklist = _artifactStringList(data['review_checklist']);
    final visualHint = (data['visual_hint'] ?? '').toString().trim();
    final coordinateGraph = data['coordinate_graph'] is Map<String, dynamic>
        ? data['coordinate_graph'] as Map<String, dynamic>
        : null;
    if (coordinateGraph != null) {
      return _buildCoordinateGraphArtifact(coordinateGraph);
    }
    final knowledgePoints =
        (data['knowledge_points'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
    final hasReviewCard = coreIdea.isNotEmpty ||
        formulaTransformations.isNotEmpty ||
        solutionPath.isNotEmpty ||
        mistakeTraps.isNotEmpty ||
        reviewChecklist.isNotEmpty ||
        visualHint.isNotEmpty ||
        coordinateGraph != null;

    if (hasReviewCard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topicType.isNotEmpty)
            _buildArtifactMetaChip('题型', _chartSceneLabel(topicType)),
          if (knowledgePoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: knowledgePoints
                  .map((item) => _buildArtifactMetaPill(item))
                  .toList(),
            ),
          ],
          if (coreIdea.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildArtifactInfoTile(
              label: '核心思路',
              child: AppLatexText(
                coreIdea,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (expressions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildArtifactSectionTitle('关键公式'),
            const SizedBox(height: 8),
            ...expressions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildArtifactBullet(item),
              ),
            ),
          ],
          if (coordinateGraph != null) ...[
            const SizedBox(height: 12),
            _buildCoordinateGraphArtifact(coordinateGraph),
          ],
          if (formulaTransformations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildArtifactSectionTitle('关键变形'),
            const SizedBox(height: 8),
            ...formulaTransformations.map((item) {
              final label = (item['label'] ?? '变形提示').toString();
              final detail = (item['detail'] ?? '').toString().trim();
              if (detail.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildArtifactInfoTile(
                  label: label,
                  child: AppLatexText(
                    detail,
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
          if (solutionPath.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildArtifactSectionTitle('解题路线'),
            const SizedBox(height: 8),
            ...solutionPath.asMap().entries.map((entry) {
              final item = entry.value;
              final action =
                  (item['action'] ?? '步骤 ${entry.key + 1}').toString();
              final reason = (item['reason'] ?? '').toString().trim();
              if (reason.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildArtifactInfoTile(
                  label: action,
                  child: AppLatexText(
                    reason,
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
          if (mistakeTraps.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildArtifactSectionTitle('易错提醒'),
            const SizedBox(height: 8),
            ...mistakeTraps.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildArtifactBullet(item),
              ),
            ),
          ],
          if (reviewChecklist.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildArtifactSectionTitle('复盘清单'),
            const SizedBox(height: 8),
            ...reviewChecklist.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildArtifactBullet(item),
              ),
            ),
          ],
          if (visualHint.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildArtifactInfoTile(
              label: '可视化提示',
              child: AppLatexText(
                visualHint,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final suggestions = (data['plot_suggestions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final studentTasks = (data['student_tasks'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scene.isNotEmpty)
          _buildArtifactMetaChip('场景', _chartSceneLabel(scene)),
        if (knowledgePoints.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: knowledgePoints
                .map((item) => _buildArtifactMetaPill(item))
                .toList(),
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
      ],
    );
  }

  Widget _buildCoordinateGraphArtifact(Map<String, dynamic> graph) {
    final title = (graph['title'] ?? '二维坐标辅助图').toString();
    final notes = _coordinateGraphNotes(graph);
    return _buildArtifactInfoTile(
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: CustomPaint(
              painter: _MathCoordinateGraphPainter(graph),
              child: const SizedBox.expand(),
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildArtifactBullet(note),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _coordinateGraphNotes(Map<String, dynamic> graph) {
    final rawItems = [
      ..._graphTextList(graph['legend']),
      ..._graphTextList(graph['student_focus']),
      ..._graphTextList(graph['annotations']),
    ];
    return rawItems
        .map((item) {
          if (item is Map<String, dynamic>) {
            return (item['text'] ?? item['label'] ?? '').toString();
          }
          return item.toString();
        })
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  List<dynamic> _graphTextList(dynamic raw) {
    if (raw is! List<dynamic>) {
      return const [];
    }
    return raw;
  }

  List<String> _artifactStringList(dynamic value) {
    if (value is! List<dynamic>) {
      return const [];
    }
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _artifactMapList(dynamic value) {
    if (value is! List<dynamic>) {
      return const [];
    }
    return value.whereType<Map<String, dynamic>>().toList();
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
    final debugChecklist =
        (data['debug_checklist'] as List<dynamic>? ?? const [])
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
              border: Border.all(
                color: AppPalette.pastelGrey.withValues(alpha: 0.08),
              ),
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
          ...traceSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildArtifactBullet(step),
            ),
          ),
        ],
        if (debugChecklist.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildArtifactSectionTitle('调试清单'),
          const SizedBox(height: 8),
          ...debugChecklist.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildArtifactBullet(item),
            ),
          ),
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

  Widget _buildGeoGebraSceneArtifact({
    required String title,
    required Map<String, dynamic> spec,
  }) {
    final templateId = (spec['template_id'] ?? '').toString().trim();
    final field = spec['field'] is Map ? spec['field'] as Map : const {};
    final particle = spec['particle'] is Map ? spec['particle'] as Map : const {};
    final parameters = spec['parameters'] is Map
        ? (spec['parameters'] as Map).cast<dynamic, dynamic>()
        : const <dynamic, dynamic>{};

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
              _buildArtifactMetaChip('类型', 'GeoGebra 交互'),
              if (templateId.isNotEmpty) _buildArtifactMetaChip('模板', templateId),
              _buildArtifactMetaChip(
                '场区',
                (field['direction_label'] ?? '物理场景').toString(),
              ),
              _buildArtifactMetaChip(
                '粒子',
                (particle['label'] ?? '带电粒子').toString(),
              ),
            ],
          ),
          if (parameters.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: parameters.entries
                  .map(
                    (entry) => _buildArtifactMetaChip(
                      entry.key.toString(),
                      entry.value.toString(),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '后端返回结构化场景参数，App 使用 GeoGebra WebView 渲染交互图；Manim 讲解视频会走后续异步生成链路。',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 13,
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
                    builder: (_) => GeoGebraScenePreviewScreen(
                      title: title,
                      spec: spec,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.open_in_browser_rounded,
                color: AppPalette.almondCream,
              ),
              label: const Text(
                '打开 GeoGebra 交互图',
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

  Widget _buildManimJobArtifact(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString();
    final progress = int.tryParse((data['progress'] ?? 0).toString()) ?? 0;
    final jobId = (data['job_id'] ?? '').toString();
    final error = (data['error'] ?? '').toString();
    final message = (data['message'] ?? '讲解视频正在等待后台生成。').toString();
    return _buildArtifactStatusBox(
      icon: Icons.movie_filter_rounded,
      title: 'Manim 任务：$status',
      message: error.isNotEmpty ? error : '$message 进度 $progress%',
      actionLabel: jobId.isEmpty
          ? null
          : (_isPollingManimJob ? '正在轮询' : '轮询状态'),
      onAction: jobId.isEmpty || _isPollingManimJob
          ? null
          : () => _pollManimJob(jobId),
    );
  }

  Widget _buildManimVideoArtifact({
    required String title,
    required String content,
  }) {
    final parsed = _tryParseArtifactJson('application/json', content);
    final url = parsed == null
        ? content
        : (parsed['url'] ?? parsed['video_url'] ?? '').toString();
    return _buildArtifactStatusBox(
      icon: Icons.play_circle_fill_rounded,
      title: 'Manim 讲解视频',
      message: url.trim().isEmpty ? '视频地址为空。' : '视频已生成，可以打开播放。',
      actionLabel: url.trim().isEmpty ? null : '播放视频',
      onAction: url.trim().isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManimVideoPreviewScreen(
                    title: title,
                    videoUrl: url,
                  ),
                ),
              );
            },
    );
  }

  Widget _buildArtifactStatusBox({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppPalette.almondCream, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppPalette.almondCream,
                    ),
                    label: Text(
                      actionLabel,
                      style: const TextStyle(color: AppPalette.almondCream),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppPalette.almondCream.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        style: const TextStyle(color: AppPalette.textPrimary, fontSize: 12),
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
      case 'probability':
        return '概率事件';
      case 'sequence':
        return '数列递推';
      case 'vector':
        return '向量关系';
      case 'linear_algebra':
        return '线性代数';
      case 'conic':
        return '圆锥曲线';
      case 'calculus':
        return '导数积分';
      case 'algebra':
        return '代数拆解';
      default:
        return scene;
    }
  }
}

class QuestionTextEditorScreen extends StatefulWidget {
  const QuestionTextEditorScreen({
    super.key,
    required this.initialText,
  });

  final String initialText;

  @override
  State<QuestionTextEditorScreen> createState() =>
      _QuestionTextEditorScreenState();
}

class _QuestionTextEditorScreenState extends State<QuestionTextEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    Navigator.of(context).pop(_sanitizeQuestionTextForPreview(_controller.text).trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: AppPalette.night,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          '编辑题干',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveAndClose,
            child: const Text(
              '完成',
              style: TextStyle(
                color: AppPalette.almondCream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: AppSurface(
        topSafe: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Expanded(
              child: AppPanel(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 16,
                    height: 1.65,
                  ),
                  decoration: const InputDecoration(
                    hintText: '在这里修正 OCR 识别结果，支持 LaTeX 公式...',
                    hintStyle: TextStyle(color: AppPalette.textSecondary),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: '完成并查看渲染结果',
                icon: Icons.check_rounded,
                onPressed: _saveAndClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolutionStepPart {
  const _SolutionStepPart(this.text, {this.isFormula = false});

  final String text;
  final bool isFormula;
}

class _MathCoordinateGraphPainter extends CustomPainter {
  const _MathCoordinateGraphPainter(this.graph);

  final Map<String, dynamic> graph;

  static const _curveColor = AppPalette.almondCream;
  static const _axisColor = Color(0x99FFFFFF);
  static const _gridColor = Color(0x1AFFFFFF);
  static const _helperColor = Color(0x99A8F08F);
  static const _pointColor = Color(0xFFFFD59A);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(30, 14, size.width - 42, size.height - 34);
    if (plot.width <= 0 || plot.height <= 0) return;

    final xRange = _range(graph['x_range'], -4, 4);
    final yRange = _range(graph['y_range'], -3, 3);
    final xMin = xRange[0];
    final xMax = xRange[1] == xMin ? xRange[0] + 1 : xRange[1];
    final yMin = yRange[0];
    final yMax = yRange[1] == yMin ? yRange[0] + 1 : yRange[1];

    Offset project(num x, num y) {
      final dx = (x.toDouble() - xMin) / (xMax - xMin);
      final dy = (y.toDouble() - yMin) / (yMax - yMin);
      final px = dx.clamp(0.0, 1.0).toDouble();
      final py = dy.clamp(0.0, 1.0).toDouble();
      return Offset(
        plot.left + px * plot.width,
        plot.bottom - py * plot.height,
      );
    }

    _drawGrid(canvas, plot);
    _drawAxes(canvas, plot, project, xMin, xMax, yMin, yMax);
    _drawLines(canvas, project);
    _drawCurves(canvas, project);
    _drawPoints(canvas, project);
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = plot.left + plot.width * i / 4;
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
  }

  void _drawAxes(
    Canvas canvas,
    Rect plot,
    Offset Function(num x, num y) project,
    double xMin,
    double xMax,
    double yMin,
    double yMax,
  ) {
    final axisPaint = Paint()
      ..color = _axisColor
      ..strokeWidth = 1.2;
    final xAxisY = yMin <= 0 && yMax >= 0 ? project(0, 0).dy : plot.bottom;
    final yAxisX = xMin <= 0 && xMax >= 0 ? project(0, 0).dx : plot.left;
    canvas.drawLine(
      Offset(plot.left, xAxisY),
      Offset(plot.right, xAxisY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(yAxisX, plot.top),
      Offset(yAxisX, plot.bottom),
      axisPaint,
    );
    _drawLabel(canvas, 'x', Offset(plot.right - 8, xAxisY + 4), _axisColor);
    _drawLabel(canvas, 'y', Offset(yAxisX + 5, plot.top), _axisColor);
  }

  void _drawCurves(Canvas canvas, Offset Function(num x, num y) project) {
    final curves = _mapList(graph['curves']);
    for (final curve in curves) {
      final points = _pointList(curve['points']);
      if (points.length < 2) continue;
      final path = Path()
        ..moveTo(
          project(points.first.dx, points.first.dy).dx,
          project(points.first.dx, points.first.dy).dy,
        );
      for (final point in points.skip(1)) {
        final projected = project(point.dx, point.dy);
        path.lineTo(projected.dx, projected.dy);
      }
      final paint = Paint()
        ..color = _curveColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }
  }

  void _drawLines(Canvas canvas, Offset Function(num x, num y) project) {
    final lines = _mapList(graph['lines']);
    for (final line in lines) {
      final from = _offsetFromPair(line['from']);
      final to = _offsetFromPair(line['to']);
      if (from == null || to == null) continue;
      final style = (line['style'] ?? '').toString();
      final paint = Paint()
        ..color = style == 'axis' ? _axisColor : _helperColor
        ..strokeWidth = style == 'axis' ? 1.4 : 1.5;
      final start = project(from.dx, from.dy);
      final end = project(to.dx, to.dy);
      if (style == 'dashed') {
        _drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }
      final label = (line['label'] ?? '').toString();
      if (label.isNotEmpty && label.length <= 8) {
        _drawLabel(
          canvas,
          label,
          Offset((start.dx + end.dx) / 2 + 4, (start.dy + end.dy) / 2 - 12),
          _helperColor,
        );
      }
    }
  }

  void _drawPoints(Canvas canvas, Offset Function(num x, num y) project) {
    final points = _mapList(graph['points']);
    final pointPaint = Paint()..color = _pointColor;
    for (final point in points) {
      final x = _toDouble(point['x']);
      final y = _toDouble(point['y']);
      if (x == null || y == null) continue;
      final offset = project(x, y);
      canvas.drawCircle(offset, 3.5, pointPaint);
      final label = _compactPointLabel((point['label'] ?? '').toString());
      if (label.isNotEmpty) {
        _drawLabel(canvas, label, offset + const Offset(5, -15), _pointColor);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vector = end - start;
    final distance = vector.distance;
    if (distance <= 0) return;
    final direction = vector / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final next = math.min(drawn + 7, distance);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * next,
        paint,
      );
      drawn += 12;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 92);
    painter.paint(canvas, offset);
  }

  String _compactPointLabel(String label) {
    if (label.isEmpty) return '';
    final compact = label.split(RegExp(r'[\s（(≈]')).first.trim();
    if (compact.isEmpty) return '';
    if (compact.length <= 5) return compact;
    return '';
  }

  static List<double> _range(
    dynamic value,
    double fallbackMin,
    double fallbackMax,
  ) {
    if (value is List<dynamic> && value.length >= 2) {
      final minValue = _toDouble(value[0]);
      final maxValue = _toDouble(value[1]);
      if (minValue != null && maxValue != null) {
        return [math.min(minValue, maxValue), math.max(minValue, maxValue)];
      }
    }
    return [fallbackMin, fallbackMax];
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List<dynamic>) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static List<Offset> _pointList(dynamic value) {
    if (value is! List<dynamic>) return const [];
    return value.map(_offsetFromPair).whereType<Offset>().toList();
  }

  static Offset? _offsetFromPair(dynamic value) {
    if (value is! List<dynamic> || value.length < 2) return null;
    final x = _toDouble(value[0]);
    final y = _toDouble(value[1]);
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  bool shouldRepaint(covariant _MathCoordinateGraphPainter oldDelegate) {
    return oldDelegate.graph != graph;
  }
}

String _sanitizeQuestionTextForPreview(String text) {
  if (text.trim().isEmpty || !text.contains(r'$')) {
    return text;
  }

  final buffer = StringBuffer();
  var index = 0;
  while (index < text.length) {
    final start = text.indexOf(r'$', index);
    if (start < 0) {
      buffer.write(text.substring(index));
      break;
    }
    final end = text.indexOf(r'$', start + 1);
    if (end < 0) {
      buffer.write(text.substring(index, start));
      buffer.write(text.substring(start + 1));
      break;
    }

    buffer.write(text.substring(index, start));
    final body = text.substring(start + 1, end);
    if (_looksLikeRealMathSegment(body)) {
      buffer.write(r'$');
      buffer.write(body);
      buffer.write(r'$');
    } else {
      buffer.write(body);
    }
    index = end + 1;
  }

  return buffer.toString();
}

bool _looksLikeRealMathSegment(String text) {
  final body = text.trim();
  if (body.isEmpty) {
    return false;
  }
  if (RegExp(r'[\u4e00-\u9fff]').hasMatch(body)) {
    return false;
  }
  if ('('.allMatches(body).length != ')'.allMatches(body).length ||
      '['.allMatches(body).length != ']'.allMatches(body).length ||
      '{'.allMatches(body).length != '}'.allMatches(body).length) {
    return false;
  }
  return RegExp(r'(\\[A-Za-z]+|[_^=<>+\-*/]|[A-Za-z]\s*\(|\d)').hasMatch(body);
}

