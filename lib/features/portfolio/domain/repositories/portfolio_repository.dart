import '../models/portfolio_item.dart';

typedef PortfolioActionResult = ({String? errorMessage});

class CreatePortfolioInput {
  const CreatePortfolioInput({
    required this.title,
    required this.description,
    required this.photoPaths,
    this.completedPlace,
    this.amount,
  });

  final String title;
  final String description;
  final String? completedPlace;
  final String? amount;
  final List<String> photoPaths;
}

class UpdatePortfolioInput {
  const UpdatePortfolioInput({
    this.title,
    this.description,
    this.completedPlace,
    this.amount,
  });

  final String? title;
  final String? description;
  final String? completedPlace;
  final String? amount;

  bool get hasAnyField => title != null || description != null || completedPlace != null || amount != null;
}

abstract class PortfolioRepository {
  Future<List<PortfolioItem>> getMyPortfolio();
  Future<PortfolioActionResult> createItem(CreatePortfolioInput input);
  Future<PortfolioActionResult> updateItem(int portfolioId, UpdatePortfolioInput input);
  Future<PortfolioActionResult> deleteItem(int portfolioId);
  Future<PortfolioActionResult> addPhotos(int portfolioId, List<String> photoPaths);
  Future<PortfolioActionResult> deletePhoto(int portfolioId, int photoId);
}
