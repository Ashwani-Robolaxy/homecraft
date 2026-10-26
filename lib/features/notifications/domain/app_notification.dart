class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  static String _readString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static bool _readBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static DateTime _readDate(Map<String, dynamic> m) {
    final raw = m['createdAt'] ??
        m['created_at'] ??
        m['sentAt'] ??
        m['sent_at'] ??
        m['timestamp'] ??
        m['time'] ??
        m['date'];
    if (raw == null) return DateTime.now();

    if (raw is DateTime) return raw;
    if (raw is num) {
      // Handle seconds and milliseconds.
      final n = raw.toInt();
      final ms = n < 1000000000000 ? n * 1000 : n;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return DateTime.now();
    final numeric = int.tryParse(s);
    if (numeric != null) {
      final ms = numeric < 1000000000000 ? numeric * 1000 : numeric;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  static AppNotification fromMap(Map<String, dynamic> m) {
    final id = _readString(m, const ['id', 'notificationId', 'notification_id', 'uuid']);

    // Some payloads wrap message fields under `data`.
    final nested = m['data'];
    final payload = nested is Map ? Map<String, dynamic>.from(nested) : const <String, dynamic>{};

    final title = _readString(m, const ['title', 'heading', 'subject']);
    final body = _readString(m, const ['body', 'message', 'content', 'text', 'description']);
    final nestedTitle = _readString(payload, const ['title', 'heading', 'subject']);
    final nestedBody = _readString(payload, const ['body', 'message', 'content', 'text', 'description']);

    return AppNotification(
      id: id,
      title: title.isNotEmpty ? title : nestedTitle,
      body: body.isNotEmpty ? body : nestedBody,
      type: _readString(m, const ['type', 'category', 'eventType', 'event_type']).isNotEmpty
          ? _readString(m, const ['type', 'category', 'eventType', 'event_type'])
          : 'general',
      isRead: _readBool(m['isRead'] ?? m['is_read'] ?? m['read'] ?? m['seen']),
      createdAt: _readDate(m),
    );
  }
}
