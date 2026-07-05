import 'package:flutter/services.dart';

class GalleryImageItem {
  const GalleryImageItem({
    required this.uri,
    required this.displayName,
    required this.dateMillis,
    this.thumbnailPath,
  });

  final String uri;
  final String displayName;
  final int dateMillis;
  final String? thumbnailPath;

  factory GalleryImageItem.fromJson(Map<dynamic, dynamic> json) {
    final rawThumbnail = json['thumbnailPath']?.toString().trim();
    return GalleryImageItem(
      uri: json['uri']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      dateMillis: int.tryParse((json['dateMillis'] ?? '0').toString()) ?? 0,
      thumbnailPath:
          rawThumbnail == null || rawThumbnail.isEmpty ? null : rawThumbnail,
    );
  }
}

class NativeChannel {
  const NativeChannel._();

  static const MethodChannel _mediaChannel = MethodChannel('zerror/media');

  static Future<List<GalleryImageItem>> listGalleryImages({
    int limit = 200,
  }) async {
    final rawItems = await _mediaChannel.invokeMethod<List<dynamic>>(
      'listGalleryImages',
      {'limit': limit},
    );
    return (rawItems ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(GalleryImageItem.fromJson)
        .where((item) => item.uri.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<String?> copyGalleryImageToCache(String uri) async {
    final path = await _mediaChannel.invokeMethod<String>(
      'copyGalleryImageToCache',
      {'uri': uri},
    );
    final normalized = path?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static Future<String?> pickGalleryImagePath() async {
    final path = await _mediaChannel.invokeMethod<String>(
      'pickGalleryImage',
    );
    final normalized = path?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
