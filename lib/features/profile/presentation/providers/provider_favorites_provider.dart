import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../favorites/data/favorites_remote_datasource.dart';
import '../../../favorites/domain/favorite_collection.dart';
import '../../../favorites/domain/favorite_item.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';

/// Active list filter for [GET /professionals/favorites/items?listId=] (`null` = all).
class ProviderFavoritesListFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? listId) {
    state = listId;
  }
}

final providerFavoritesListFilterProvider =
    NotifierProvider<ProviderFavoritesListFilterNotifier, int?>(
        ProviderFavoritesListFilterNotifier.new);

class ProviderFavoritesNotifier extends FavoritesNotifier {
  final _ds = FavoritesRemoteDatasource(apiPrefix: '/professionals');

  @override
  FavoritesRemoteDatasource get ds => _ds;

  @override
  Future<void> load() async {
    final listId = ref.read(providerFavoritesListFilterProvider);
    state = state.copyWith(loading: true, collectionsLoading: true, error: null);
    try {
      final results = await Future.wait([
        _ds.listFavorites(listId: listId, limit: 100),
        _ds.listCollections(),
      ]);
      state = state.copyWith(
        items: results[0] as List<FavoriteItem>,
        collections: results[1] as List<FavoriteCollection>,
        loading: false,
        collectionsLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        collectionsLoading: false,
        error: 'Could not load favorites.',
        items: const [],
        collections: const [],
      );
    }
  }

  void setListFilter(int? listId) {
    ref.read(providerFavoritesListFilterProvider.notifier).select(listId);
    load();
  }
}

final providerFavoritesProvider =
    NotifierProvider<ProviderFavoritesNotifier, FavoritesState>(
        ProviderFavoritesNotifier.new);
