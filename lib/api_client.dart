import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'env.dart';
import 'session_store.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<Object?> get(
    String path, {
    Map<String, Object?> query = const {},
    bool authorized = true,
  }) {
    return _send('GET', path, query: query, authorized: authorized);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authorized = false,
  }) async {
    final response = await _send('POST', path, body: body, authorized: authorized);
    if (response is Map<String, dynamic>) return response;
    throw ApiException('Unexpected server response.');
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    bool authorized = true,
  }) async {
    final response = await _send('PATCH', path, body: body, authorized: authorized);
    if (response is Map<String, dynamic>) return response;
    throw ApiException('Unexpected server response.');
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool authorized = true,
  }) async {
    final response = await _send('PUT', path, body: body, authorized: authorized);
    if (response is Map<String, dynamic>) return response;
    throw ApiException('Unexpected server response.');
  }

  Future<void> delete(String path, {bool authorized = true}) async {
    await _send('DELETE', path, authorized: authorized);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, Object?> query = const {},
    bool authorized = true,
  }) async {
    final uriPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('${AppEnv.apiBaseUrl}$uriPath');
    final cleanQuery = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null || value.toString().trim().isEmpty) continue;
      cleanQuery[entry.key] = value.toString();
    }
    final uri = cleanQuery.isEmpty ? base : base.replace(queryParameters: cleanQuery);
    final request = await _client.openUrl(method, uri).timeout(const Duration(seconds: 20));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

    final token = SessionStore.current?.access;
    if (authorized && token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    if (body != null) request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 30));
    final raw = await response.transform(utf8.decoder).join();
    final decoded = _decode(raw);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(decoded, response.statusCode));
    }

    return decoded;
  }

  Object? _decode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String _errorMessage(Object? decoded, int statusCode) {
    if (decoded is String) {
      final lowered = decoded.toLowerCase();
      if (lowered.contains('<!doctype html') || lowered.contains('<html')) {
        final titleMatch = RegExp(r'<title>(.*?)</title>', dotAll: true, caseSensitive: false).firstMatch(decoded);
        final title = titleMatch?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (title != null && title.isNotEmpty) return title;
        return 'Backend returned an HTML error page. Please check API_BASE_URL.';
      }
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'] ?? decoded['detail'];
      if (message is String && message.trim().isNotEmpty) return message;

      final detail = decoded['detail'];
      if (detail is Map<String, dynamic>) {
        final field = _firstFieldError(detail);
        if (field.isNotEmpty) return field;
      }

      final field = _firstFieldError(decoded);
      if (field.isNotEmpty) return field;
    }
    return 'Request failed with status $statusCode.';
  }

  String _firstFieldError(Map<String, dynamic> payload) {
    for (final entry in payload.entries) {
      final value = entry.value;
      String? text;
      if (value is String) text = value;
      if (value is List && value.isNotEmpty && value.first is String) {
        text = value.first as String;
      }
      if (text != null && text.trim().isNotEmpty) {
        if (entry.key == 'non_field_errors') return text;
        final label = entry.key
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
            .join(' ');
        return '$label: $text';
      }
    }
    return '';
  }
}
