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

  static String get ocrEndpoint => '$apiBaseUrl/api/v1/ocr/extract';
  static String get analysisEndpoint => '$apiBaseUrl/api/v1/analysis/text';
}
