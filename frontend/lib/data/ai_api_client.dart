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
    final reviewPlan = (json['review_plan'] as Map<String, dynamic>?) ?? const {};
    final schedule = (reviewPlan['schedule'] as List<dynamic>? ?? const [])
        .map((item) => int.tryParse(item.toString()) ?? 0)
        .where((item) => item > 0)
        .toList();

    return AnalysisResult(
      subject: (json['subject'] ?? '通用').toString(),
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
      similarQuestions: (json['similar_questions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SimilarQuestionItem.fromJson)
          .toList(),
      richArtifacts: (json['rich_artifacts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

class AiApiClient {
  const AiApiClient();

  Future<String> extractTextFromImage(String imagePath) async {
    final request = http.MultipartRequest('POST', Uri.parse(AppConstants.ocrEndpoint))
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final payload = _decodeJson(response);

    if (response.statusCode >= 400) {
      throw AiApiException(_extractErrorMessage(payload));
    }

    final normalizedText = (payload['normalized_text'] ?? '').toString().trim();
    if (normalizedText.isEmpty) {
      throw const AiApiException('OCR 没有返回可用文本。');
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

  Map<String, dynamic> _decodeJson(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return const {};
    }
    final decodedBody = utf8.decode(response.bodyBytes);
    final dynamic parsed = jsonDecode(decodedBody);
    if (parsed is Map<String, dynamic>) {
      return parsed;
    }
    throw const AiApiException('接口返回的不是有效 JSON 对象。');
  }

  String _extractErrorMessage(Map<String, dynamic> payload) {
    final detail = payload['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }
    return '请求失败，请稍后重试。';
  }
}
