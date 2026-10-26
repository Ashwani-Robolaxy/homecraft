/// One service coverage point for [PUT /professionals/complete-profile] (`serviceAreaCities`).
/// Swagger: `latitude` / `longitude` (or `lat` / `lng` / `long` on write), optional `label`.
class ServiceAreaLocation {
  const ServiceAreaLocation({this.latitude, this.longitude, this.label});

  final double? latitude;
  final double? longitude;
  final String? label;

  bool get isValidForApi {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  String get displayLabel {
    if (label != null && label!.trim().isNotEmpty) return label!.trim();
    final lat = latitude;
    final lng = longitude;
    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
    return 'Unknown area';
  }

  /// Payload for `serviceAreaCities` on [PUT /professionals/complete-profile]:
  /// numeric `latitude` / `longitude` (Swagger also allows `lat` / `lng` / `long`).
  /// Plain city strings must not be sent — only geocoded numbers + optional `label`.
  Map<String, dynamic> toCompleteProfileJson() {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      throw StateError(
        'serviceAreaCities entry must include latitude and longitude',
      );
    }
    return {
      'latitude': lat.toDouble(),
      'longitude': lng.toDouble(),
      if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
    };
  }

  factory ServiceAreaLocation.fromJson(Map<String, dynamic> m) {
    return ServiceAreaLocation(
      latitude: _parseDouble(m['latitude'] ?? m['lat']),
      longitude: _parseDouble(m['longitude'] ?? m['lng'] ?? m['long']),
      label: m['label']?.toString(),
    );
  }

  /// API may return coordinate objects; older rows may be plain strings (legacy).
  factory ServiceAreaLocation.fromDynamic(dynamic e) {
    if (e is Map) {
      return ServiceAreaLocation.fromJson(Map<String, dynamic>.from(e));
    }
    if (e is String) {
      return ServiceAreaLocation(label: e);
    }
    return const ServiceAreaLocation();
  }

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool isSameLocation(ServiceAreaLocation other) {
    final a = latitude;
    final b = longitude;
    final oa = other.latitude;
    final ob = other.longitude;
    if (a == null || b == null || oa == null || ob == null) return false;
    return (a - oa).abs() < 1e-4 && (b - ob).abs() < 1e-4;
  }
}
