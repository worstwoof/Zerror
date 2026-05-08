import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _defaultCloudApiBaseUrl = 'http://101.35.214.120';

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return _defaultCloudApiBaseUrl;
    }
    return _defaultCloudApiBaseUrl;
  }

  static String snapshotStorageKey(String? syncUserId) {
    final scopedKey = (syncUserId == null || syncUserId.trim().isEmpty)
        ? 'guest'
        : Uri.encodeComponent(syncUserId.trim());
    return 'app_snapshot_v2_$scopedKey';
  }

  static String get registerEndpoint => '$apiBaseUrl/api/v1/auth/register';
  static String get loginEndpoint => '$apiBaseUrl/api/v1/auth/login';
  static String get logoutEndpoint => '$apiBaseUrl/api/v1/auth/logout';
  static String get meEndpoint => '$apiBaseUrl/api/v1/auth/me';
  static String get ocrEndpoint => '$apiBaseUrl/api/v1/ocr/extract';
  static String get analysisEndpoint => '$apiBaseUrl/api/v1/analysis/text';
  static String get imageAnalysisJobsEndpoint =>
      '$apiBaseUrl/api/v1/analysis/image/jobs';
  static String imageAnalysisJobEndpoint(String jobId) =>
      '$imageAnalysisJobsEndpoint/${Uri.encodeComponent(jobId)}';
  static String imageAnalysisJobRetryEndpoint(String jobId) =>
      '${imageAnalysisJobEndpoint(jobId)}/retry';
  static String get manimRenderEndpoint => '$apiBaseUrl/api/v1/render/manim';
  static String manimJobEndpoint(String jobId) =>
      '$apiBaseUrl/api/v1/render/manim/${Uri.encodeComponent(jobId)}';
  static String get fileUploadEndpoint => '$apiBaseUrl/api/v1/files/upload';
  static String appStateEndpoint(String syncUserId) =>
      '$apiBaseUrl/api/v1/app-state/${Uri.encodeComponent(syncUserId)}';
}
