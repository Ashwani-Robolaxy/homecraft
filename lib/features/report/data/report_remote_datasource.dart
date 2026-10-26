import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';

/// Reason options and their API-expected values.
enum ReportReason {
  hateSpeech('Hate Speech', 'hate_speech', 'take_action.reason_hate_speech'),
  nudityOrSexual('Nudity or Sexual Content', 'nudity_or_sexual_content', 'take_action.reason_nudity'),
  threat('Threat', 'threat', 'take_action.reason_threat'),
  harassment('Harassment', 'harassment', 'take_action.reason_harassment'),
  diffamation('Diffamation', 'something_else', 'take_action.reason_diffamation'),
  fraudOrScam('Fraud Or Scam', 'fraud_or_scam', 'take_action.reason_fraud'),
  somethingElse('Something Else', 'other', 'take_action.reason_something_else');

  const ReportReason(this.label, this.apiValue, this.translationKey);
  final String label;
  final String apiValue;
  /// Key used with easy_localization tr() for localised display label.
  final String translationKey;

  static ReportReason fromLabel(String label) =>
      ReportReason.values.firstWhere(
        (r) => r.label == label,
        orElse: () => ReportReason.somethingElse,
      );
}

class ReportRemoteDatasource {
  final ApiClient _api = ApiClient();
  final SessionStorage _session = SessionStorage();

  Future<String> _requireToken() async {
    final t = await _session.getToken();
    if (t == null || t.isEmpty) throw ApiException('Please login again.');
    return t;
  }

  /// POST /users/reports/professionals
  /// Reports a professional with a reason and optional description.
  Future<void> reportProfessional({
    required String professionalId,
    required ReportReason reason,
    String? description,
  }) async {
    final token = await _requireToken();

    final body = <String, dynamic>{
      'professionalId': int.tryParse(professionalId) ?? professionalId,
      'reason': reason.apiValue,
    };
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }

    debugPrint('[Report] POST /users/reports/professionals body=$body');

    final res = await _api.post(
      '/users/reports/professionals',
      body: body,
      token: token,
    );
    debugPrint('[Report] response keys: ${res.keys.toList()}');
  }

  /// POST /professionals/reports/users
  /// Reports a user (customer) with a reason and optional details.
  Future<void> reportUser({
    required String userId,
    required ReportReason reason,
    String? details,
  }) async {
    final token = await _requireToken();

    final body = <String, dynamic>{
      'userId': int.tryParse(userId) ?? userId,
      'reason': reason.apiValue,
    };
    if (details != null && details.trim().isNotEmpty) {
      body['details'] = details.trim();
    }

    debugPrint('[Report] POST /professionals/reports/users body=$body');

    final res = await _api.post(
      '/professionals/reports/users',
      body: body,
      token: token,
    );
    debugPrint('[Report] response keys: ${res.keys.toList()}');
  }

  /// GET /users/reports  — list all reports submitted by this user.
  Future<List<Map<String, dynamic>>> listMyReports() async {
    final token = await _requireToken();
    final res = await _api.get('/users/reports', token: token);
    debugPrint('[Report] listMyReports keys: ${res.keys.toList()}');
    final raw = _pickList(res, ['reports', 'data', 'items']);
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<dynamic> _pickList(
      Map<String, dynamic> res, List<String> keys) {
    for (final k in keys) {
      final v = res[k];
      if (v is List) return v;
    }
    if (res['data'] is Map) {
      for (final k in keys) {
        final v = (res['data'] as Map)[k];
        if (v is List) return v;
      }
    }
    return [];
  }
}
