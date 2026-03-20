import '../../domain/models/content_page.dart';
import '../../domain/models/faq_item.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/content_remote_datasource.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({ContentRemoteDatasource? datasource})
      : _ds = datasource ?? ContentRemoteDatasource();

  final ContentRemoteDatasource _ds;

  @override
  Future<List<FaqItem>> getFaqs() => _ds.getFaqs();

  @override
  Future<ContentPage> getPrivacy() => _ds.getPrivacy();

  @override
  Future<ContentPage> getTerms() => _ds.getTerms();
}
