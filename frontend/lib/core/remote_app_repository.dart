import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_repository.dart';
import 'constants.dart';

class RemoteAppRepositoryException implements Exception {
  const RemoteAppRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RemoteAppRepository implements AppRepository {
  RemoteAppRepository({
    http.Client? client,
    String? syncUserId,
  })  : _client = client ?? http.Client(),
        _syncUserId = syncUserId ?? AppConstants.appSyncUserId;

  final http.Client _client;
  final String _syncUserId;

  @override
  Future<AppPersistenceSnapshot?> loadSnapshot() async {
    final response = await _client
        .get(
          Uri.parse(AppConstants.appStateEndpoint(_syncUserId)),
          headers: const {
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) {
      return null;
    }

    final payload = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw RemoteAppRepositoryException(
        _extractErrorMessage(payload, fallback: 'Failed to load cloud snapshot.'),
      );
    }

    final snapshotJson = _asMap(payload['snapshot']);
    if (snapshotJson.isEmpty) {
      return null;
    }
    return AppPersistenceSnapshot.fromJson(snapshotJson);
  }

  @override
  Future<void> saveSnapshot(AppPersistenceSnapshot snapshot) async {
    final response = await _client
        .put(
          Uri.parse(AppConstants.appStateEndpoint(_syncUserId)),
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'snapshot': snapshot.toJson(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode >= 400) {
      final payload = _decodeJson(response);
      throw RemoteAppRepositoryException(
        _extractErrorMessage(payload, fallback: 'Failed to save cloud snapshot.'),
      );
    }
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

  String _extractErrorMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    for (final key in const ['detail', 'message', 'msg', 'error']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
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
