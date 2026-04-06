import '../../../core/network/api_config.dart';
import 'favorite_item.dart';

class FavoriteCollection {
  const FavoriteCollection({
    required this.id,
    required this.name,
    this.itemCount = 0,
    this.coverImageUrl,
    this.items = const [],
  });

  final int id;
  final String name;
  final int itemCount;
  final String? coverImageUrl;

  /// Items belonging to this collection (populated when available).
  final List<FavoriteItem> items;

  /// Up to 4 cover images for the Instagram-style grid thumbnail.
  List<String> get coverImages {
    final urls = items
        .where((i) => i.imageUrl != null && i.imageUrl!.isNotEmpty)
        .map((i) => i.imageUrl!)
        .take(4)
        .toList();
    if (urls.isEmpty && coverImageUrl != null) return [coverImageUrl!];
    return urls;
  }

  FavoriteCollection copyWith({
    int? id,
    String? name,
    int? itemCount,
    String? coverImageUrl,
    List<FavoriteItem>? items,
  }) =>
      FavoriteCollection(
        id: id ?? this.id,
        name: name ?? this.name,
        itemCount: itemCount ?? this.itemCount,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        items: items ?? this.items,
      );

  factory FavoriteCollection.fromMap(Map<String, dynamic> map) {
    final id = _parseInt(map['id'] ?? map['listId']) ?? 0;
    final name = (map['name'] ?? map['title'] ?? 'Collection').toString().trim();
    final count = _parseInt(map['itemCount'] ?? map['count'] ?? map['total']) ?? 0;
    final rawCover = map['coverImageUrl'] ?? map['coverPhoto'] ?? map['image'];
    return FavoriteCollection(
      id: id,
      name: name,
      itemCount: count,
      coverImageUrl: _absoluteUrl(rawCover?.toString()),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String? _absoluteUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return '$base${raw.startsWith('/') ? raw : '/$raw'}';
  }
}
