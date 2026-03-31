import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/models/professional_listing.dart';

/// Client discovery feed from `/users/professionals/search`.
class ProfessionalsRemoteDatasource {
  ProfessionalsRemoteDatasource({
    ApiClient? apiClient,
    SessionStorage? session,
  })  : _api = apiClient ?? ApiClient(),
        _session = session ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;

  /// Best-effort location sync. Never throws — any failure is silently ignored
  /// so it never blocks the professionals search.
  Future<void> updateUserLocationFromDevice() async {
    try {
      final token = await _session.getToken();
      if (token == null || token.isEmpty) return;

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      // Try last-known position first (instant), fall back to fresh fix with 5s cap.
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 5), onTimeout: () => throw Exception('GPS timeout'));

      await _api.put(
        '/users/location',
        body: {'latitude': position.latitude, 'longitude': position.longitude},
        token: token,
      );
    } catch (_) {
      // Location sync is optional; never block the search.
    }
  }

  Future<List<ProfessionalListing>> fetchRecommended({
    int limit = 24,
    String? query,
    String? location,
    int? categoryId,
    double? maxDistanceKm,
    Set<String>? availability,
    int? minRating,
  }) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to search professionals.');
    }
    final trimmedQuery = query?.trim();
    final trimmedLocation = location?.trim();

    // Fire location sync in the background — don't block the search on GPS.
    unawaited(updateUserLocationFromDevice());
    final params = <String, String>{
      'limit': '${limit.clamp(1, 100)}',
      if (trimmedQuery != null && trimmedQuery.isNotEmpty) 'query': trimmedQuery,
      if (trimmedLocation != null && trimmedLocation.isNotEmpty) 'location': trimmedLocation,
      if (categoryId != null) 'categoryId': '$categoryId',
      if (maxDistanceKm != null) 'maxDistanceKm': maxDistanceKm.toStringAsFixed(0),
      if (availability != null) 'availability': _availabilityParam(availability),
      if (minRating != null) 'minRating': '$minRating',
    };
    final q = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
    late final Map<String, dynamic> map;
    try {
      map = await _api.get('/users/professionals/search?$q', token: token);
    } on ApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('/users/location') || msg.contains('save your location')) {
        throw ApiException('Please enter your city in search before searching professionals.', statusCode: e.statusCode);
      }
      rethrow;
    }
    final raw = _extractList(map);
    final base = raw
        .whereType<Map<String, dynamic>>()
        .where((e) => _professionalIdFrom(e).isNotEmpty || _displayNameFrom(e).isNotEmpty)
        .toList();
    final enriched = await _enrichWithProfessionalDetails(base, token: token);
    final listings = enriched.map(ProfessionalListing.fromMap).toList();
    return _applyClientSideQueryGuard(listings, query: trimmedQuery);
  }

  List<dynamic> _extractList(Map<String, dynamic> map) {
    for (final key in const ['professionals', 'data', 'items', 'results', 'rows']) {
      final v = map[key];
      if (v is List) return v;
      if (v is Map<String, dynamic>) {
        for (final inner in const ['professionals', 'items', 'list']) {
          final nested = v[inner];
          if (nested is List) return nested;
        }
      }
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _enrichWithProfessionalDetails(
    List<Map<String, dynamic>> base, {
    required String token,
  }) async {
    if (base.isEmpty) return base;
    final futures = base.map((item) async {
      final id = _professionalIdFrom(item);
      if (id.isEmpty) return item;
      try {
        final detail = await _api.get('/users/professionals/$id', token: token);
        final payload = _extractPayload(detail);
        if (payload == null || payload.isEmpty) return item;
        final withTopLevelCollections = _attachTopLevelCollections(payload, detail);
        final normalized = _normalizePortfolioProjection(withTopLevelCollections);
        return _deepMerge(_deepMerge(item, withTopLevelCollections), normalized);
      } on ApiException {
        return item;
      } catch (_) {
        return item;
      }
    });
    return Future.wait(futures);
  }

  String _professionalIdFrom(Map<String, dynamic> map) {
    for (final key in const ['professionalId', 'id', '_id', 'userId', 'uid']) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _displayNameFrom(Map<String, dynamic> map) {
    for (final key in const ['displayName', 'name', 'username', 'fullName']) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, dynamic>? _extractPayload(Map<String, dynamic> map) {
    final direct = map['professional'];
    if (direct is Map<String, dynamic>) return direct;
    final data = map['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['professional'];
      if (nested is Map<String, dynamic>) return nested;
      return data;
    }
    return map;
  }

  Map<String, dynamic> _attachTopLevelCollections(
    Map<String, dynamic> payload,
    Map<String, dynamic> root,
  ) {
    final out = Map<String, dynamic>.from(payload);
    for (final key in const ['portfolio', 'portfolioItems', 'projects', 'works']) {
      final value = root[key];
      if (value is List && value.isNotEmpty && (out[key] is! List || (out[key] as List).isEmpty)) {
        out[key] = value;
      }
    }
    return out;
  }

  /// Flatten common professional-detail portfolio shapes into keys expected by card mapping.
  Map<String, dynamic> _normalizePortfolioProjection(Map<String, dynamic> payload) {
    final project = _firstPortfolioProject(payload);
    if (project == null) return const {};

    final title = _pickString(project, const ['title', 'projectTitle', 'name']);
    final place = _pickString(project, const ['completedPlace', 'location', 'city', 'address']);
    final amount = _pickString(project, const ['amount', 'price', 'totalPrice', 'projectCost']);
    final doneAt = _pickString(project, const ['completedAt', 'completionDate', 'date', 'createdAt']);
    final photo = _pickPortfolioPhoto(project);

    return {
      if (title != null) 'title': title,
      if (place != null) 'location': place,
      if (amount != null) 'rateLabel': amount,
      if (doneAt != null) 'availability': doneAt,
      if (photo != null) 'coverPhotoUrl': photo,
      // Keep a normalized list so existing mapper's portfolio readers always find data.
      'portfolio': [project],
    };
  }

  Map<String, dynamic>? _firstPortfolioProject(Map<String, dynamic> payload) {
    final candidates = <dynamic>[
      payload['portfolio'],
      payload['portfolioItems'],
      payload['projects'],
      payload['works'],
      payload['data'],
      payload['professional'],
    ];
    for (final node in candidates) {
      if (node is List && node.isNotEmpty && node.first is Map) {
        return Map<String, dynamic>.from(node.first as Map);
      }
      if (node is Map<String, dynamic>) {
        final nestedList = node['portfolio'] ?? node['portfolioItems'] ?? node['projects'] ?? node['works'] ?? node['items'];
        if (nestedList is List && nestedList.isNotEmpty && nestedList.first is Map) {
          return Map<String, dynamic>.from(nestedList.first as Map);
        }
      }
    }
    return null;
  }

  String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _pickPortfolioPhoto(Map<String, dynamic> project) {
    final photos = project['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        return _pickString(m, const ['url', 'photoUrl', 'imageUrl']);
      }
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    return _pickString(project, const ['coverPhotoUrl', 'imageUrl', 'photoUrl', 'thumbnailUrl']);
  }

  /// Fetches all portfolio photo URLs for a professional.
  /// Reuses the same parsing logic as the enrich pipeline so the result is consistent.
  Future<List<String>> fetchPortfolioPhotoUrls(String professionalId) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) throw ApiException('Please login again.');

    final raw = await _api.get('/users/professionals/$professionalId', token: token);
    final payload = _extractPayload(raw) ?? raw;
    final withCollections = _attachTopLevelCollections(payload, raw);

    // Gather every portfolio item from all known keys
    final portfolioItems = <Map<String, dynamic>>[];
    for (final key in const ['portfolio', 'portfolioItems', 'projects', 'works']) {
      final v = withCollections[key] ?? raw[key];
      if (v is List) {
        for (final e in v) {
          if (e is Map) portfolioItems.add(Map<String, dynamic>.from(e));
        }
      }
    }

    // Extract photo URLs from each portfolio item
    final urls = <String>[];
    for (final item in portfolioItems) {
      final photos = item['photos'] ?? item['images'] ?? item['photoUrls'];
      if (photos is List) {
        for (final p in photos) {
          String? url;
          if (p is Map) {
            url = _pickString(Map<String, dynamic>.from(p), const ['url', 'photoUrl', 'imageUrl', 'thumbnailUrl']);
          } else if (p is String && p.trim().isNotEmpty) {
            url = p.trim();
          }
          if (url != null && url.isNotEmpty) {
            urls.add(_toAbsoluteUrl(url));
          }
        }
      }
      // Also pick a direct cover photo if no sub-photos were found for this item
      if (photos == null || (photos is List && photos.isEmpty)) {
        final cover = _pickPortfolioPhoto(item);
        if (cover != null && cover.isNotEmpty && !urls.contains(cover)) {
          urls.add(cover);
        }
      }
    }
    return urls;
  }

  String _toAbsoluteUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$base$path';
  }

  Map<String, dynamic> _deepMerge(Map<String, dynamic> base, Map<String, dynamic> incoming) {
    final merged = Map<String, dynamic>.from(base);
    incoming.forEach((key, value) {
      final prev = merged[key];
      if (prev is Map && value is Map) {
        merged[key] = _deepMerge(Map<String, dynamic>.from(prev), Map<String, dynamic>.from(value));
      } else if (prev is List && prev.isNotEmpty && value is List && value.isNotEmpty) {
        merged[key] = prev;
      } else if (value != null && !(value is String && value.trim().isEmpty)) {
        merged[key] = value;
      }
    });
    return merged;
  }

  String _availabilityParam(Set<String> raw) {
    if (raw.isEmpty) return 'any';
    final normalized = raw
        .map((e) => e.trim().toLowerCase())
        .map((e) {
          if (e == 'within_week') return 'this_week';
          if (e == 'next_week') return 'this_month';
          return e;
        })
        .toSet();
    if (normalized.contains('today')) return 'today';
    if (normalized.contains('this_week')) return 'this_week';
    if (normalized.contains('this_month')) return 'this_month';
    if (normalized.contains('any')) return 'any';
    return 'any';
  }

  List<ProfessionalListing> _applyClientSideQueryGuard(
    List<ProfessionalListing> listings, {
    required String? query,
  }) {
    final q = query?.trim().toLowerCase();
    if (q == null || q.isEmpty) return listings;

    String normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    final qNorm = normalize(q);
    final terms = _querySynonyms(qNorm);

    return listings.where((p) {
      final hay = normalize('${p.specialty} ${p.roleLabel} ${p.displayName}');
      return terms.any((term) => term.isNotEmpty && hay.contains(term));
    }).toList();
  }

  Set<String> _querySynonyms(String qNorm) {
    final out = <String>{qNorm};
    if (qNorm.contains('elect')) out.addAll({'electrical', 'electrician', 'electric'});
    if (qNorm.contains('plumb')) out.addAll({'plumbing', 'plumber'});
    if (qNorm.contains('paint')) out.addAll({'painting', 'painter'});
    if (qNorm.contains('carpent')) out.addAll({'carpentry', 'carpenter'});
    if (qNorm.contains('clean')) out.addAll({'cleaning', 'cleaner'});
    return out;
  }
}
