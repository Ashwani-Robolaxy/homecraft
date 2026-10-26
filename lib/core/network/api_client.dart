import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'token_utils.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Called once when a 401 (expired / invalid token) is detected.
  /// Wire this in app startup to clear the session and navigate to login.
  static void Function()? onUnauthorized;

  /// Prevents multiple simultaneous 401 triggers from spamming the callback.
  static bool _handlingUnauth = false;

  Future<Map<String, dynamic>> get(String path, {String? token, bool skipUnauthorized = false}) => _request('GET', path, token: token, skipUnauthorized: skipUnauthorized);
  Future<Map<String, dynamic>> post(String path, {Object? body, String? token, bool skipUnauthorized = false}) => _request('POST', path, body: body, token: token, skipUnauthorized: skipUnauthorized);
  Future<Map<String, dynamic>> put(String path, {Object? body, String? token, bool skipUnauthorized = false}) => _request('PUT', path, body: body, token: token, skipUnauthorized: skipUnauthorized);
  Future<Map<String, dynamic>> patch(String path, {Object? body, String? token, bool skipUnauthorized = false}) =>
      _request('PATCH', path, body: body, token: token, skipUnauthorized: skipUnauthorized);
  Future<Map<String, dynamic>> delete(String path, {String? token, bool skipUnauthorized = false}) => _request('DELETE', path, token: token, skipUnauthorized: skipUnauthorized);

  /// Resolves [urlOrPath] to a URI: full `http(s)` URL as-is, otherwise path under [ApiConfig.baseUrl].
  static Uri resolveBinaryUri(String urlOrPath) {
    final t = urlOrPath.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) {
      return Uri.parse(t);
    }
    final path = t.startsWith('/') ? t : '/$t';
    return Uri.parse('${ApiConfig.baseUrl}$path');
  }

  /// GET raw bytes (e.g. image/PDF). Sends `Authorization: Bearer` when [token] is non-empty.
  Future<Uint8List> getBytes(String urlOrPath, {String? token}) async {
    if (token != null && token.isNotEmpty && TokenUtils.isExpired(token)) {
      debugPrint('[API] Token expired locally — triggering sign-out');
      _triggerUnauthorized();
      throw ApiException('Session expired. Please log in again.', statusCode: 401);
    }
    final uri = resolveBinaryUri(urlOrPath);
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    debugPrint('[API] -> GET $uri (binary)');
    late http.Response response;
    try {
      response = await _client.get(uri, headers: headers).timeout(_requestTimeout);
    } catch (e) {
      if (e is TimeoutException) {
        throw ApiException('Request timed out. Please try again.');
      }
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('network is unreachable') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('connection failed') ||
          errStr.contains('connection refused') ||
          errStr.contains('clientexception')) {
        throw ApiException('No internet connection. Please check your network and retry.');
      }
      throw ApiException('Network error. Please check your connection and try again.');
    }
    debugPrint('[API] <- ${response.statusCode} GET $uri (${response.bodyBytes.length} bytes)');
    if (response.statusCode == 401) {
      if (token != null && token.isNotEmpty) {
        debugPrint('[API] 401 with token — triggering sign-out');
        _triggerUnauthorized();
        throw ApiException('Session expired. Please log in again.', statusCode: 401);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Failed to load file (${response.statusCode})', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> _request(String method, String path, {Object? body, String? token, bool skipUnauthorized = false}) async {
    // ── Pre-flight: reject locally if token is already expired ───────────────
    if (token != null && token.isNotEmpty && TokenUtils.isExpired(token)) {
      debugPrint('[API] Token expired locally — triggering sign-out');
      _triggerUnauthorized();
      throw ApiException('Session expired. Please log in again.', statusCode: 401);
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    _logRequest(method: method, uri: uri, headers: headers, body: body);
    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(_requestTimeout);
          break;
        case 'POST':
          response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_requestTimeout);
          break;
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_requestTimeout);
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_requestTimeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(_requestTimeout);
          break;
        default:
          throw ApiException('Unsupported method');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw ApiException('Request timed out. Please try again.');
      }
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('network is unreachable') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('connection failed') ||
          errStr.contains('connection refused') ||
          errStr.contains('clientexception')) {
        throw ApiException('No internet connection. Please check your network and retry.');
      }
      throw ApiException('Network error. Please check your connection and try again.');
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    _logResponse(method: method, uri: uri, statusCode: response.statusCode, body: response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return map;

    // ── 401 from server ───────────────────────────────────────────────────────
    // Only treat as "session expired" when we actually sent an auth token.
    // A 401 on a public endpoint (e.g. /login) means wrong credentials —
    // surface the server's message directly instead of triggering sign-out.
    if (response.statusCode == 401) {
      // When skipUnauthorized is true the caller handles the 401 itself
      // (e.g. change-password where 401 = wrong current password, not expired session).
      if (token != null && token.isNotEmpty && !skipUnauthorized) {
        debugPrint('[API] 401 with token — triggering sign-out');
        _triggerUnauthorized();
        throw ApiException('Session expired. Please log in again.', statusCode: 401);
      }
      // No token, or skipUnauthorized → fall through and surface the real server message.
    }

    var message = (map['message'] ?? map['error'] ?? 'Request failed').toString();
    final errors = map['errors'];
    if (errors is List) {
      final parts = <String>[];
      for (final e in errors) {
        if (e is Map) {
          final m = e['message'] ?? e['error'];
          if (m != null && m.toString().isNotEmpty) parts.add(m.toString());
        } else if (e != null) {
          parts.add(e.toString());
        }
      }
      if (parts.isNotEmpty) message = '$message\n${parts.join('\n')}';
    } else if (errors is Map) {
      final parts = <String>[];
      errors.forEach((key, val) {
        if (val is List) {
          parts.add('$key: ${val.join(', ')}');
        } else if (val != null) {
          parts.add('$key: $val');
        }
      });
      if (parts.isNotEmpty) message = '$message\n${parts.join('\n')}';
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  void _logRequest({required String method, required Uri uri, required Map<String, String> headers, required Object? body}) {
    debugPrint('[API] -> $method $uri');
    debugPrint('[API]    headers: $headers');
    if (body != null) {
      debugPrint('[API]    payload: ${jsonEncode(body)}');
    }
  }

  void _logResponse({required String method, required Uri uri, required int statusCode, required String body}) {
    debugPrint('[API] <- $statusCode $method $uri');
    final responseBody = body.length > 4000 ? '${body.substring(0, 4000)}...<truncated>' : body;
    debugPrint('[API]    response: $responseBody');
  }

  /// Fire the onUnauthorized callback at most once per 3 seconds to avoid
  /// spamming it when multiple requests fail simultaneously.
  static void _triggerUnauthorized() {
    if (_handlingUnauth) return;
    _handlingUnauth = true;
    onUnauthorized?.call();
    Future.delayed(const Duration(seconds: 3), () => _handlingUnauth = false);
  }
}
