import 'dart:convert';
import 'package:path/path.dart' as p;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/models/my_projects_result.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_category.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectRemoteDatasource {
  ProjectRemoteDatasource({ApiClient? apiClient, SessionStorage? sessionStorage, http.Client? httpClient})
    : _api = apiClient ?? ApiClient(),
      _session = sessionStorage ?? SessionStorage(),
      _http = httpClient ?? http.Client();

  final ApiClient _api;
  final SessionStorage _session;
  final http.Client _http;

  Future<List<ProjectCategory>> getCategories() async {
    final map = await _api.get('/projects/categories');
    final list = map['categories'] is List ? map['categories'] as List : (map['data'] is List ? map['data'] as List : const []);
    return list.whereType<Map<String, dynamic>>().map(ProjectCategory.fromMap).where((e) => e.id > 0).toList();
  }

  Future<MyProjectsResult> getMyProjects() async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to load projects.');
    }
    final map = await _api.get('/users/projects', token: token);
    final list = _extractProjectsList(map);
    final projects = list.whereType<Map<String, dynamic>>().map(_normalizeProjectMap).map(Project.fromMap).where((e) => e.id.isNotEmpty).toList();
    final remaining = _extractInt(
      map,
      keys: const ['remainingProjects', 'remainingProject', 'projectsRemaining', 'remaining'],
      nestedDataKeys: const ['remainingProjects', 'remainingProject', 'projectsRemaining', 'remaining'],
    );
    final max = _extractInt(map, keys: const ['maxProjects', 'projectLimit', 'limit'], nestedDataKeys: const ['maxProjects', 'projectLimit', 'limit']);
    return MyProjectsResult(projects: projects, remainingProjects: remaining, maxProjects: max);
  }

  /// Swagger: `GET /professionals/projects` — open projects (verified professionals only).
  /// Query: [limit] (default 20), [beforeId] pagination, [categoryId] filter.
  /// Optional [search] is sent as `q` when non-empty (filter server-side when supported; otherwise client-side).
  Future<List<Project>> getProfessionalProjects({
    int limit = 20,
    int? beforeId,
    int? categoryId,
    String? search,
  }) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to load projects.');
    }
    final query = <String, String>{
      'limit': '${limit.clamp(1, 100)}',
      if (beforeId != null) 'beforeId': '$beforeId',
      if (categoryId != null) 'categoryId': '$categoryId',
      if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
    };
    final q = query.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    final map = await _api.get('/professionals/projects?$q', token: token);
    final list = _extractProjectsList(map);
    return list.whereType<Map<String, dynamic>>().map(_normalizeProjectMap).map(Project.fromMap).where((e) => e.id.isNotEmpty).toList();
  }

  Future<List<ProfessionalInterestedProject>> getProfessionalInterestedProjects() async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to load interested projects.');
    }
    final map = await _api.get('/professionals/projects/interested', token: token);
    final list = map['projects'] is List ? map['projects'] as List : const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) {
          final normalized = _normalizeProjectMap(m);
          return ProfessionalInterestedProject.fromMap(normalized);
        })
        .toList();
  }

  Future<void> createProject(CreateProjectInput input) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to create a project.');
    }
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/users/projects'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = input.title;
    request.fields['description'] = input.description;
    request.fields['categoryId'] = input.categoryId.toString();
    request.fields['location'] = input.location;
    request.fields['desiredDate'] = input.desiredDate;
    if (input.latitude != null) {
      request.fields['latitude'] = input.latitude!.toString();
    }
    if (input.longitude != null) {
      request.fields['longitude'] = input.longitude!.toString();
    }
    if (input.budget != null && input.budget!.trim().isNotEmpty) {
      request.fields['budget'] = input.budget!.trim();
    }
    if (input.attachmentPath != null && input.attachmentPath!.isNotEmpty) {
      final ext = p.extension(input.attachmentPath!).replaceFirst('.', '').toLowerCase();
      final fileName = p.basenameWithoutExtension(input.attachmentPath!);
      final normalizedName = ext.isEmpty ? fileName : '$fileName.$ext';
      final mediaType = _mediaTypeForExtension(ext);
      request.files.add(await http.MultipartFile.fromPath('attachment', input.attachmentPath!, filename: normalizedName, contentType: mediaType));
    }

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var message = (map['message'] ?? map['error'] ?? 'Failed to create project').toString();
    final errors = map['errors'];
    if (errors is List) {
      final parts = <String>[];
      for (final e in errors) {
        if (e is Map && e['message'] != null) {
          parts.add(e['message'].toString());
        }
      }
      if (parts.isNotEmpty) message = parts.join('\n');
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<void> updateProject(String projectId, CreateProjectInput input) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to update this project.');
    }
    Future<http.Response> sendWithMethod(String method) async {
      final request = http.MultipartRequest(
        method,
        Uri.parse('${ApiConfig.baseUrl}/users/projects/$projectId'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = input.title;
      request.fields['description'] = input.description;
      request.fields['categoryId'] = input.categoryId.toString();
      request.fields['location'] = input.location;
      request.fields['desiredDate'] = input.desiredDate;
      if (input.latitude != null) {
        request.fields['latitude'] = input.latitude!.toString();
      }
      if (input.longitude != null) {
        request.fields['longitude'] = input.longitude!.toString();
      }
      if (input.budget != null && input.budget!.trim().isNotEmpty) {
        request.fields['budget'] = input.budget!.trim();
      }
      if (input.attachmentPath != null && input.attachmentPath!.isNotEmpty) {
        final ext = p.extension(input.attachmentPath!).replaceFirst('.', '').toLowerCase();
        final fileName = p.basenameWithoutExtension(input.attachmentPath!);
        final normalizedName = ext.isEmpty ? fileName : '$fileName.$ext';
        final mediaType = _mediaTypeForExtension(ext);
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            input.attachmentPath!,
            filename: normalizedName,
            contentType: mediaType,
          ),
        );
      }
      final streamed = await _http.send(request);
      return http.Response.fromStream(streamed);
    }

    var response = await sendWithMethod('PUT');
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    // Some deployments expose PATCH while mobile contract uses PUT.
    final msgRaw = (map['message'] ?? map['error'] ?? '').toString().toLowerCase();
    final missingRoute = response.statusCode == 404 && msgRaw.contains('route not found');
    if (missingRoute) {
      response = await sendWithMethod('PATCH');
      final decodedPatch = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      final mapPatch = decodedPatch is Map<String, dynamic> ? decodedPatch : <String, dynamic>{'data': decodedPatch};
      if (response.statusCode >= 200 && response.statusCode < 300) return;

      var message = (mapPatch['message'] ?? mapPatch['error'] ?? 'Failed to update project').toString();
      final errors = mapPatch['errors'];
      if (errors is List) {
        final parts = <String>[];
        for (final e in errors) {
          if (e is Map && e['message'] != null) {
            parts.add(e['message'].toString());
          }
        }
        if (parts.isNotEmpty) message = parts.join('\n');
      }
      throw ApiException(message, statusCode: response.statusCode);
    }

    var message = (map['message'] ?? map['error'] ?? 'Failed to update project').toString();
    final errors = map['errors'];
    if (errors is List) {
      final parts = <String>[];
      for (final e in errors) {
        if (e is Map && e['message'] != null) {
          parts.add(e['message'].toString());
        }
      }
      if (parts.isNotEmpty) message = parts.join('\n');
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<void> deleteProject(String projectId) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to delete this project.');
    }
    await _api.delete('/users/projects/$projectId', token: token);
  }

  /// POST /professionals/projects/{projectId}/interest
  /// Body may include optional [comment].
  Future<void> markProjectInterest(String projectId, {String? comment}) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to mark interest.');
    }
    final path = '/professionals/projects/$projectId/interest';
    final body = <String, dynamic>{
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    };

    try {
      await _api.post(path, body: body, token: token);
      return;
    } on ApiException catch (e) {
      // Some deployments may register PUT instead of POST.
      final msg = e.message.toLowerCase();
      final missingRoute = e.statusCode == 404 || msg.contains('route not found');
      if (!missingRoute) rethrow;
      await _api.put(path, body: body, token: token);
    }
  }

  /// GET /users/projects/{projectId}/interests
  /// Returns interested count + comments/professional notes.
  Future<ProjectInterestsResult> fetchProjectInterests(String projectId) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to load project interests.');
    }
    final map = await _api.get('/users/projects/$projectId/interests', token: token);

    int pickInt(List<dynamic> values) {
      for (final v in values) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return 0;
    }

    List<Map<String, dynamic>> toMapList(dynamic node) {
      if (node is! List) return const [];
      return node.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    String absUrl(String raw) {
      if (raw.isEmpty) return '';
      if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
      final path = raw.startsWith('/') ? raw : '/$raw';
      return '${ApiConfig.baseUrl}$path';
    }

    String interestName(Map<String, dynamic> m) {
      final nested = m['professional'] ?? m['user'] ?? m['provider'] ?? m['otherParty'];
      if (nested is Map) {
        final mm = Map<String, dynamic>.from(nested);
        final direct = (mm['displayName'] ?? mm['fullName'] ?? mm['name'] ?? mm['username'] ?? '').toString().trim();
        if (direct.isNotEmpty) return direct;
        final first = (mm['firstName'] ?? '').toString().trim();
        final last = (mm['lastName'] ?? '').toString().trim();
        final joined = '$first $last'.trim();
        if (joined.isNotEmpty) return joined;
      }
      return (m['professionalUsername'] ?? m['professionalName'] ?? '').toString().trim();
    }

    String interestSubtitle(Map<String, dynamic> m) {
      final nested = m['professional'] ?? m['user'] ?? m['provider'] ?? m['otherParty'];
      if (nested is Map) {
        final mm = Map<String, dynamic>.from(nested);
        final text = (mm['speciality'] ?? mm['specialty'] ?? mm['profession'] ?? mm['companyName'] ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return (m['professionalCompany'] ?? m['professionalSpeciality'] ?? '').toString().trim();
    }

    String interestId(Map<String, dynamic> m) {
      final nested = m['professional'] ?? m['user'] ?? m['provider'] ?? m['otherParty'];
      if (nested is Map) {
        final mm = Map<String, dynamic>.from(nested);
        final id = (mm['id'] ?? mm['_id'] ?? mm['userId'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
      }
      return (m['professionalId'] ?? m['providerId'] ?? m['userId'] ?? '').toString().trim();
    }

    String interestAvatar(Map<String, dynamic> m) {
      final nested = m['professional'] ?? m['user'] ?? m['provider'] ?? m['otherParty'];
      if (nested is Map) {
        final mm = Map<String, dynamic>.from(nested);
        final raw = (mm['imageUrl'] ?? mm['avatar'] ?? mm['profilePhoto'] ?? mm['photo'] ?? '').toString().trim();
        if (raw.isNotEmpty) return absUrl(raw);
      }
      final rootRaw = (m['professionalImageUrl'] ?? m['imageUrl'] ?? '').toString().trim();
      return rootRaw.isEmpty ? '' : absUrl(rootRaw);
    }

    ProjectComment toComment(Map<String, dynamic> m) {
      final text = (m['comment'] ?? m['message'] ?? m['note'] ?? m['text'] ?? '').toString().trim();
      final createdAt = (m['createdAt'] ?? m['updatedAt'] ?? '').toString().trim();
      final dt = DateTime.tryParse(createdAt);
      final hoursAgo = dt == null ? 0 : DateTime.now().difference(dt).inHours.clamp(0, 24 * 365);
      final name = interestName(m);
      return ProjectComment(
        userName: name.isNotEmpty ? name : 'Professional',
        userAvatar: interestAvatar(m),
        text: text,
        hoursAgo: hoursAgo,
      );
    }

    final data = map['data'];
    final root = data is Map<String, dynamic> ? data : map;
    final rawInterests = toMapList(
      root['interests'] ?? root['comments'] ?? root['items'] ?? map['interests'] ?? map['comments'] ?? map['items'],
    );
    final interestedCount = pickInt([
      root['interestedCount'],
      root['interestCount'],
      root['count'],
      root['totalInterests'],
      rawInterests.length,
      map['interestedCount'],
      map['interestCount'],
      map['count'],
      map['totalInterests'],
    ]);
    final comments = rawInterests
        .map(toComment)
        .where((c) => c.text.trim().isNotEmpty)
        .toList();
    final interests = rawInterests.map((m) {
      final createdAt = DateTime.tryParse((m['createdAt'] ?? m['updatedAt'] ?? '').toString().trim());
      final name = interestName(m);
      final subtitle = interestSubtitle(m);
      final avatar = interestAvatar(m);
      return ProjectInterest(
        professionalId: interestId(m),
        professionalName: name.isNotEmpty ? name : 'Professional',
        professionalSubtitle: subtitle,
        professionalImageUrl: avatar.isEmpty ? null : avatar,
        comment: (m['comment'] ?? '').toString().trim(),
        createdAt: createdAt,
      );
    }).toList();
    return (interestedCount: interestedCount, comments: comments, interests: interests);
  }

  MediaType? _mediaTypeForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'zip':
        return MediaType('application', 'zip');
      default:
        return null;
    }
  }

  List _extractProjectsList(Map<String, dynamic> map) {
    final rootProjects = map['projects'];
    if (rootProjects is List) return rootProjects;

    final data = map['data'];
    if (data is Map<String, dynamic>) {
      final nestedProjects = data['projects'];
      if (nestedProjects is List) return nestedProjects;
    }
    if (data is List) return data;
    return const [];
  }

  Map<String, dynamic> _normalizeProjectMap(Map<String, dynamic> map) {
    final normalized = Map<String, dynamic>.from(map);

    void mergeCoordsFrom(dynamic node) {
      if (node is! Map) return;
      final m = Map<String, dynamic>.from(node);
      final lat = m['latitude'] ?? m['lat'];
      final lng = m['longitude'] ?? m['lng'] ?? m['long'];
      if (lat != null && normalized['latitude'] == null) normalized['latitude'] = lat;
      if (lng != null && normalized['longitude'] == null) normalized['longitude'] = lng;
    }

    mergeCoordsFrom(map['coordinates']);
    mergeCoordsFrom(map['geo']);
    mergeCoordsFrom(map['geoLocation']);
    final geometry = map['geometry'];
    if (geometry is Map) mergeCoordsFrom(geometry['location']);

    final loc = map['location'];
    if (loc is Map) {
      final m = Map<String, dynamic>.from(loc);
      final addr = (m['address'] ??
              m['formattedAddress'] ??
              m['formatted_address'] ??
              m['label'] ??
              m['name'] ??
              '')
          .toString()
          .trim();
      if (addr.isNotEmpty) normalized['location'] = addr;
      mergeCoordsFrom(loc);
    }

    final attachment = (normalized['attachmentUrl'] ?? '').toString().trim();
    if (attachment.isNotEmpty && !attachment.startsWith('http://') && !attachment.startsWith('https://')) {
      final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
      final path = attachment.startsWith('/') ? attachment : '/$attachment';
      normalized['attachmentUrl'] = '$base$path';
    }
    return normalized;
  }

  int? _extractInt(Map<String, dynamic> root, {required List<String> keys, required List<String> nestedDataKeys}) {
    for (final key in keys) {
      final value = root[key];
      final parsed = _toInt(value);
      if (parsed != null) return parsed;
    }
    final data = root['data'];
    if (data is Map<String, dynamic>) {
      for (final key in nestedDataKeys) {
        final value = data[key];
        final parsed = _toInt(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
