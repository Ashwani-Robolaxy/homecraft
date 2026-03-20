import '../../../../core/network/api_client.dart';
import '../../domain/models/content_page.dart';
import '../../domain/models/faq_item.dart';

class ContentRemoteDatasource {
  ContentRemoteDatasource({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<ContentPage> getTerms() async {
    final map = await _api.get('/content/terms');
    final payload = _extractPagePayload(map);
    return ContentPage.fromMap(payload);
  }

  Future<ContentPage> getPrivacy() async {
    final map = await _api.get('/content/privacy');
    final payload = _extractPagePayload(map);
    return ContentPage.fromMap(payload);
  }

  Future<List<FaqItem>> getFaqs() async {
    final map = await _api.get('/content/faqs');
    final list = map['data'] is List
        ? map['data'] as List<dynamic>
        : (map['faqs'] is List ? map['faqs'] as List<dynamic> : const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(FaqItem.fromMap)
        .toList();
  }

  Map<String, dynamic> _extractPagePayload(Map<String, dynamic> map) {
    final page = map['page'];
    if (page is Map<String, dynamic>) return page;
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    return map;
  }
}
