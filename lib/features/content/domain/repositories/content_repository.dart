import '../models/content_page.dart';
import '../models/faq_item.dart';

abstract class ContentRepository {
  Future<ContentPage> getTerms();
  Future<ContentPage> getPrivacy();
  Future<List<FaqItem>> getFaqs();
}
