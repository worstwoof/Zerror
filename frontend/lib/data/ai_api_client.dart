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
        return '待解析';
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
