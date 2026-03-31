class Project {
  final String id;
  final String title;
  final String description;
  final String location;
  final String date;
  final String? serviceType;
  final String? budget;
  final String? imageUrl;
  final int acceptedCount;
  final List<ProjectComment> comments;

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
    this.budget,
    this.imageUrl,
    this.acceptedCount = 0,
    this.comments = const [],
    this.clientUserId,
    this.clientDisplayName,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    final client = _parseClientFields(map);
    return Project(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? map['descriptionPreview'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      date: _displayDate((map['desiredDate'] ?? map['date'] ?? '').toString()),
      serviceType: _displayServiceType(map),
      budget: _displayBudget((map['budgetAmount'] ?? map['budget'] ?? '').toString()),
      imageUrl: (map['attachmentUrl'] ?? map['imageUrl'])?.toString(),
      acceptedCount: (map['acceptedCount'] as num?)?.toInt() ?? 0,
      clientUserId: client.$1,
      clientDisplayName: client.$2,
    );
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
      // API format: yyyy-MM-dd -> UI format: MM-dd-yyyy
      return '${parts[1]}-${parts[2]}-${parts[0]}';
    }
    return raw;
  }

  static String? _displayBudget(String raw) {
    if (raw.trim().isEmpty) return null;
    final amount = double.tryParse(raw.trim());
    if (amount == null) return raw;
    final whole = amount.round();
    final digits = whole.toString();
    final withSeparators = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '€ $withSeparators';
  }

  static String? _displayServiceType(Map<String, dynamic> map) {
    final categoryName = (map['categoryName'] ?? '').toString().trim();
    if (categoryName.isNotEmpty) return categoryName;
    final slug = (map['categorySlug'] ?? '').toString().trim();
    if (slug.isEmpty) return null;
    return slug
        .split(RegExp(r'[_-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class ProjectComment {
  final String userName;
  final String userAvatar;
  final String text;
  final int hoursAgo;

  ProjectComment({required this.userName, required this.userAvatar, required this.text, required this.hoursAgo});
}
