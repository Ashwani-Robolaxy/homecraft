import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/domain/models/service_area_location.dart';

/// Same Google Cloud key as address autocomplete in provider setup screens.
/// Restrict this key by iOS/Android bundle IDs and APIs in Google Cloud Console.
const String kGoogleMapsPlacesApiKey = 'AIzaSyDmS2dadlo4YW7AR4iDlKcJtNGRc-mnTSA';

class PlaceAutocompleteSuggestion {
  const PlaceAutocompleteSuggestion({required this.description, required this.placeId});

  final String description;
  final String placeId;
}

/// Client-side Places + geocoding (Swagger: API does not geocode for you).
class GooglePlacesService {
  GooglePlacesService({required this.sessionToken});

  final String sessionToken;

  Future<List<PlaceAutocompleteSuggestion>> autocomplete(String input, {String types = 'geocode'}) async {
    final q = input.trim();
    if (q.length < 2) return [];
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': q,
      'types': types,
      'language': 'fr',
      'components': 'country:fr',
      'sessiontoken': sessionToken,
      'key': kGoogleMapsPlacesApiKey,
    });
    final res = await http.get(uri);
    if (res.body.isEmpty) return [];
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final status = (map['status'] ?? '').toString();
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];
    final predictions = map['predictions'];
    if (predictions is! List) return [];
    return predictions
        .whereType<Map>()
        .map((e) => PlaceAutocompleteSuggestion(description: (e['description'] ?? '').toString(), placeId: (e['place_id'] ?? '').toString()))
        .where((e) => e.placeId.isNotEmpty)
        .toList();
  }

  Future<ServiceAreaLocation?> placeDetails(String placeId) async {
    if (placeId.isEmpty) return null;
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {'place_id': placeId, 'fields': 'geometry/location,formatted_address', 'key': kGoogleMapsPlacesApiKey});
    final res = await http.get(uri);
    if (res.body.isEmpty) return null;
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    if ((map['status'] ?? '').toString() != 'OK') return null;
    final result = map['result'];
    if (result is! Map) return null;
    final geometry = result['geometry'];
    if (geometry is! Map) return null;
    final loc = geometry['location'];
    if (loc is! Map) return null;
    final lat = _toDouble(loc['lat']);
    final lng = _toDouble(loc['lng']);
    if (lat == null || lng == null) return null;
    final formatted = (result['formatted_address'] ?? '').toString().trim();
    return ServiceAreaLocation(latitude: lat, longitude: lng, label: formatted.isNotEmpty ? formatted : null);
  }

  /// Fallback when user taps "Add Area" with free text (no suggestion selected).
  Future<ServiceAreaLocation?> geocodeAddress(String address) async {
    final q = address.trim();
    if (q.isEmpty) return null;
    final google = await geocodeWithGoogleGeocodingApi(q);
    if (google != null) return google;
    try {
      final locations = await locationFromAddress(q);
      if (locations.isEmpty) return null;
      final l = locations.first;
      return ServiceAreaLocation(latitude: l.latitude, longitude: l.longitude, label: q);
    } catch (_) {
      return null;
    }
  }

  /// Google Geocoding API (same key as Places). Better worldwide coverage than [locationFromAddress].
  static Future<ServiceAreaLocation?> geocodeWithGoogleGeocodingApi(String address) async {
    final q = address.trim();
    if (q.isEmpty) return null;
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {'address': q, 'region': 'fr', 'key': kGoogleMapsPlacesApiKey});
      final res = await http.get(uri);
      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      if ((decoded['status'] ?? '').toString() != 'OK') return null;
      final results = decoded['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final geometry = first['geometry'];
      if (geometry is! Map) return null;
      final location = geometry['location'];
      if (location is! Map) return null;
      final lat = _toDouble(location['lat']);
      final lng = _toDouble(location['lng']);
      if (lat == null || lng == null) return null;
      final formatted = (first['formatted_address'] ?? '').toString().trim();
      return ServiceAreaLocation(latitude: lat, longitude: lng, label: formatted.isNotEmpty ? formatted : null);
    } catch (_) {
      return null;
    }
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
