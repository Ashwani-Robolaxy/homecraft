import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/support_message.dart';

class SupportRemoteDatasource {
  SupportRemoteDatasource({ApiClient? apiClient, SessionStorage? session})
      : _api = apiClient ?? ApiClient(),
        _session = session ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;

  // ── Thread management ────────────────────────────────────────────────────

  /// Finds an existing open thread for the current user/professional.
  /// Returns null if none exists yet (caller should call [createThread] lazily
  /// once the user types their first message).
  Future<int?> findExistingThread({required bool isProfessional}) async {
    final token = await _requireToken();
    final base = isProfessional ? '/professionals/support' : '/users/support';
    try {
      final listRes = await _api.get('$base/threads', token: token);
      final threads = _parseList(listRes, keys: ['threads', 'data', 'items']);
      // Prefer open threads, fall back to any thread
      int? anyId;
      for (final t in threads) {
        final id = _parseInt(t['id']);
        if (id == null) continue;
        anyId ??= id;
        final status = (t['status'] ?? '').toString().toLowerCase();
        if (status == 'open') return id;
      }
      return anyId;
    } catch (_) {
      return null;
    }
  }

  /// Creates a new thread AND sends the first message in one go.
  /// The API requires an initial [body] when opening a thread.
  Future<({int threadId, SupportMessage message})> createThreadWithMessage({
    required bool isProfessional,
    required String body,
    String subject = 'Support Request',
  }) async {
    final token = await _requireToken();
    final base = isProfessional ? '/professionals/support' : '/users/support';

    final createRes = await _api.post(
      '$base/threads',
      body: {'subject': subject, 'body': body.trim()},
      token: token,
    );

    final threadId = _extractThreadId(createRes);
    if (threadId == null) throw ApiException('Could not open support thread.');

    // The creation response may already include the first message
    SupportMessage? firstMsg;
    for (final key in ['messageItem', 'message', 'firstMessage']) {
      final raw = createRes[key];
      if (raw is Map) {
        firstMsg =
            SupportMessage.fromMap(Map<String, dynamic>.from(raw));
        break;
      }
    }

    // Fallback: construct a local message so the UI shows it immediately
    firstMsg ??= SupportMessage.fromMap({
      'id': 0,
      'threadId': threadId,
      'senderRole': isProfessional ? 'professional' : 'user',
      'body': body.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    return (threadId: threadId, message: firstMsg);
  }

  // ── Message history ──────────────────────────────────────────────────────

  Future<List<SupportMessage>> fetchMessages(
    int threadId, {
    required bool isProfessional,
    int limit = 50,
  }) async {
    final token = await _requireToken();
    final base = isProfessional ? '/professionals/support' : '/users/support';
    try {
      final res = await _api.get(
        '$base/threads/$threadId/messages?limit=$limit',
        token: token,
      );
      final raw = _parseList(res, keys: ['messages', 'data', 'items']);
      return raw
          .map((e) => SupportMessage.fromMap(Map<String, dynamic>.from(e)))
          .where((m) => m.body.isNotEmpty)
          .toList();
    } catch (e) {
      // History load failed – real-time socket messages still work.
      // ignore: avoid_print
      print('[Support] fetchMessages failed (non-fatal): $e');
      return [];
    }
  }

  // ── Send via REST (fallback when socket is unavailable) ──────────────────

  Future<SupportMessage?> sendMessage(
    int threadId,
    String body, {
    required bool isProfessional,
  }) async {
    final token = await _requireToken();
    final base = isProfessional ? '/professionals/support' : '/users/support';
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      final res = await _api.post(
        '$base/threads/$threadId/messages',
        body: {'body': text},
        token: token,
      );
      final raw = res['messageItem'] ?? res['message'] ?? res['data'];
      if (raw is Map) {
        return SupportMessage.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      throw ApiException('Failed to send message.');
    }
    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<String> _requireToken() async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again.');
    }
    return token;
  }

  int? _extractThreadId(Map<String, dynamic> map) {
    dynamic raw = map['threadId'] ?? map['id'];
    for (final key in ['thread', 'data', 'result']) {
      if (raw != null) break;
      final nested = map[key];
      if (nested is Map) raw = nested['threadId'] ?? nested['id'];
    }
    return _parseInt(raw);
  }

  List<Map<String, dynamic>> _parseList(
    Map<String, dynamic> map, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final v = map[key];
      if (v is List) {
        return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
