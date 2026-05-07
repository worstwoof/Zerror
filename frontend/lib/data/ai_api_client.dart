import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';

class AiApiException implements Exception {
  final String message;

  const AiApiException(this.message);

  @override
  String toString() => message;
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
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
      richArtifacts: (json['rich_artifacts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) =>
              item.map((key, value) => MapEntry(key.toString(), value)))
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
      artifact = rawArtifact.map(
        (key, value) => MapEntry(key.toString(), value),
      );
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
      diagnostics: _staticAsMap(json['diagnostics']),
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

  static Map<String, dynamic> _staticAsMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const <String, dynamic>{};
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
      throw AiApiException(_extractErrorMessage(payload));
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
      throw AiApiException(_extractErrorMessage(payload));
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
      throw AiApiException(_extractErrorMessage(payload));
    }

    final result = ImageAnalysisPayload.fromJson(payload);
    if (result.extractedText.trim().isEmpty) {
      throw const AiApiException('图片解析成功，但 OCR 未提取出题目文字。');
    }
    return result;
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
      throw AiApiException(_extractErrorMessage(decoded));
    }

    return PhysicsAnimationResult.fromJson(decoded);
  }

  Future<ManimRenderJob> fetchManimJob(String jobId) async {
    final response = await http.get(
      Uri.parse(AppConstants.manimJobEndpoint(jobId)),
    );

    final decoded = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AiApiException(_extractErrorMessage(decoded));
    }

    return ManimRenderJob.fromJson(decoded);
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

  String _extractErrorMessage(
    Map<String, dynamic> payload, {
    String fallback = '请求失败，请稍后重试。',
  }) {
    for (final key in const ['detail', 'message', 'msg', 'error']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    final nested = _asMap(payload['data']);
    if (nested.isNotEmpty) {
      for (final key in const ['detail', 'message', 'msg', 'error']) {
        final value = nested[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    return fallback;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const <String, dynamic>{};
  }
}
