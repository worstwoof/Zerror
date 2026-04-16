import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/auth_session.dart';
import '../core/constants.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthApiClient {
  const AuthApiClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _httpClient => _client ?? http.Client();

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse(AppConstants.registerEndpoint),
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'username': username,
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));

    return _parseAuthResponse(response, fallbackMessage: 'Registration failed.');
  }

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse(AppConstants.loginEndpoint),
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identifier': identifier,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));

    return _parseAuthResponse(response, fallbackMessage: 'Login failed.');
  }

  Future<void> logout(String token) async {
    final response = await _httpClient
        .post(
          Uri.parse(AppConstants.logoutEndpoint),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode >= 400) {
      final payload = _decodeJson(response);
      throw AuthApiException(
        _extractErrorMessage(payload, fallback: 'Logout failed.'),
      );
    }
  }

  AuthSession _parseAuthResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final payload = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw AuthApiException(
        _extractErrorMessage(payload, fallback: fallbackMessage),
      );
    }

    final session = AuthSession.fromJson(payload);
    if (session.token.isEmpty || session.syncUserId.isEmpty) {
      throw AuthApiException(fallbackMessage);
    }
    return session;
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
}
