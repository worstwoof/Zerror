import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';

class FileUploadException implements Exception {
  const FileUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UploadedFilePayload {
  const UploadedFilePayload({
    required this.objectKey,
    required this.fileUrl,
    required this.contentType,
    required this.sizeBytes,
  });

  final String objectKey;
  final String fileUrl;
  final String contentType;
  final int sizeBytes;

  factory UploadedFilePayload.fromJson(Map<String, dynamic> json) {
    return UploadedFilePayload(
      objectKey: (json['object_key'] ?? '').toString(),
      fileUrl: (json['file_url'] ?? '').toString(),
      contentType: (json['content_type'] ?? '').toString(),
      sizeBytes: int.tryParse((json['size_bytes'] ?? '0').toString()) ?? 0,
    );
  }
}

class FileUploadClient {
  const FileUploadClient();

  Future<UploadedFilePayload> uploadFile({
    required String filePath,
    required String category,
    String? syncUserId,
    String? authToken,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConstants.fileUploadEndpoint),
    )
      ..fields['category'] = category
      ..fields['sync_user_id'] = syncUserId ?? 'anonymous'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    if (authToken != null && authToken.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final payload = _decodeJson(response);

    if (response.statusCode >= 400) {
      throw FileUploadException(_extractErrorMessage(payload));
    }

    final result = UploadedFilePayload.fromJson(payload);
    if (result.fileUrl.trim().isEmpty) {
      throw const FileUploadException('File upload succeeded but file URL is empty.');
    }
    return result;
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
      return <String, dynamic>{'data': parsed};
    } catch (_) {
      return <String, dynamic>{'message': decodedBody};
    }
  }

  String _extractErrorMessage(Map<String, dynamic> payload) {
    for (final key in const ['detail', 'message', 'msg', 'error']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return 'File upload failed. Please try again.';
  }
}
