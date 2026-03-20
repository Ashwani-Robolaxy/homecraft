import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        break;
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: jsonEncode(body ?? {}));
        break;
      case 'PATCH':
        response = await _client.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
        break;
      default:
        throw ApiException('Unsupported method');
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
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
}
