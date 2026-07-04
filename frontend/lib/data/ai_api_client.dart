import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';

class AiApiException implements Exception {
  final String message;
  final int? statusCode;

  const AiApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class SimilarQuestionItem {
  final String prompt;
  final String answerOutline;

  const SimilarQuestionItem({
    required this.prompt,
    required this.answerOutline,
  });

  factory SimilarQuestionItem.fromJson(Map<String, dynamic> json) {
    return SimilarQuestionItem(
      prompt: (json['prompt'] ?? '').toString(),
      answerOutline: (json['answer_outline'] ?? '').toString(),
    );
  }
}

class AnalysisResult {
  final String subject;
  final String sceneBrief;
  final List<String> knowledgePoints;
  final String solutionSummary;
  final List<String> solutionSteps;
  final String mistakeDiagnosis;
  final List<int> reviewSchedule;
  final String reviewFocus;
  final List<SimilarQuestionItem> similarQuestions;
  final List<Map<String, dynamic>> richArtifacts;

  const AnalysisResult({
    required this.subject,
    required this.sceneBrief,
    required this.knowledgePoints,
    required this.solutionSummary,
    required this.solutionSteps,
    required this.mistakeDiagnosis,
    required this.reviewSchedule,
    required this.reviewFocus,
    required this.similarQuestions,
    required this.richArtifacts,
  });

  AnalysisResult copyWith({
    String? subject,
    String? sceneBrief,
    List<String>? knowledgePoints,
    String? solutionSummary,
    List<String>? solutionSteps,
    String? mistakeDiagnosis,
    List<int>? reviewSchedule,
    String? reviewFocus,
    List<SimilarQuestionItem>? similarQuestions,
    List<Map<String, dynamic>>? richArtifacts,
  }) {
    return AnalysisResult(
      subject: subject ?? this.subject,
      sceneBrief: sceneBrief ?? this.sceneBrief,
      knowledgePoints: knowledgePoints ?? this.knowledgePoints,
      solutionSummary: solutionSummary ?? this.solutionSummary,
      solutionSteps: solutionSteps ?? this.solutionSteps,
      mistakeDiagnosis: mistakeDiagnosis ?? this.mistakeDiagnosis,
      reviewSchedule: reviewSchedule ?? this.reviewSchedule,
      reviewFocus: reviewFocus ?? this.reviewFocus,
      similarQuestions: similarQuestions ?? this.similarQuestions,
      richArtifacts: richArtifacts ?? this.richArtifacts,
    );
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final reviewPlan =
        (json['review_plan'] as Map<String, dynamic>?) ?? const {};
    final schedule = (reviewPlan['schedule'] as List<dynamic>? ?? const [])
        .map((item) => int.tryParse(item.toString()) ?? 0)
        .where((item) => item > 0)
        .toList();

    return AnalysisResult(
      sceneBrief: (json['scene_brief'] ?? '').toString(),
      subject: (json['subject'] ?? '未分类').toString(),
      knowledgePoints: (json['knowledge_points'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      solutionSummary: (json['solution_summary'] ?? '').toString(),
      solutionSteps: (json['solution_steps'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      mistakeDiagnosis: (json['mistake_diagnosis'] ?? '').toString(),
      reviewSchedule: schedule,
      reviewFocus: (reviewPlan['focus'] ?? '').toString(),
      similarQuestions:
          (json['similar_questions'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => SimilarQuestionItem.fromJson(
                  _asStringMap(item),
                ),
              )
              .toList(),
      richArtifacts: (json['rich_artifacts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(_asStringMap)
          .toList(),
    );
  }
}

class ImageAnalysisPayload {
  final String extractedText;
  final AnalysisResult analysis;

  const ImageAnalysisPayload({
    required this.extractedText,
    required this.analysis,
  });

  factory ImageAnalysisPayload.fromJson(Map<String, dynamic> json) {
    final ocr = (json['ocr'] as Map<String, dynamic>?) ?? const {};
    return ImageAnalysisPayload(
      extractedText:
          (json['cleaned_question'] ?? ocr['normalized_text'] ?? '').toString(),
      analysis: AnalysisResult.fromJson(json),
    );
  }
}

class ImageAnalysisJob {
  final String jobId;
  final String status;
  final int progress;
  final String message;
  final String error;
  final double createdAt;
  final double updatedAt;
  final ImageAnalysisPayload? result;
  final ImageAnalysisPayload? partialResult;

  const ImageAnalysisJob({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.message,
    required this.error,
    required this.createdAt,
    required this.updatedAt,
    required this.result,
    required this.partialResult,
  });

  bool get hasBasicResult => partialResult != null || result != null;
  bool get isFinished =>
      status == 'completed' || status == 'failed' || status == 'need_retry';
  bool get canRetry => status == 'partial_success' || status == 'need_retry';

  // The UI can show partial_success as "OCR is saved, high-quality explanation
  // is still running". completed is the only state where result should replace
  // the partial card.
  String get displayMessage {
    if (message.trim().isNotEmpty) {
      return message;
    }
    switch (status) {
      case 'pending':
        return '等待解析';
      case 'processing':
        return '解析中';
      case 'partial_success':
        return '已识别题目，正在生成高质量详解';
      case 'completed':
        return '解析完成';
      case 'need_retry':
        return '解析需要重试';
      case 'failed':
        return '解析失败';
    }
    return '后台整理中';
  }

  factory ImageAnalysisJob.fromJson(Map<String, dynamic> json) {
    final rawResult = _asStringMap(json['result']);
    final rawPartial = _asStringMap(json['partial_result']);
    return ImageAnalysisJob(
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      progress: int.tryParse((json['progress'] ?? 0).toString()) ?? 0,
      message: (json['message'] ?? '').toString(),
      error: AiApiClient.friendlyError((json['error'] ?? '').toString()),
      createdAt: double.tryParse((json['created_at'] ?? '0').toString()) ?? 0,
      updatedAt: double.tryParse((json['updated_at'] ?? '0').toString()) ?? 0,
      result:
          rawResult.isEmpty ? null : ImageAnalysisPayload.fromJson(rawResult),
      partialResult:
          rawPartial.isEmpty ? null : ImageAnalysisPayload.fromJson(rawPartial),
    );
  }
}

class PhysicsAnimationPayload {
  final String cleanedQuestion;
  final String sceneBrief;
  final String subject;
  final List<String> knowledgePoints;
  final String solutionSummary;
  final List<String> solutionSteps;

  const PhysicsAnimationPayload({
    required this.cleanedQuestion,
    required this.sceneBrief,
    required this.subject,
    required this.knowledgePoints,
    required this.solutionSummary,
    required this.solutionSteps,
  });

  Map<String, dynamic> toJson() {
    return {
      'cleaned_question': cleanedQuestion,
      'scene_brief': sceneBrief,
      'subject': subject,
      'knowledge_points': knowledgePoints,
      'solution_summary': solutionSummary,
      'solution_steps': solutionSteps,
    };
  }
}

class PhysicsAnimationResult {
  final String subject;
  final Map<String, dynamic>? artifact;
  final bool generated;
  final String reason;

  const PhysicsAnimationResult({
    required this.subject,
    required this.artifact,
    required this.generated,
    required this.reason,
  });

  factory PhysicsAnimationResult.fromJson(Map<String, dynamic> json) {
    final rawArtifact = json['artifact'];
    Map<String, dynamic>? artifact;
    if (rawArtifact is Map<String, dynamic>) {
      artifact = rawArtifact;
    } else if (rawArtifact is Map) {
      artifact = _asStringMap(rawArtifact);
    }

    return PhysicsAnimationResult(
      subject: (json['subject'] ?? '').toString(),
      artifact: artifact,
      generated: json['generated'] == true,
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class ManimRenderJob {
  final String jobId;
  final String status;
  final int progress;
  final String videoUrl;
  final String absoluteVideoUrl;
  final String message;
  final String error;
  final double? updatedAt;
  final Map<String, dynamic> diagnostics;

  const ManimRenderJob({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.videoUrl,
    required this.absoluteVideoUrl,
    required this.message,
    required this.error,
    required this.updatedAt,
    required this.diagnostics,
  });

  bool get isFinished => status == 'succeeded' || status == 'failed';

  factory ManimRenderJob.fromJson(Map<String, dynamic> json) {
    return ManimRenderJob(
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      progress: int.tryParse((json['progress'] ?? 0).toString()) ?? 0,
      videoUrl: (json['video_url'] ?? '').toString(),
      absoluteVideoUrl: (json['absolute_video_url'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      error: (json['error'] ?? '').toString(),
      updatedAt: double.tryParse((json['updated_at'] ?? '').toString()),
      diagnostics: _asStringMap(json['diagnostics']),
    );
  }

  Map<String, dynamic> toArtifactContent() {
    return {
      'job_id': jobId,
      'status': status,
      'progress': progress,
      'video_url': videoUrl,
      'absolute_video_url': absoluteVideoUrl,
      'message': message,
      'error': error,
      'updated_at': updatedAt,
      'diagnostics': diagnostics,
    };
  }
}

class GeneratedPracticeQuestion {
  final String id;
  final String type;
  final String subject;
  final String topic;
  final String stem;
  final List<String> options;
  final String answer;
  final int? answerIndex;
  final String solutionOutline;
  final List<String> solutionSteps;
  final String reasonHint;
  final String difficulty;
  final int estimatedMinutes;
  final List<String> sourceErrorIds;

  const GeneratedPracticeQuestion({
    required this.id,
    required this.type,
    required this.subject,
    required this.topic,
    required this.stem,
    required this.options,
    required this.answer,
    required this.answerIndex,
    required this.solutionOutline,
    required this.solutionSteps,
    required this.reasonHint,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.sourceErrorIds,
  });

  factory GeneratedPracticeQuestion.fromJson(Map<String, dynamic> json) {
    return GeneratedPracticeQuestion(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '简答题').toString(),
      subject: (json['subject'] ?? '').toString(),
      topic: (json['topic'] ?? '').toString(),
      stem: (json['stem'] ?? '').toString(),
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((item) => _normalizeOption(item.toString()))
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      answer: (json['answer'] ?? '').toString(),
      answerIndex: int.tryParse((json['answer_index'] ?? '').toString()),
      solutionOutline: (json['solution_outline'] ?? '').toString(),
      solutionSteps: (json['solution_steps'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      reasonHint: (json['reason_hint'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '中等').toString(),
      estimatedMinutes:
          int.tryParse((json['estimated_minutes'] ?? '').toString()) ?? 4,
      sourceErrorIds: (json['source_error_ids'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'subject': subject,
      'topic': topic,
      'stem': stem,
      'options': options,
      'answer': answer,
      'answer_index': answerIndex,
      'solution_outline': solutionOutline,
      'solution_steps': solutionSteps,
      'reason_hint': reasonHint,
      'difficulty': difficulty,
      'estimated_minutes': estimatedMinutes,
      'source_error_ids': sourceErrorIds,
    };
  }

  Map<String, dynamic> toQuizMap() {
    final isChoice = options.isNotEmpty && answerIndex != null;
    return {
      'type': type,
      'subject': subject.isEmpty ? '综合' : subject,
      'topic': topic.isEmpty ? '错题回收' : topic,
      'content': stem,
      'options': options,
      'correctIndex': answerIndex,
      'correctAnswer': answer,
      'keywords': _answerKeywords(answer),
      'reasonHint': reasonHint.isEmpty ? '组卷练习中暴露出薄弱点' : reasonHint,
      'analysisHint': _combinedAnalysis(),
      'answerType': isChoice ? 'choice' : 'text',
      'difficulty': difficulty,
      'estimatedMinutes': estimatedMinutes,
      'sourceErrorIds': sourceErrorIds,
    };
  }

  List<String> _answerKeywords(String text) {
    final chunks = text
        .split(RegExp(r'[\s,，。；;、]+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 2)
        .take(4)
        .toList();
    return chunks.isEmpty ? [text.trim()] : chunks;
  }

  String _combinedAnalysis() {
    final parts = <String>[
      if (solutionOutline.trim().isNotEmpty) solutionOutline.trim(),
      ...solutionSteps
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    ];
    return parts.isEmpty ? answer : parts.join('\n');
  }

  static String _normalizeOption(String option) {
    final cleaned = option.trim().replaceFirst(
          RegExp(
              r'^(?:[\(\[（【]?\s*[A-Fa-f]\s*[\)\]）】]?[\.\、．:：]?\s+|[A-Fa-f][\.\、．:：]\s*)'),
          '',
        );
    return cleaned.trim().isEmpty ? option.trim() : cleaned.trim();
  }
}

class PracticePaperResult {
  final String title;
  final String subtitle;
  final List<String> subjectFocus;
  final List<String> topicFocus;
  final String strategyLabel;
  final int estimatedMinutes;
  final String handoutOverview;
  final List<String> learningTargets;
  final List<String> warmupNotes;
  final List<GeneratedPracticeQuestion> questions;
  final List<String> answerKey;
  final String printableHtml;

  const PracticePaperResult({
    required this.title,
    required this.subtitle,
    required this.subjectFocus,
    required this.topicFocus,
    required this.strategyLabel,
    required this.estimatedMinutes,
    required this.handoutOverview,
    required this.learningTargets,
    required this.warmupNotes,
    required this.questions,
    required this.answerKey,
    required this.printableHtml,
  });

  factory PracticePaperResult.fromJson(Map<String, dynamic> json) {
    return PracticePaperResult(
      title: (json['title'] ?? '专题针对性练习').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      subjectFocus: _stringList(json['subject_focus']),
      topicFocus: _stringList(json['topic_focus']),
      strategyLabel: (json['strategy_label'] ?? '').toString(),
      estimatedMinutes:
          int.tryParse((json['estimated_minutes'] ?? '').toString()) ?? 20,
      handoutOverview: (json['handout_overview'] ?? '').toString(),
      learningTargets: _stringList(json['learning_targets']),
      warmupNotes: _stringList(json['warmup_notes']),
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => GeneratedPracticeQuestion.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
      answerKey: _stringList(json['answer_key']),
      printableHtml: (json['printable_html'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'subject_focus': subjectFocus,
      'topic_focus': topicFocus,
      'strategy_label': strategyLabel,
      'estimated_minutes': estimatedMinutes,
      'handout_overview': handoutOverview,
      'learning_targets': learningTargets,
      'warmup_notes': warmupNotes,
      'questions': questions.map((item) => item.toJson()).toList(),
      'answer_key': answerKey,
      'printable_html': printableHtml,
    };
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}

class LectureHandoutSectionResult {
  final String title;
  final String body;
  final List<String> bullets;

  const LectureHandoutSectionResult({
    required this.title,
    required this.body,
    required this.bullets,
  });

  factory LectureHandoutSectionResult.fromJson(Map<String, dynamic> json) {
    return LectureHandoutSectionResult(
      title: (json['title'] ?? '知识梳理').toString(),
      body: (json['body'] ?? '').toString(),
      bullets: _asStringList(json['bullets']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'bullets': bullets,
    };
  }
}

class LectureHandoutResult {
  final String title;
  final String subtitle;
  final String subject;
  final String topic;
  final String overview;
  final List<LectureHandoutSectionResult> sections;
  final List<String> keyPoints;
  final List<String> formulaCards;
  final List<String> methodNotes;
  final List<String> commonTraps;
  final List<String> recapChecklist;
  final String printableHtml;
  final String rawModelOutput;

  const LectureHandoutResult({
    required this.title,
    required this.subtitle,
    required this.subject,
    required this.topic,
    required this.overview,
    required this.sections,
    required this.keyPoints,
    required this.formulaCards,
    required this.methodNotes,
    required this.commonTraps,
    required this.recapChecklist,
    required this.printableHtml,
    required this.rawModelOutput,
  });

  factory LectureHandoutResult.fromJson(Map<String, dynamic> json) {
    return LectureHandoutResult(
      title: (json['title'] ?? '知识讲义').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      topic: (json['topic'] ?? '').toString(),
      overview: (json['overview'] ?? '').toString(),
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => LectureHandoutSectionResult.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
      keyPoints: _asStringList(json['key_points']),
      formulaCards: _asStringList(json['formula_cards']),
      methodNotes: _asStringList(json['method_notes']),
      commonTraps: _asStringList(json['common_traps']),
      recapChecklist: _asStringList(json['recap_checklist']),
      printableHtml: (json['printable_html'] ?? '').toString(),
      rawModelOutput: (json['raw_model_output'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'subject': subject,
      'topic': topic,
      'overview': overview,
      'sections': sections.map((item) => item.toJson()).toList(),
      'key_points': keyPoints,
      'formula_cards': formulaCards,
      'method_notes': methodNotes,
      'common_traps': commonTraps,
      'recap_checklist': recapChecklist,
      'printable_html': printableHtml,
      'raw_model_output': rawModelOutput,
    };
  }
}

class LectureHandoutJob {
  final String jobId;
  final String status;
  final int progress;
  final String message;
  final String error;
  final double? createdAt;
  final double? updatedAt;
  final LectureHandoutResult? result;

  const LectureHandoutJob({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.message,
    required this.error,
    required this.createdAt,
    required this.updatedAt,
    required this.result,
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isActive => status == 'pending' || status == 'processing';

  factory LectureHandoutJob.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'];
    return LectureHandoutJob(
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      progress: int.tryParse((json['progress'] ?? '').toString()) ?? 0,
      message: (json['message'] ?? '').toString(),
      error: (json['error'] ?? '').toString(),
      createdAt: double.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: double.tryParse((json['updated_at'] ?? '').toString()),
      result: resultJson is Map<String, dynamic>
          ? LectureHandoutResult.fromJson(resultJson)
          : resultJson is Map
              ? LectureHandoutResult.fromJson(
                  resultJson.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : null,
    );
  }
}

class AssistantReplySection {
  final String title;
  final String body;
  final List<String> bullets;

  const AssistantReplySection({
    required this.title,
    required this.body,
    required this.bullets,
  });

  factory AssistantReplySection.fromJson(Map<String, dynamic> json) {
    return AssistantReplySection(
      title: (json['title'] ?? '助教建议').toString(),
      body: (json['body'] ?? '').toString(),
      bullets: _asStringList(json['bullets']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'bullets': bullets,
    };
  }
}

class AssistantChatReply {
  final String mode;
  final String title;
  final String summary;
  final List<AssistantReplySection> sections;
  final List<String> linkedKnowledge;
  final List<String> followUpPrompts;
  final int sprintMinutes;
  final bool fallback;
  final String rawModelOutput;

  const AssistantChatReply({
    required this.mode,
    required this.title,
    required this.summary,
    required this.sections,
    required this.linkedKnowledge,
    required this.followUpPrompts,
    required this.sprintMinutes,
    required this.fallback,
    required this.rawModelOutput,
  });

  factory AssistantChatReply.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final sections = rawSections is List
        ? rawSections
            .whereType<Map>()
            .map(
              (item) => AssistantReplySection.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList(growable: false)
        : const <AssistantReplySection>[];

    return AssistantChatReply(
      mode: (json['mode'] ?? 'quick_answer').toString(),
      title: (json['title'] ?? 'AI 助教').toString(),
      summary: (json['summary'] ?? '').toString(),
      sections: sections,
      linkedKnowledge: _asStringList(json['linked_knowledge']),
      followUpPrompts: _asStringList(json['follow_up_prompts']),
      sprintMinutes:
          int.tryParse((json['sprint_minutes'] ?? '0').toString()) ?? 0,
      fallback: json['fallback'] == true,
      rawModelOutput: (json['raw_model_output'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson({bool includeRawModelOutput = true}) {
    return {
      'mode': mode,
      'title': title,
      'summary': summary,
      'sections': sections.map((item) => item.toJson()).toList(growable: false),
      'linked_knowledge': linkedKnowledge,
      'follow_up_prompts': followUpPrompts,
      'sprint_minutes': sprintMinutes,
      'fallback': fallback,
      'raw_model_output': includeRawModelOutput ? rawModelOutput : '',
    };
  }
}

class AiApiClient {
  const AiApiClient();

  Future<String> extractTextFromImage(String imagePath) async {
    final request =
        http.MultipartRequest('POST', Uri.parse(AppConstants.ocrEndpoint))
          ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    late final http.Response response;
    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 150),
          );
      response = await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 150),
      );
    } on TimeoutException catch (_) {
      throw const AiApiException('AI 解析耗时过长，请稍后重试；题目图片可以先保留在后台整理中。');
    } on http.ClientException catch (_) {
      throw const AiApiException('网络连接中断了，请稍后重试；如果连续失败，可以先用手动整理保存题目。');
    }
    final payload = _decodeJson(response);

    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }

    final normalizedText = (payload['normalized_text'] ?? '').toString().trim();
    if (normalizedText.isEmpty) {
      throw const AiApiException('OCR 未返回可用文本，请更换更清晰的图片后重试。');
    }
    return normalizedText;
  }

  Future<AnalysisResult> analyzeQuestion({
    required String questionText,
    required String subject,
    required String wrongReasonHint,
  }) async {
    final response = await http.post(
      Uri.parse(AppConstants.analysisEndpoint),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'question_text': questionText,
        'subject': subject,
        'user_answer': '',
        'wrong_reason_hint': wrongReasonHint,
        'enable_subject_extensions': true,
      }),
    );

    final payload = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }

    return AnalysisResult.fromJson(payload);
  }

  Future<ImageAnalysisPayload> analyzeImage({
    required String imagePath,
    String subject = '未分类',
    String wrongReasonHint = '',
    bool enableSubjectExtensions = true,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.apiBaseUrl}/api/v1/analysis/image'),
    )
      ..fields['subject'] = subject
      ..fields['user_answer'] = ''
      ..fields['wrong_reason_hint'] = wrongReasonHint
      ..fields['enable_subject_extensions'] =
          enableSubjectExtensions ? 'true' : 'false'
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    late final http.Response response;
    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 150),
          );
      response = await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 150),
      );
    } on TimeoutException catch (_) {
      throw const AiApiException('AI 解析耗时过长，请稍后重试；题目图片可以先保留在后台整理中。');
    } on http.ClientException catch (_) {
      throw const AiApiException('网络连接中断了，请稍后重试；如果连续失败，可以先用手动整理保存题目。');
    }
    final payload = _decodeJson(response);

    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }

    final result = ImageAnalysisPayload.fromJson(payload);
    if (result.extractedText.trim().isEmpty) {
      throw const AiApiException('图片解析成功，但 OCR 未提取出题目文字。');
    }
    return result;
  }

  Future<ImageAnalysisJob> createImageAnalysisJob({
    required String imagePath,
    String? clientJobId,
    String subject = '未分类',
    String wrongReasonHint = '',
    bool enableSubjectExtensions = true,
  }) async {
    // New batch-photo flow: create a server job quickly, then poll
    // fetchImageAnalysisJob until partial_result/result appears.
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConstants.imageAnalysisJobsEndpoint),
    )
      ..fields['subject'] = subject
      ..fields['user_answer'] = ''
      ..fields['wrong_reason_hint'] = wrongReasonHint
      ..fields['enable_subject_extensions'] =
          enableSubjectExtensions ? 'true' : 'false'
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));
    final normalizedClientJobId = clientJobId?.trim();
    if (normalizedClientJobId != null && normalizedClientJobId.isNotEmpty) {
      request.fields['client_job_id'] = normalizedClientJobId;
    }

    final response = await _sendMultipart(
      request,
      timeout: const Duration(seconds: 45),
    );
    final payload = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }
    return ImageAnalysisJob.fromJson(payload);
  }

  Future<ImageAnalysisJob> fetchImageAnalysisJob(String jobId) async {
    final response = await http
        .get(Uri.parse(AppConstants.imageAnalysisJobEndpoint(jobId)))
        .timeout(const Duration(seconds: 20));
    final payload = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }
    return ImageAnalysisJob.fromJson(payload);
  }

  Future<ImageAnalysisJob> retryImageAnalysisJob(String jobId) async {
    final response = await http
        .post(Uri.parse(AppConstants.imageAnalysisJobRetryEndpoint(jobId)))
        .timeout(const Duration(seconds: 20));
    final payload = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }
    return ImageAnalysisJob.fromJson(payload);
  }

  Future<PhysicsAnimationResult> generatePhysicsAnimation(
    PhysicsAnimationPayload payload,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConstants.apiBaseUrl}/api/v1/analysis/physics-animation'),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(payload.toJson()),
    );

    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
      );
    }

    return PhysicsAnimationResult.fromJson(decoded);
  }

  Future<ManimRenderJob> fetchManimJob(String jobId) async {
    final response = await http.get(
      Uri.parse(AppConstants.manimJobEndpoint(jobId)),
    );

    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
      );
    }

    return ManimRenderJob.fromJson(decoded);
  }

  Future<PracticePaperResult> generatePracticePaper({
    required List<Map<String, dynamic>> errors,
    required int questionCount,
    required List<String> selectedSubjects,
    required String strategyLabel,
  }) async {
    final response = await http.post(
      Uri.parse(AppConstants.practicePaperEndpoint),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'errors': errors,
        'question_count': questionCount,
        'selected_subjects': selectedSubjects,
        'strategy_label': strategyLabel,
        'include_answer_key': true,
      }),
    );

    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      if (response.statusCode == 404) {
        throw AiApiException(
          '组卷接口未找到，请确认 App 正在连接已更新并重启后的后端：${AppConstants.practicePaperEndpoint}',
          statusCode: response.statusCode,
        );
      }
      throw AiApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
      );
    }

    return PracticePaperResult.fromJson(decoded);
  }

  Future<LectureHandoutJob> createLectureHandoutJob({
    required String prompt,
    required String subject,
    required String topic,
    String? clientJobId,
  }) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(AppConstants.lectureHandoutJobsEndpoint),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'prompt': prompt,
              'subject': subject,
              'topic': topic,
              if (clientJobId != null && clientJobId.trim().isNotEmpty)
                'client_job_id': clientJobId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 35));
    } on TimeoutException catch (_) {
      throw const AiApiException('讲义任务提交暂时较慢，请稍后重试。');
    } on http.ClientException catch (_) {
      throw const AiApiException('网络连接中断，讲义任务暂时无法提交。');
    }

    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      if (response.statusCode == 404) {
        throw AiApiException(
          '讲义生成接口未找到，请确认 App 连接的是已更新后端：${AppConstants.lectureHandoutJobsEndpoint}',
          statusCode: response.statusCode,
        );
      }
      throw AiApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
      );
    }

    return LectureHandoutJob.fromJson(decoded);
  }

  Future<LectureHandoutJob> fetchLectureHandoutJob(String jobId) async {
    late final http.Response response;
    try {
      response = await http
          .get(Uri.parse(AppConstants.lectureHandoutJobEndpoint(jobId)))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (_) {
      throw const AiApiException('讲义进度刷新暂时较慢，请稍后重试。');
    } on http.ClientException catch (_) {
      throw const AiApiException('网络连接中断，讲义进度暂时无法刷新。');
    }
    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
      );
    }
    return LectureHandoutJob.fromJson(decoded);
  }

  Future<LectureHandoutJob> retryLectureHandoutJob(String jobId) async {
    late final http.Response response;
    try {
      response = await http
          .post(Uri.parse(AppConstants.lectureHandoutJobRetryEndpoint(jobId)))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (_) {
      throw const AiApiException('讲义重试提交暂时较慢，请稍后再试。');
    } on http.ClientException catch (_) {
      throw const AiApiException('网络连接中断，讲义重试暂时无法提交。');
    }
    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
      );
    }
    return LectureHandoutJob.fromJson(decoded);
  }

  Future<AssistantChatReply> askAssistant({
    required String message,
    required String mode,
    required Map<String, dynamic> context,
    required List<Map<String, dynamic>> errors,
  }) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(AppConstants.assistantChatEndpoint),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'message': message,
              'mode': mode,
              'context': context,
              'errors': errors,
            }),
          )
          .timeout(const Duration(seconds: 75));
    } on TimeoutException catch (_) {
      throw const AiApiException('AI 助教响应暂时较慢，我先帮你保留这个问题。');
    } on http.ClientException catch (_) {
      throw const AiApiException('网络连接中断，AI 助教暂时连不上服务器。');
    }

    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      if (response.statusCode == 404) {
        throw AiApiException(
          'AI 助教接口未找到，请确认 App 连接的是已更新后端：${AppConstants.assistantChatEndpoint}',
          statusCode: response.statusCode,
        );
      }
      throw AiApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
      );
    }

    return AssistantChatReply.fromJson(decoded);
  }

  Future<void> retainManimArtifacts(
    Iterable<Map<String, dynamic>> artifacts,
  ) async {
    await _postManimArtifactLifecycle(
      endpoint: AppConstants.manimRetainEndpoint,
      artifacts: artifacts,
      swallowErrors: false,
    );
  }

  Future<void> cleanupManimArtifacts(
    Iterable<Map<String, dynamic>> artifacts,
  ) async {
    await _postManimArtifactLifecycle(
      endpoint: AppConstants.manimCleanupEndpoint,
      artifacts: artifacts,
      swallowErrors: true,
    );
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return const {};
    }

    final decodedBody = utf8.decode(response.bodyBytes);
    try {
      final dynamic parsed = jsonDecode(decodedBody);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      if (parsed is List) {
        return <String, dynamic>{'data': parsed};
      }
      return <String, dynamic>{'data': parsed.toString()};
    } catch (_) {
      return <String, dynamic>{'message': decodedBody};
    }
  }

  Future<http.Response> _sendMultipart(
    http.MultipartRequest request, {
    required Duration timeout,
  }) async {
    try {
      final streamedResponse = await request.send().timeout(timeout);
      return await http.Response.fromStream(streamedResponse).timeout(timeout);
    } on TimeoutException catch (_) {
      throw const AiApiException('AI 解析暂时较慢，已保留题目基础信息，可稍后重新生成详解。');
    } on http.ClientException catch (_) {
      throw const AiApiException('网络连接中断，请检查网络后重试。');
    }
  }

  Future<void> _postManimArtifactLifecycle({
    required String endpoint,
    required Iterable<Map<String, dynamic>> artifacts,
    required bool swallowErrors,
  }) async {
    final references = _manimArtifactReferences(artifacts);
    if (references.jobIds.isEmpty && references.videoUrls.isEmpty) {
      return;
    }
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'job_ids': references.jobIds.toList(growable: false),
              'video_urls': references.videoUrls.toList(growable: false),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400 && !swallowErrors) {
        throw AiApiException(_extractErrorMessage(_decodeJson(response)));
      }
    } catch (error) {
      if (!swallowErrors) {
        rethrow;
      }
    }
  }

  ({Set<String> jobIds, Set<String> videoUrls}) _manimArtifactReferences(
    Iterable<Map<String, dynamic>> artifacts,
  ) {
    final jobIds = <String>{};
    final videoUrls = <String>{};
    for (final artifact in artifacts) {
      final type = (artifact['artifact_type'] ?? '').toString();
      if (type != 'manim_job' && type != 'manim_video') {
        continue;
      }
      final content = _artifactContentMap(artifact['content']);
      final jobId = (content['job_id'] ?? artifact['job_id'] ?? '').toString();
      if (jobId.trim().isNotEmpty) {
        jobIds.add(jobId.trim());
      }
      for (final key in const ['video_url', 'absolute_video_url', 'url']) {
        final value = (content[key] ?? artifact[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          videoUrls.add(value);
        }
      }
      final rawContent = artifact['content'];
      if (type == 'manim_video' && rawContent is String) {
        final trimmed = rawContent.trim();
        if (trimmed.startsWith('http') || trimmed.startsWith('/static/')) {
          videoUrls.add(trimmed);
        }
      }
    }
    return (jobIds: jobIds, videoUrls: videoUrls);
  }

  Map<String, dynamic> _artifactContentMap(dynamic content) {
    if (content is Map<String, dynamic>) {
      return content;
    }
    if (content is Map) {
      return _asStringMap(content);
    }
    if (content is String && content.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(content);
        return _asStringMap(parsed);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  String _extractErrorMessage(
    Map<String, dynamic> payload, {
    String fallback = '请求失败，请稍后重试。',
  }) {
    for (final key in const ['detail', 'message', 'msg', 'error']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return friendlyError(value);
      }
    }

    final nested = _asStringMap(payload['data']);
    if (nested.isNotEmpty) {
      for (final key in const ['detail', 'message', 'msg', 'error']) {
        final value = nested[key];
        if (value is String && value.trim().isNotEmpty) {
          return friendlyError(value);
        }
      }
    }

    return friendlyError(fallback);
  }

  static String friendlyError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('clientexception') ||
        lower.contains('connection abort') ||
        lower.contains('connection reset') ||
        lower.contains('socket')) {
      return '网络连接中断，请检查网络后重试。';
    }
    if (lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('read timed out') ||
        lower.contains('502')) {
      return 'AI 解析暂时较慢，已保留题目基础信息，可稍后重新生成详解。';
    }
    if (message.contains('vivo') || message.contains('上游')) {
      return 'AI 服务暂时繁忙，可稍后重新生成详解。';
    }
    return message.trim().isEmpty ? '请求失败，请稍后重试。' : message;
  }
}
