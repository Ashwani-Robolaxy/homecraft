class ChatMessage {
  const ChatMessage({
    required this.body,
    required this.isMine,
    this.id,
    this.createdAt,
    this.pending = false,
  });

  final int? id;
  final String body;
  final bool isMine;
  final DateTime? createdAt;
  final bool pending;

  /// Parse a server-pushed message.
  ///
  /// [isCurrentUserProfessional] — pass `true` when the logged-in user is a
  /// professional so that messages with senderRole=='professional' are treated
  /// as "mine". Pass `false` for a client user.
  factory ChatMessage.fromServerPayload(
    dynamic raw, {
    bool isCurrentUserProfessional = true,
  }) {
    if (raw is! Map) return const ChatMessage(body: '', isMine: false);
    final map = Map<String, dynamic>.from(raw);
    final id = _parseInt(map['id']);
    final body = (map['body'] ?? '').toString();
    final role = (map['senderRole'] ?? '').toString().toLowerCase();

    final bool isMine;
    if (isCurrentUserProfessional) {
      isMine = role == 'professional' || role == 'provider';
    } else {
      isMine = role == 'user' || role == 'client';
    }

    return ChatMessage(
      id: id,
      body: body,
      isMine: isMine,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  static ChatMessage? fromSendAck(
    dynamic ack, {
    bool isCurrentUserProfessional = true,
  }) {
    if (ack is! Map) return null;
    final map = Map<String, dynamic>.from(ack);
    if (map['ok'] != true) return null;
    final msg = map['message'];
    if (msg is! Map) return null;
    return ChatMessage.fromServerPayload(
      msg,
      isCurrentUserProfessional: isCurrentUserProfessional,
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
