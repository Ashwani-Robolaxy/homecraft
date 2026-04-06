import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/chat_message.dart';

class ChatRemoteDatasource {
  ChatRemoteDatasource({ApiClient? apiClient, SessionStorage? session})
      : _api = apiClient ?? ApiClient(),
        _session = session ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;

  // ── Conversation creation ───────────────────────────────────────────────

  /// Professional opens/gets a conversation with a client.
  /// POST /professionals/chat/conversations  { userId }
  Future<int> createOrGetProfessionalConversation(String userId) async {
    final token = await _requireToken();
    final trimmed = userId.trim();
    if (trimmed.isEmpty) throw ApiException('Missing client.');
    final map = await _api.post(
      '/professionals/chat/conversations',
      body: {'userId': trimmed},
      token: token,
    );
    return _requireConversationId(map);
  }

  /// Client opens/gets a conversation with a professional.
  /// POST /users/chat/conversations  { professionalId }
  Future<int> createOrGetUserConversation(String professionalId) async {
    final token = await _requireToken();
    final trimmed = professionalId.trim();
    if (trimmed.isEmpty) throw ApiException('Missing professional.');
    final map = await _api.post(
      '/users/chat/conversations',
      body: {'professionalId': trimmed},
      token: token,
    );
    return _requireConversationId(map);
  }

  // ── Message history ─────────────────────────────────────────────────────

  /// Fetch existing messages for [conversationId].
  /// Tries both user and professional endpoints and returns whichever works.
  Future<List<ChatMessage>> fetchMessages(
    int conversationId, {
    required bool isCurrentUserProfessional,
  }) async {
    final token = await _requireToken();
    final base = isCurrentUserProfessional
        ? '/professionals/chat/conversations'
        : '/users/chat/conversations';

    try {
      final map = await _api.get(
        '$base/$conversationId/messages',
        token: token,
      );
      return _parseMessages(map, isCurrentUserProfessional: isCurrentUserProfessional);
    } catch (e) {
      // Server error on history load – messages are still delivered via socket.
      // ignore: avoid_print
      print('[Chat] fetchMessages failed (non-fatal): $e');
      return [];
    }
  }

  // ── Conversation list ────────────────────────────────────────────────────

  /// List all conversations for the current user.
  Future<List<Map<String, dynamic>>> listConversations({
    required bool isCurrentUserProfessional,
  }) async {
    final token = await _requireToken();
    final path = isCurrentUserProfessional
        ? '/professionals/chat/conversations'
        : '/users/chat/conversations';
    try {
      final map = await _api.get(path, token: token);
      // ignore: avoid_print
      print('[Chat] listConversations raw keys: ${map.keys.toList()}');
      final data = map['data'] ?? map['conversations'] ?? map;
      if (data is List && data.isNotEmpty) {
        final first = data.first;
        // ignore: avoid_print
        print('[Chat] first conversation keys: ${first is Map ? first.keys.toList() : first}');
        // ignore: avoid_print
        if (first is Map) print('[Chat] first conversation: $first');
      }
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<String> _requireToken() async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to use chat.');
    }
    return token;
  }

  int _requireConversationId(Map<String, dynamic> map) {
    final id = _conversationIdFrom(map);
    if (id == null) throw ApiException('Could not open conversation.');
    return id;
  }

  int? _conversationIdFrom(Map<String, dynamic> map) {
    // Try common top-level keys first
    dynamic raw = map['conversationId'] ?? map['id'];

    // Try nested under 'conversation', 'data', or 'result'
    for (final key in ['conversation', 'data', 'result']) {
      if (raw != null) break;
      final nested = map[key];
      if (nested is Map) {
        raw = nested['conversationId'] ?? nested['id'];
      }
    }

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  List<ChatMessage> _parseMessages(
    Map<String, dynamic> map, {
    required bool isCurrentUserProfessional,
  }) {
    final raw = map['data'] ?? map['messages'] ?? map['items'] ?? [];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ChatMessage.fromServerPayload(
              e,
              isCurrentUserProfessional: isCurrentUserProfessional,
            ))
        .where((m) => m.body.isNotEmpty)
        .toList();
  }
}
