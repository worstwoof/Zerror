import 'package:flutter/services.dart';

class NativeChannel {
  const NativeChannel._();

  static const MethodChannel _mediaChannel = MethodChannel('zerror/media');

  static Future<String?> pickGalleryImagePath() async {
    final path = await _mediaChannel.invokeMethod<String>(
      'pickGalleryImage',
    );
    final normalized = path?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
