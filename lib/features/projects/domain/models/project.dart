import '../../../../core/network/api_config.dart';

class Project {
  final String id;
  final String title;
  final String description;
  final String location;
  final String date;
  final String? serviceType;
  final int? categoryId;
  final String? budget;

  /// Raw budget for filtering (e.g. map / radius UI). May be null if absent.
  final double? budgetAmount;
  final String? imageUrl;
  final int acceptedCount;
  final List<ProjectComment> comments;

  /// When API sends coordinates (optional — often only [location] text is present).
  final double? latitude;
  final double? longitude;

  /// Client (project owner) user id when returned for professionals — used for chat.
  final String? clientUserId;

  /// Display name for client when available.
  final String? clientDisplayName;

  Project({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    this.serviceType,
    this.categoryId,
    this.budget,
    this.budgetAmount,
    this.imageUrl,
    this.acceptedCount = 0,
    this.comments = const [],
    this.latitude,
    this.longitude,
    this.clientUserId,
    this.clientDisplayName,
  });

  Project copyWith({
    int? acceptedCount,
  }) {
    return Project(
      id: id,
      title: title,
      description: description,
      location: location,
      date: date,
      serviceType: serviceType,
      categoryId: categoryId,
      budget: budget,
      budgetAmount: budgetAmount,
      imageUrl: imageUrl,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      comments: comments,
      latitude: latitude,
      longitude: longitude,
      clientUserId: clientUserId,
      clientDisplayName: clientDisplayName,
    );
  }


  factory Project.fromMap(Map<String, dynamic> map) {
    final pMap = map['project'] is Map ? map['project'] as Map<String, dynamic> : map;
    final idStr = (pMap['id'] ?? pMap['projectId'] ?? map['id'] ?? '').toString();
    final client = _parseClientFields(map);
    final rawBudget = (map['budgetAmount'] ?? map['budget'] ?? '').toString();
    var lat = _parseDouble(map['latitude'] ?? map['lat']);
    var lng = _parseDouble(map['longitude'] ?? map['lng'] ?? map['long']);
    if (lat == null || lng == null) {
      final loc = map['location'];
      if (loc is Map) {
        final m = Map<String, dynamic>.from(loc);
        lat ??= _parseDouble(m['latitude'] ?? m['lat']);
        lng ??= _parseDouble(m['longitude'] ?? m['lng'] ?? m['long']);
      }
    }
    return Project(
      id: idStr,
      title: (pMap['title'] ?? map['title'] ?? '').toString(),
      description: (pMap['description'] ?? pMap['descriptionPreview'] ?? map['description'] ?? map['descriptionPreview'] ?? '').toString(),
      location: _locationString(pMap['location'] ?? map['location']),
      date: _displayDate((pMap['desiredDate'] ?? pMap['date'] ?? map['desiredDate'] ?? map['date'] ?? '').toString()),
      serviceType: _displayServiceType(pMap) ?? _displayServiceType(map),
      categoryId: _parseInt(pMap['categoryId'] ?? pMap['category_id'] ?? map['categoryId'] ?? map['category_id']),
      budget: _displayBudget(rawBudget),
      budgetAmount: _parseBudgetAmount(rawBudget),
      imageUrl: _absoluteUrl((pMap['attachmentUrl'] ?? pMap['imageUrl'] ?? pMap['attachment'] ?? pMap['image'] ?? map['attachmentUrl'] ?? map['imageUrl'] ?? map['attachment'] ?? map['image'])?.toString()),
      acceptedCount: _parseAcceptedCount(
        pMap['interestedCount'] ?? pMap['interestCount'] ?? pMap['interestsCount'] ?? pMap['totalInterests'] ?? pMap['acceptedCount'] ??
        map['interestedCount'] ?? map['interestCount'] ?? map['interestsCount'] ?? map['totalInterests'] ?? map['acceptedCount'],
        pMap['accepted'] ?? map['accepted'] ?? pMap['isAccepted'] ?? map['isAccepted'],
        pMap['status'] ?? map['status'],
      ),
      latitude: lat,
      longitude: lng,
      clientUserId: client.$1 ?? _topLevelOwnerId(map),
      clientDisplayName: client.$2,
    );
  }

  /// When nested `client` is missing, some list endpoints still send owner id on the root.
  static String? _topLevelOwnerId(Map<String, dynamic> map) {
    for (final k in ['userId', 'ownerId', 'clientUserId', 'ownerUserId']) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static int _parseAcceptedCount(dynamic acceptedCountVal, dynamic acceptedVal, dynamic statusVal) {
    if (statusVal != null && statusVal.toString().toLowerCase() == 'accepted') {
      return 1;
    }
    if (acceptedCountVal != null) {
      if (acceptedCountVal is num) return acceptedCountVal.toInt();
      return int.tryParse(acceptedCountVal.toString()) ?? 0;
    }
    if (acceptedVal != null) {
      if (acceptedVal is bool) return acceptedVal ? 1 : 0;
      if (acceptedVal is num) return acceptedVal.toInt();
      if (acceptedVal is String) {
        final lower = acceptedVal.toLowerCase();
        if (lower == 'true') return 1;
        if (lower == 'false') return 0;
        return int.tryParse(acceptedVal) ?? 0;
      }
    }
    return 0;
  }

  static String? _absoluteUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final path = s.startsWith('/') ? s : '/$s';
    // Fix Windows backslashes if any.
    return '$base${path.replaceAll(r'\', '/')}';
  }

  static String _locationString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      for (final key in ['formattedAddress', 'address', 'formatted_address', 'label', 'name']) {
        final s = (m[key] ?? '').toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return v.toString().trim();
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static double? _parseBudgetAmount(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t.replaceAll(',', ''));
    return n;
  }

  static (String?, String?) _parseClientFields(Map<String, dynamic> map) {
    dynamic node = map['client'];
    node ??= map['user'];
    node ??= map['owner'];
    if (node is! Map) return (null, null);
    final c = Map<String, dynamic>.from(node);
    final rawId = c['id'] ?? c['userId'];
    final uid = rawId != null && rawId.toString().trim().isNotEmpty ? rawId.toString().trim() : null;
    var name = (c['username'] ?? c['name'] ?? c['fullName'] ?? c['email'] ?? '').toString().trim();
    if (name.isEmpty) name = '';
    return (uid, name.isEmpty ? null : name);
  }

  static String _displayDate(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw.length >= 10 ? raw.substring(0, 10) : raw;
    final parts = normalized.split('-');
    if (parts.length == 3) {
      // API format: yyyy-MM-dd -> UI format: dd/MM/yyyy
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return raw;
  }

  static String? _displayBudget(String raw) {
    if (raw.trim().isEmpty) return null;
    final amount = double.tryParse(raw.trim());
    if (amount == null) return raw;
    final whole = amount.round();
    final digits = whole.toString();
    final withSeparators = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    return '€ $withSeparators';
  }

  static String? _displayServiceType(Map<String, dynamic> map) {
    final categoryName = (map['categoryName'] ?? '').toString().trim();
    if (categoryName.isNotEmpty) return categoryName;
    final slug = (map['categorySlug'] ?? '').toString().trim();
    if (slug.isEmpty) return null;
    return slug.split(RegExp(r'[_-]+')).where((part) => part.isNotEmpty).map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
  }
}

class ProjectComment {
  final String userName;
  final String userAvatar;
  final String text;
  final int hoursAgo;

  ProjectComment({required this.userName, required this.userAvatar, required this.text, required this.hoursAgo});
}

class ProjectInterest {
  final String professionalId;
  final String professionalName;
  final String professionalSubtitle;
  final String? professionalImageUrl;
  final String comment;
  final DateTime? createdAt;

  ProjectInterest({
    required this.professionalId,
    required this.professionalName,
    required this.professionalSubtitle,
    required this.professionalImageUrl,
    required this.comment,
    this.createdAt,
  });
}

class ProfessionalInterestedProject {
  final Project project;
  final String? professionalComment;
  final String? interestCreatedAt;

  ProfessionalInterestedProject({
    required this.project,
    this.professionalComment,
    this.interestCreatedAt,
  });

  factory ProfessionalInterestedProject.fromMap(Map<String, dynamic> map) {
    return ProfessionalInterestedProject(
      project: Project.fromMap(map),
      professionalComment: map['professionalComment'] as String?,
      interestCreatedAt: map['interestCreatedAt'] as String?,
    );
  }
}
