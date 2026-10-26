import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/portfolio_repository_impl.dart';
import '../../domain/models/portfolio_item.dart';
import '../../domain/repositories/portfolio_repository.dart';

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepositoryImpl();
});

final professionalPortfolioProvider = FutureProvider<List<PortfolioItem>>((ref) async {
  final repo = ref.watch(portfolioRepositoryProvider);
  return repo.getMyPortfolio();
});
