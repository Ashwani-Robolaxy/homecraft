import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/models/portfolio_item.dart';
import '../../domain/repositories/portfolio_repository.dart';

class PortfolioRemoteDatasource {
  PortfolioRemoteDatasource({SessionStorage? sessionStorage, http.Client? httpClient})
      : _session = sessionStorage ?? SessionStorage(),
        _http = httpClient ?? http.Client();

  /// Matches API: max 30 photos per portfolio item (see swagger).
  static const int maxPhotosPerItem = 4;

  final SessionStorage _session;
  final http.Client _http;

  /// Fetches the portfolio of any professional by their user ID.
  /// Uses the public professional detail endpoint and extracts portfolio data.
  Future<List<PortfolioItem>> getPortfolioByProfessionalId(String professionalId) async {
    final token = await _token();
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/users/professionals/$professionalId'),
      headers: _jsonHeaders(token),
    );
    final map = _decodeMap(response.body);
    _ensureOk(response.statusCode, map, fallback: 'Failed to load professional portfolio');

    // The response may nest data under 'professional', 'data', or be at top level
    final data = (map['professional'] ?? map['data'] ?? map) as Map<String, dynamic>;

    // Extract portfolio — could be a list of items or a flat list of photo URLs
    dynamic raw = data['portfolio'] ?? data['portfolioItems'] ?? data['portfolioPhotos'];
    if (raw is! List) return const [];

    // Try to parse as PortfolioItem list first; fall back to flat photo URL strings
    final items = <PortfolioItem>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        try {
          items.add(PortfolioItem.fromMap(e));
        } catch (_) {
          // If not a full item, treat as a single-photo item
          final photo = PortfolioPhoto.fromMap(e);
          if (photo.url.isNotEmpty) {
            items.add(PortfolioItem(
              id: photo.id,
              title: '',
              description: '',
              photos: [photo],
            ));
          }
        }
      } else if (e is String && e.trim().isNotEmpty) {
        final url = PortfolioPhoto.toAbsoluteUrl(e.trim());
        items.add(PortfolioItem(
          id: items.length + 1,
          title: '',
          description: '',
          photos: [PortfolioPhoto(id: items.length + 1, url: url)],
        ));
      }
    }
    return items;
  }

  Future<List<PortfolioItem>> getMyPortfolio() async {
    final token = await _token();
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/professionals/portfolio'),
      headers: _jsonHeaders(token),
    );
    final map = _decodeMap(response.body);
    _ensureOk(response.statusCode, map, fallback: 'Failed to load portfolio');
    final rows = _extractList(map);
    return rows.map(PortfolioItem.fromMap).where((e) => e.id > 0).toList();
  }

  Future<void> createItem(CreatePortfolioInput input) async {
    final token = await _token();
    if (input.photoPaths.isEmpty) {
      throw ApiException('Please add at least one photo.');
    }
    if (input.photoPaths.length > maxPhotosPerItem) {
      throw ApiException('At most $maxPhotosPerItem photos per portfolio item.');
    }
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/professionals/portfolio'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = input.title;
    request.fields['description'] = input.description;
    if (input.completedPlace != null) request.fields['completedPlace'] = input.completedPlace!;
    if (input.amount != null) request.fields['amount'] = input.amount!;

    for (final path in input.photoPaths) {
      final mediaType = await _detectAllowedMediaType(path);
      request.files.add(await http.MultipartFile.fromPath('photos', path, contentType: mediaType));
    }

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final map = _decodeMap(response.body);
    _ensureOk(response.statusCode, map, fallback: 'Failed to create portfolio item');
  }

  Future<void> updateItem(int portfolioId, UpdatePortfolioInput input) async {
    final token = await _token();
    if (!input.hasAnyField) {
      throw ApiException('No fields to update.');
    }
    final body = <String, dynamic>{};
    if (input.title != null) body['title'] = input.title;
    if (input.description != null) body['description'] = input.description;
    if (input.completedPlace != null) body['completedPlace'] = input.completedPlace;
    if (input.amount != null) {
      final trimmed = input.amount!.trim();
      body['amount'] = trimmed.isEmpty ? null : (double.tryParse(trimmed) ?? trimmed);
    }

    final response = await _http.put(
      Uri.parse('${ApiConfig.baseUrl}/professionals/portfolio/$portfolioId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(body),
    );
    final map = _decodeMap(response.body);
    _ensureOk(response.statusCode, map, fallback: 'Failed to update portfolio item');
  }

  Future<void> deleteItem(int portfolioId) async {
    final token = await _token();
    final response = await _http.delete(
      Uri.parse('${ApiConfig.baseUrl}/professionals/portfolio/$portfolioId'),
      headers: _jsonHeaders(token),
    );
    final map = _decodeMap(response.body);
    _ensureOk(response.statusCode, map, fallback: 'Failed to delete portfolio item');
  }

  Future<void> addPhotos(int portfolioId, List<String> photoPaths) async {
    final token = await _token();
    if (photoPaths.isEmpty) {
      throw ApiException('Please pick at least one photo to upload.');
    }
    if (photoPaths.length > maxPhotosPerItem) {
      throw ApiException('At most $maxPhotosPerItem photos can be uploaded in one request.');
    }

    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/professionals/portfolio/$portfolioId/photos'));
    request.headers['Authorization'] = 'Bearer $token';

    for (final path in photoPaths) {
      final mediaType = await _detectAllowedMediaType(path);
      request.files.add(await http.MultipartFile.fromPath('photos', path, contentType: mediaType));
    }

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final map = _decodeMap(response.body);
    _ensureOk(response.statusCode, map, fallback: 'Failed to add photos');
  }

  Future<void> deletePhoto(int portfolioId, int photoId) async {
    final token = await _token();
    final response = await _http.delete(
      Uri.parse('${ApiConfig.baseUrl}/professionals/portfolio/$portfolioId/photos/$photoId'),
      headers: _jsonHeaders(token),
    );
    final map = _decodeMap(response.body);
    _ensureOk(response.statusCode, map, fallback: 'Failed to delete photo');
  }

  Future<String> _token() async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to continue.');
    }
    return token;
  }

  Map<String, String> _jsonHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> map) {
    dynamic node = map['items'];
    node ??= map['portfolio'];
    node ??= map['data'];
    if (node is Map<String, dynamic>) {
      node = node['items'] ?? node['portfolio'] ?? node['data'];
    }
    if (node is! List) return const [];
    return node.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _ensureOk(int statusCode, Map<String, dynamic> map, {required String fallback}) {
    if (statusCode >= 200 && statusCode < 300) return;
    var message = (map['message'] ?? map['error'] ?? fallback).toString();
    final errors = map['errors'];
    if (errors is List && errors.isNotEmpty) {
      final all = <String>[];
      for (final e in errors) {
        if (e is Map && e['message'] != null) {
          all.add(e['message'].toString());
        }
      }
      if (all.isNotEmpty) message = all.join('\n');
    }
    throw ApiException(message, statusCode: statusCode);
  }

  Future<MediaType> _detectAllowedMediaType(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ApiException('Selected file is not accessible. Please pick the image again.');
    }
    final bytes = await file.readAsBytes();
    final header = bytes.length >= 16 ? bytes.sublist(0, 16) : bytes;
    final mime = lookupMimeType(path, headerBytes: header)?.toLowerCase();
    switch (mime) {
      case 'image/jpeg':
        return MediaType('image', 'jpeg');
      case 'image/png':
        return MediaType('image', 'png');
      case 'image/webp':
        return MediaType('image', 'webp');
      default:
        throw ApiException('Only JPEG, PNG, or WebP images are allowed for portfolio photos');
    }
  }
}
