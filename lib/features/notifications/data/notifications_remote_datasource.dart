import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/app_notification.dart';

class NotificationsRemoteDatasource {
  NotificationsRemoteDatasource({ApiClient? apiClient, SessionStorage? session})
      : _api = apiClient ?? ApiClient(),
        _session = session ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;

  Future<String> _requireToken() async {
    final t = await _session.getToken();
    if (t == null || t.isEmpty) {
      throw ApiException('Not signed in.');
    }
    return t;
  }

  String _base(bool isProfessional) => isProfessional ? '/professionals' : '/users';

  List<Map<String, dynamic>> _pickNotifications(Map<String, dynamic> res) {
    for (final key in ['notifications', 'items', 'data', 'results']) {
      final v = res[key];
      if (v is List) {
        return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  /// GET …/notifications — [beforeId] for cursor pagination.
  Future<List<AppNotification>> fetchNotifications({
    required bool isProfessional,
    int limit = 50,
    String? beforeId,
  }) async {
    final token = await _requireToken();
    final q = <String, String>{
      'limit': '$limit',
      if (beforeId != null && beforeId.isNotEmpty) 'beforeId': beforeId,
    };
    final qs = '?${q.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    try {
      final res = await _api.get('${_base(isProfessional)}/notifications$qs', token: token);
      if (kDebugMode) {
        debugPrint('[Notifications] fetch keys: ${res.keys.toList()}');
      }
      return _pickNotifications(res).map(AppNotification.fromMap).toList();
    } on ApiException catch (e) {
      // Server bug (Knex): "Bind parameters must not contain undefined" — handler passes
      // undefined into SQL (e.g. wrong JWT claim mapping). Until the API is fixed, avoid
      // throwing so Riverpod does not spam retries and the UI stays usable.
      final code = e.statusCode ?? 0;
      if (code >= 500) {
        if (kDebugMode) {
          debugPrint(
            '[Notifications] GET failed ($code): ${e.message}. '
            'Returning empty list; fix backend SQL binds / req.user mapping.',
          );
        }
        return [];
      }
      rethrow;
    }
  }

  /// Counts unread items (paginates until no more or cap).
  Future<int> countUnread({required bool isProfessional, int pageSize = 100, int maxPages = 10}) async {
    var total = 0;
    String? beforeId;
    for (var p = 0; p < maxPages; p++) {
      final batch = await fetchNotifications(isProfessional: isProfessional, limit: pageSize, beforeId: beforeId);
      if (batch.isEmpty) break;
      total += batch.where((n) => !n.isRead).length;
      beforeId = batch.last.id;
      if (batch.length < pageSize) break;
    }
    return total;
  }

  Future<void> markRead({required bool isProfessional, required String id}) async {
    final token = await _requireToken();
    if (id.isEmpty) throw ApiException('Invalid notification id.');
    await _api.patch(
      '${_base(isProfessional)}/notifications/$id/read',
      body: const {},
      token: token,
    );
  }

  Future<void> markAllRead({required bool isProfessional}) async {
    final token = await _requireToken();
    await _api.patch(
      '${_base(isProfessional)}/notifications/read-all',
      body: const {},
      token: token,
    );
  }
}
