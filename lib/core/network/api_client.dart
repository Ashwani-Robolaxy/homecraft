import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> get(String path, {String? token}) =>
      _request('GET', path, token: token);
  Future<Map<String, dynamic>> post(String path, {Object? body, String? token}) =>
      _request('POST', path, body: body, token: token);
  Future<Map<String, dynamic>> put(String path, {Object? body, String? token}) =>
      _request('PUT', path, body: body, token: token);
  Future<Map<String, dynamic>> patch(String path, {Object? body, String? token}) =>
      _request('PATCH', path, body: body, token: token);
  Future<Map<String, dynamic>> delete(String path, {String? token}) =>
      _request('DELETE', path, token: token);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
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
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    _logResponse(method: method, uri: uri, statusCode: response.statusCode, body: response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return map;
    var message = (map['message'] ?? map['error'] ?? 'Request failed').toString();
    final errors = map['errors'];
    if (errors is List) {
      final parts = <String>[];
      for (final e in errors) {
        if (e is Map) {
          final m = e['message'];
          if (m != null && m.toString().isNotEmpty) parts.add(m.toString());
        }
      }
      if (parts.isNotEmpty) message = parts.join('\n');
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  void _logRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Object? body,
  }) {
    debugPrint('[API] -> $method $uri');
    debugPrint('[API]    headers: $headers');
    if (body != null) {
      debugPrint('[API]    payload: ${jsonEncode(body)}');
    }
  }

  void _logResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    required String body,
  }) {
    debugPrint('[API] <- $statusCode $method $uri');
    final responseBody = body.length > 4000 ? '${body.substring(0, 4000)}...<truncated>' : body;
    debugPrint('[API]    response: $responseBody');
  }
}
