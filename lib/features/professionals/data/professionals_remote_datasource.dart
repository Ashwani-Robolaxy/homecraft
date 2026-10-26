import 'dart:async';
import 'dart:developer' as developer;

import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/models/professional_listing.dart';
import '../domain/models/professional_review.dart';

/// Client discovery feed from `/users/professionals/search`.
class ProfessionalsRemoteDatasource {
  ProfessionalsRemoteDatasource({
    ApiClient? apiClient,
    SessionStorage? session,
  })  : _api = apiClient ?? ApiClient(),
        _session = session ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;
  static DateTime? _lastLocationSyncAt;

  /// Best-effort location sync. Never throws — any failure is silently ignored
  /// so it never blocks the professionals search.
  Future<void> updateUserLocationFromDevice() async {
    try {
      final now = DateTime.now();
      if (_lastLocationSyncAt != null &&
          now.difference(_lastLocationSyncAt!) < const Duration(minutes: 2)) {
        return;
      }
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
      _lastLocationSyncAt = now;
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
    double? latitude,
    double? longitude,
    DateTime? interventionDate,
  }) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to search professionals.');
    }
    final trimmedQuery = query?.trim();
    final trimmedLocation = location?.trim();
    final now = interventionDate ?? DateTime.now();
    final dateYmd =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final coords = await _deviceCoordinates();
    
    // Default fallback to Paris coordinates (48.856614, 2.3522219) for general discovery/recommendations feed
    // or when the device coordinates are far outside France.
    double lat = latitude ?? coords?.$1 ?? 48.856614;
    double long = longitude ?? coords?.$2 ?? 2.3522219;

    if (latitude == null && (trimmedLocation == null || trimmedLocation.isEmpty)) {
      final isOutsideFrance = lat < 41.0 || lat > 52.0 || long < -5.5 || long > 10.0;
      if (isOutsideFrance) {
        lat = 48.856614;
        long = 2.3522219;
      }
    }

    // Fetch categories to get IDs and name mappings
    List<Map<String, dynamic>> allCategoriesMap = [];
    List<int> fetchedIds = [];
    try {
      final catMap = await _api.get('/projects/categories', token: token);
      final catList = (catMap['categories'] ?? catMap['data']) as List?;
      if (catList != null) {
        for (final item in catList) {
          if (item is Map<String, dynamic>) {
            allCategoriesMap.add(item);
            final id = item['id'] as int?;
            if (id != null) fetchedIds.add(id);
          }
        }
      }
    } catch (e) {
      developer.log('Failed to fetch categories: $e', name: 'ProfessionalsRemoteDatasource');
    }

    final List<int> categoryIds;
    if (categoryId != null) {
      categoryIds = [categoryId];
    } else {
      categoryIds = fetchedIds.isNotEmpty ? fetchedIds : [1, 2, 3, 4, 5, 6, 25, 26];
    }

    final isFranceSearch = trimmedLocation != null &&
        (trimmedLocation.toLowerCase().contains('france') ||
            trimmedLocation.toLowerCase().contains(', fr') ||
            trimmedLocation.toLowerCase() == 'fr');

    if (latitude != null && longitude != null) {
      try {
        await _api.put(
          '/users/location',
          body: {'latitude': lat, 'longitude': long},
          token: token,
        );
      } catch (e) {
        developer.log('Failed to sync search location to backend: $e', name: 'ProfessionalsRemoteDatasource');
      }
    } else {
      unawaited(updateUserLocationFromDevice());
    }

    // Use wide radius for default recommendation feeds so all available professionals are discovered
    final double radiusValue = (latitude == null && (trimmedLocation == null || trimmedLocation.isEmpty))
        ? 10000.0
        : (isFranceSearch ? 2000.0 : (maxDistanceKm ?? 500.0));

    final baseParams = <String, String>{
      'limit': '${limit.clamp(1, 100)}',
      'radiusKm': radiusValue.toStringAsFixed(0),
      'maxDistanceKm': radiusValue.toStringAsFixed(0),
      if (availability != null) 'availability': _availabilityParam(availability),
      'lat': lat.toString(),
      'long': long.toString(),
      'date': dateYmd,
    };
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      baseParams['query'] = trimmedQuery;
    }
    if (trimmedLocation != null && trimmedLocation.isNotEmpty) {
      baseParams['location'] = trimmedLocation;
    }
    if (minRating != null) {
      baseParams['minRating'] = '$minRating';
    }

    String encode(Map<String, String> map) => map.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    // Run search calls in parallel for all resolved categoryIds
    final searchFutures = categoryIds.map((catId) async {
      final params = Map<String, String>.from(baseParams);
      params['categoryId'] = '$catId';
      
      developer.log(
        'Search API payload for categoryId $catId => $params',
        name: 'ProfessionalsRemoteDatasource',
      );
      
      try {
        final resMap = await _api.get(
          '/users/professionals/search?${encode(params)}',
          token: token,
        );
        return _extractList(resMap);
      } on ApiException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('/users/location') || msg.contains('save your location')) {
          throw ApiException(
            'Please enter your city in search before searching professionals.',
            statusCode: e.statusCode,
          );
        }
        if (e.statusCode == 422) {
          return const [];
        }
        rethrow;
      } catch (e) {
        developer.log('Search failed for categoryId $catId: $e', name: 'ProfessionalsRemoteDatasource');
        return const [];
      }
    });

    final searchResults = await Future.wait(searchFutures);
    List<dynamic> raw = searchResults.expand((e) => e).toList();

    // If a specific category was searched but returned 0 results from backend,
    // fallback to searching all categories and filtering by category name/specialty client-side
    if (raw.isEmpty && categoryId != null) {
      final fallbackCat = allCategoriesMap.firstWhere(
        (c) => c['id'] == categoryId,
        orElse: () => const <String, dynamic>{},
      );
      final catName = (fallbackCat['name'] ?? '').toString().toLowerCase().trim();
      final catSlug = (fallbackCat['slug'] ?? '').toString().toLowerCase().trim();

      final allCatIds = fetchedIds.isNotEmpty ? fetchedIds : [1, 2, 3, 4, 5, 6, 25, 26];
      final allFutures = allCatIds.map((cId) async {
        final params = Map<String, String>.from(baseParams);
        params['categoryId'] = '$cId';
        try {
          final resMap = await _api.get(
            '/users/professionals/search?${encode(params)}',
            token: token,
          );
          return _extractList(resMap);
        } catch (_) {
          return const [];
        }
      });
      final allResults = await Future.wait(allFutures);
      final allRaw = allResults.expand((e) => e).toList();

      if (catName.isNotEmpty || catSlug.isNotEmpty) {
        raw = allRaw.where((item) {
          if (item is! Map) return false;
          final m = Map<String, dynamic>.from(item);
          final itemCatId = m['categoryId'] ?? m['category_id'];
          if (itemCatId != null && itemCatId.toString() == '$categoryId') return true;
          final spec = (m['speciality'] ?? m['specialty'] ?? m['categoryName'] ?? m['profession'] ?? m['role'] ?? '').toString().toLowerCase();
          if (catName.isNotEmpty && spec.contains(catName)) return true;
          if (catSlug.isNotEmpty && spec.contains(catSlug)) return true;
          return false;
        }).toList();
      }
    }

    developer.log(
      'Search API responses combined items: ${raw.length}',
      name: 'ProfessionalsRemoteDatasource',
    );

    // Deduplicate items by professional ID or display name to avoid duplicates across queries
    final seenIds = <String>{};
    final base = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final id = _professionalIdFrom(item);
        if (id.isNotEmpty) {
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            base.add(item);
          }
        } else {
          final displayName = _displayNameFrom(item);
          if (displayName.isNotEmpty && !seenIds.contains(displayName)) {
            seenIds.add(displayName);
            base.add(item);
          }
        }
      }
    }

    // Never block the recommendations feed on detail-enrichment calls.
    // If enrichment is slow/fails, fall back to base results immediately.
    List<Map<String, dynamic>> enriched = base;
    try {
      enriched = await _enrichWithProfessionalDetails(base, token: token)
          .timeout(const Duration(seconds: 8), onTimeout: () => base);
    } catch (_) {
      enriched = base;
    }

    final listings = enriched.map(ProfessionalListing.fromMap).toList();
    developer.log(
      'Search API mapped listings => ${listings.length}',
      name: 'ProfessionalsRemoteDatasource',
    );
    return _applyClientSideFilters(
      listings,
      query: trimmedQuery,
      searchLocation: trimmedLocation,
      searchLat: latitude,
      searchLng: longitude,
      maxDistanceKm: maxDistanceKm,
    );
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

  /// Fetches one professional by id and maps all available detail data into listing shape.
  Future<ProfessionalListing> fetchProfessionalById(String professionalId) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again.');
    }
    final id = professionalId.trim();
    if (id.isEmpty) {
      throw ApiException('Professional id is required.');
    }

    final raw = await _api.get('/users/professionals/$id', token: token);
    final payload = _extractPayload(raw) ?? raw;
    final withCollections = _attachTopLevelCollections(payload, raw);
    final normalized = _normalizePortfolioProjection(withCollections);
    final merged = _deepMerge(_deepMerge({'id': id}, withCollections), normalized);
    return ProfessionalListing.fromMap(merged);
  }

  /// Fetches reviews and ratings for a professional via `/users/professionals/{professionalId}/reviews`.
  Future<ProfessionalReviewsSummary> fetchProfessionalReviewsById(String professionalId) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again.');
    }
    final proId = professionalId.trim();
    if (proId.isEmpty) {
      throw ApiException('Professional id is missing.');
    }

    final res = await _api.get('/users/professionals/$proId/reviews', token: token);
    return ProfessionalReviewsSummary.fromMap(res);
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

  Future<(double, double)?> _deviceCoordinates() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (last.latitude, last.longitude);
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 2), onTimeout: () => throw Exception('GPS timeout'));
      return (current.latitude, current.longitude);
    } catch (_) {
      return null;
    }
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

  List<ProfessionalListing> _applyClientSideFilters(
    List<ProfessionalListing> listings, {
    required String? query,
    required String? searchLocation,
    required double? searchLat,
    required double? searchLng,
    required double? maxDistanceKm,
  }) {
    var filtered = _applyClientSideQueryGuard(listings, query: query);

    final sLoc = searchLocation?.trim().toLowerCase() ?? '';
    final isFranceSearch = sLoc.contains('france') || sLoc.contains(', fr') || sLoc == 'fr';
    final limitRadius = maxDistanceKm ?? 500.0;

    if (sLoc.isEmpty && searchLat == null && searchLng == null) {
      return filtered;
    }

    return filtered.where((p) {
      if (sLoc.isNotEmpty) {
        final locLower = p.location.toLowerCase();
        if (isFranceSearch) {
          if (locLower.contains('france') || locLower.contains('fr') || locLower.contains('paris') || locLower.contains('queaux')) {
            return true;
          }
          final servesFrance = p.serviceAreas.any((area) {
            final label = area.label?.toLowerCase() ?? '';
            return label == 'france' || label == 'fr' || label.contains('france');
          });
          if (servesFrance) return true;
        }

        final cleanSearch = sLoc.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
        final cleanLocation = locLower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
        if (cleanLocation.contains(cleanSearch) || cleanSearch.contains(cleanLocation)) {
          return true;
        }

        final hasMatchingLabel = p.serviceAreas.any((area) {
          final label = area.label?.toLowerCase() ?? '';
          if (label.isEmpty) return false;

          final cleanLabel = label.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
          final searchWords = cleanSearch.split(' ');
          final labelWords = cleanLabel.split(' ');

          if (searchWords.isNotEmpty && labelWords.isNotEmpty) {
            if (searchWords.first == labelWords.first || cleanLabel.contains(cleanSearch)) return true;
          }
          return false;
        });
        if (hasMatchingLabel) return true;
      }

      final lat1 = searchLat;
      final lng1 = searchLng;
      if (lat1 != null && lng1 != null) {
        if (p.latitude != null && p.longitude != null) {
          final dist = Geolocator.distanceBetween(lat1, lng1, p.latitude!, p.longitude!) / 1000.0;
          if (dist <= limitRadius) return true;
        }
        for (final area in p.serviceAreas) {
          if (area.latitude != null && area.longitude != null) {
            final dist = Geolocator.distanceBetween(lat1, lng1, area.latitude!, area.longitude!) / 1000.0;
            if (dist <= limitRadius) return true;
          }
        }
      }

      return false;
    }).toList();
  }
}
