import '../../../../core/network/api_exception.dart';
import '../../domain/models/portfolio_item.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../datasources/portfolio_remote_datasource.dart';

class PortfolioRepositoryImpl implements PortfolioRepository {
  PortfolioRepositoryImpl({PortfolioRemoteDatasource? datasource})
      : _ds = datasource ?? PortfolioRemoteDatasource();

  final PortfolioRemoteDatasource _ds;

  @override
  Future<List<PortfolioItem>> getMyPortfolio() => _ds.getMyPortfolio();

  @override
  Future<PortfolioActionResult> createItem(CreatePortfolioInput input) async {
    try {
      await _ds.createItem(input);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<PortfolioActionResult> updateItem(int portfolioId, UpdatePortfolioInput input) async {
    try {
      await _ds.updateItem(portfolioId, input);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<PortfolioActionResult> deleteItem(int portfolioId) async {
    try {
      await _ds.deleteItem(portfolioId);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<PortfolioActionResult> addPhotos(int portfolioId, List<String> photoPaths) async {
    try {
      await _ds.addPhotos(portfolioId, photoPaths);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<PortfolioActionResult> deletePhoto(int portfolioId, int photoId) async {
    try {
      await _ds.deletePhoto(portfolioId, photoId);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }
}
