import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/content_repository_impl.dart';
import '../../domain/models/content_page.dart';
import '../../domain/models/faq_item.dart';
import '../../domain/repositories/content_repository.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepositoryImpl();
});

final termsProvider = FutureProvider<ContentPage>((ref) {
  return ref.read(contentRepositoryProvider).getTerms();
});

final privacyProvider = FutureProvider<ContentPage>((ref) {
  return ref.read(contentRepositoryProvider).getPrivacy();
});

final faqProvider = FutureProvider<List<FaqItem>>((ref) {
  return ref.read(contentRepositoryProvider).getFaqs();
});
