class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.threadId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final int threadId;

  /// `user`, `professional`, or `admin`
  final String senderRole;
  final String body;
  final DateTime createdAt;

  /// Whether this message was sent by the currently logged-in user/professional
  /// (i.e. not by admin).
  bool get isMine => senderRole != 'admin';

  factory SupportMessage.fromMap(Map<String, dynamic> map) {
    return SupportMessage(
      id: _parseInt(map['id']) ?? 0,
      threadId: _parseInt(map['threadId']) ?? 0,
      senderRole: (map['senderRole'] ?? '').toString().toLowerCase(),
      body: (map['body'] ?? '').toString(),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
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
