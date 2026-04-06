import '../../../../core/network/api_config.dart';

class PortfolioPhoto {
  const PortfolioPhoto({required this.id, required this.url});

  final int id;
  final String url;

  factory PortfolioPhoto.fromMap(Map<String, dynamic> map) {
    final id = _toInt(map['id']) ?? 0;
    final raw = (map['url'] ?? map['photoUrl'] ?? map['imageUrl'] ?? '').toString().trim();
    final url = _toAbsoluteUrl(raw);
    return PortfolioPhoto(id: id, url: url);
  }

  static String toAbsoluteUrl(String raw) => _toAbsoluteUrl(raw);

  static String _toAbsoluteUrl(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$base$path';
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.title,
    required this.description,
    required this.photos,
    this.completedPlace,
    this.amount,
  });

  final int id;
  final String title;
  final String description;
  final String? completedPlace;
  final double? amount;
  final List<PortfolioPhoto> photos;

  factory PortfolioItem.fromMap(Map<String, dynamic> map) {
    final photos = _extractPhotos(map);
    return PortfolioItem(
      id: _toInt(map['id']) ?? 0,
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      completedPlace: _toNullableString(map['completedPlace']),
      amount: _toDouble(map['amount']),
      photos: photos,
    );
  }

  static List<PortfolioPhoto> _extractPhotos(Map<String, dynamic> map) {
    dynamic raw = map['photos'];
    raw ??= map['images'];
    raw ??= map['photoUrls'];
    if (raw is! List) return const [];

    final list = <PortfolioPhoto>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        final p = PortfolioPhoto.fromMap(e);
        if (p.id > 0 && p.url.isNotEmpty) list.add(p);
      } else if (e is String && e.trim().isNotEmpty) {
        list.add(PortfolioPhoto(id: list.length + 1, url: e.trim()));
      }
    }
    return list;
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
