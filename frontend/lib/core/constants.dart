import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _defaultCloudApiBaseUrl = 'http://101.35.214.120';
  static const String _defaultSyncUserId = 'zerror_001';

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _syncUserIdOverride = String.fromEnvironment(
    'APP_SYNC_USER_ID',
    defaultValue: _defaultSyncUserId,
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

  static String get appSyncUserId => _syncUserIdOverride;

  static String get ocrEndpoint => '$apiBaseUrl/api/v1/ocr/extract';
  static String get analysisEndpoint => '$apiBaseUrl/api/v1/analysis/text';
  static String get fileUploadEndpoint => '$apiBaseUrl/api/v1/files/upload';
  static String appStateEndpoint(String syncUserId) =>
      '$apiBaseUrl/api/v1/app-state/${Uri.encodeComponent(syncUserId)}';
}
