import '../../../core/network/api_config.dart';

enum FavoriteType { professional, project, user, unknown }

class FavoriteItem {
  const FavoriteItem({required this.favoriteId, required this.type, required this.itemId, required this.title, required this.subtitle, this.imageUrl, this.createdAt, this.verificationStatus, this.rawData});

  /// The ID of the favorite record itself (used for deletion).
  final int favoriteId;
  final FavoriteType type;

  /// The ID of the actual professional or project.
  final String itemId;

  /// Display name / project title.
  final String title;

  /// Role / specialty / service type.
  final String subtitle;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? verificationStatus;
  final Map<String, dynamic>? rawData;

  bool get isPro => verificationStatus == 'verified';

  FavoriteItem copyWith({
    int? favoriteId,
    FavoriteType? type,
    String? itemId,
    String? title,
    String? subtitle,
    String? imageUrl,
    DateTime? createdAt,
    String? verificationStatus,
    Map<String, dynamic>? rawData,
  }) {
    return FavoriteItem(
      favoriteId: favoriteId ?? this.favoriteId,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rawData: rawData ?? this.rawData,
    );
  }

  factory FavoriteItem.fromMap(Map<String, dynamic> map) {
    // API uses targetType / targetId
    final typeRaw = (map['targetType'] ?? map['type'] ?? map['itemType'] ?? '').toString().toLowerCase().trim();
    // Order matters: "project" contains "proj" but must not match "professional".
    final FavoriteType type;
    switch (typeRaw) {
      case 'project':
        type = FavoriteType.project;
        break;
      case 'user':
        type = FavoriteType.user;
        break;
      case 'professional':
        type = FavoriteType.professional;
        break;
      default:
        if (typeRaw.contains('project')) {
          type = FavoriteType.project;
        } else if (typeRaw == 'user' || typeRaw.contains('customer') || typeRaw.contains('client')) {
          type = FavoriteType.user;
        } else if (typeRaw.contains('professional')) {
          type = FavoriteType.professional;
        } else {
          type = FavoriteType.unknown;
        }
    }

    final favoriteId = _parseInt(map['id'] ?? map['favoriteId']) ?? 0;
    final nested = _firstMap([map['target'], map['professional'], map['project'], map['item'], map['data']]);
    final effective = nested ?? map;
    final user = _firstMap([effective['user'], map['user']]);

    final itemId = _firstNonEmpty([map['targetId'], map['itemId'], map['professionalId'], map['projectId'], effective['id'], effective['_id'], effective['userId']]) ?? '';

    final title =
        _firstNonEmpty([
          effective['displayName'],
          effective['fullName'],
          effective['username'],
          effective['companyName'],
          effective['name'],
          effective['title'],
          _composeName(effective),
          if (user != null) ...[user['displayName'], user['fullName'], user['username'], user['companyName'], user['name'], _composeName(user)],
        ]) ??
        'Unknown';

    final subtitle =
        _firstNonEmpty([effective['specialty'], effective['speciality'], effective['role'], effective['jobTitle'], effective['categoryName'], effective['serviceType'], effective['profession']]) ?? '';

    final nestedProj = effective['project'] is Map ? Map<String, dynamic>.from(effective['project']) : null;
    final nestedPro = effective['professional'] is Map ? Map<String, dynamic>.from(effective['professional']) : null;

    final rawPhoto = _firstNonEmpty([
      effective['profilePhotoUrl'],
      effective['profilePhoto'],
      effective['profilePicture'],
      effective['profileImage'],
      effective['profile_photo'],
      effective['profile_image'],
      effective['picture'],
      effective['photo'],
      effective['image'],
      effective['thumbnail'],
      effective['avatarUrl'],
      effective['avatar'],
      effective['coverPhotoUrl'],
      effective['attachmentUrl'],
      effective['attachment'],
      effective['imageUrl'],
      effective['photoUrl'],
      if (nestedProj != null) ...[
        nestedProj['attachmentUrl'],
        nestedProj['attachment'],
        nestedProj['imageUrl'],
        nestedProj['image'],
      ],
      if (nestedPro != null) ...[
        nestedPro['profilePhotoUrl'],
        nestedPro['avatarUrl'],
        nestedPro['imageUrl'],
        nestedPro['avatar'],
        nestedPro['image'],
      ],
      if (user != null) ...[
        user['profilePhotoUrl'],
        user['profilePhoto'],
        user['profilePicture'],
        user['profileImage'],
        user['profile_photo'],
        user['profile_image'],
        user['picture'],
        user['photo'],
        user['image'],
        user['avatarUrl'],
        user['avatar'],
      ],
    ]);

    final verificationStatus = _firstNonEmpty([effective['verificationStatus'], if (user != null) user['verificationStatus']]);

    return FavoriteItem(
      favoriteId: favoriteId,
      type: type,
      itemId: itemId,
      title: title,
      subtitle: subtitle,
      imageUrl: _absoluteUrl(rawPhoto) ?? _findDeepImage(map),
      createdAt: _parseDate(map['createdAt']),
      verificationStatus: verificationStatus,
      rawData: effective,
    );
  }

  static String? _findDeepImage(dynamic obj) {
    if (obj is Map) {
      final keys = [
        'attachmentUrl', 'imageUrl', 'profilePhotoUrl', 'photoUrl', 'avatarUrl', 'coverPhotoUrl',
        'attachment', 'image', 'photo', 'picture', 'avatar', 'thumbnail',
        'profilePhoto', 'profilePicture', 'profileImage', 'profile_photo', 'profile_image'
      ];
      for (final k in keys) {
        if (obj[k] != null && obj[k].toString().trim().isNotEmpty) {
          final s = obj[k].toString().trim();
          if (s.startsWith('http') || s.startsWith('/')) {
            return s.startsWith('/') ? 'http://13.39.19.165:5000$s' : s;
          }
        }
      }
      for (final v in obj.values) {
        final res = _findDeepImage(v);
        if (res != null) return res;
      }
    } else if (obj is List) {
      for (final v in obj) {
        final res = _findDeepImage(v);
        if (res != null) return res;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _firstMap(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is Map) return Map<String, dynamic>.from(c);
    }
    return null;
  }

  static String? _composeName(Map<String, dynamic> m) {
    final first = (m['firstName'] ?? '').toString().trim();
    final last = (m['lastName'] ?? '').toString().trim();
    if (first.isEmpty && last.isEmpty) return null;
    return '$first $last'.trim();
  }

  static String? _firstNonEmpty(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String? _absoluteUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    final path = s.startsWith('/') ? s : '/$s';
    return '$base${path.replaceAll(r'\', '/')}';
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
