import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_remote_datasource.dart';
import '../../domain/favorite_collection.dart';
import '../../domain/favorite_item.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class FavoritesState {
  const FavoritesState({
    this.items = const [],
    this.collections = const [],
    this.loading = false,
    this.collectionsLoading = false,
    this.error,
    this.togglingIds = const {},
  });

  final List<FavoriteItem> items;
  final List<FavoriteCollection> collections;
  final bool loading;
  final bool collectionsLoading;
  final String? error;
  final Set<String> togglingIds;

  bool isFavorited(String itemId) => items.any((f) => f.itemId == itemId);

  /// Items not yet assigned to any collection (itemId == 0 on their list ref).
  List<FavoriteItem> get uncategorised => items;

  FavoritesState copyWith({
    List<FavoriteItem>? items,
    List<FavoriteCollection>? collections,
    bool? loading,
    bool? collectionsLoading,
    String? error,
    Set<String>? togglingIds,
  }) =>
      FavoritesState(
        items: items ?? this.items,
        collections: collections ?? this.collections,
        loading: loading ?? this.loading,
        collectionsLoading: collectionsLoading ?? this.collectionsLoading,
        error: error,
        togglingIds: togglingIds ?? this.togglingIds,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class FavoritesNotifier extends Notifier<FavoritesState> {
  final _ds = FavoritesRemoteDatasource();
  String? _lastError;

  String? consumeError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  @override
  FavoritesState build() {
    Future.microtask(load);
    return const FavoritesState(loading: true, collectionsLoading: true);
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(loading: true, collectionsLoading: true, error: null);
    try {
      final results = await Future.wait([
        _ds.listFavorites(),
        _ds.listCollections(),
      ]);
      state = state.copyWith(
        items: results[0] as List<FavoriteItem>,
        collections: results[1] as List<FavoriteCollection>,
        loading: false,
        collectionsLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        collectionsLoading: false,
        error: 'Could not load favorites.',
        items: const [],
        collections: const [],
      );
    }
  }

  Future<void> loadCollections() async {
    state = state.copyWith(collectionsLoading: true);
    try {
      final cols = await _ds.listCollections();
      state = state.copyWith(collections: cols, collectionsLoading: false);
    } catch (_) {
      state = state.copyWith(collectionsLoading: false);
    }
  }

  // ── Toggle favorite ───────────────────────────────────────────────────────

  Future<bool> toggleProfessional(
    String professionalId, {
    String? displayName,
    String? subtitle,
    String? imageUrl,
  }) async {
    return _toggle(
      itemId: professionalId,
      type: FavoriteType.professional,
      addFn: () => _ds.addProfessional(professionalId),
      displayName: displayName,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  Future<bool> toggleProject(
    String projectId, {
    String? displayName,
    String? subtitle,
    String? imageUrl,
  }) async {
    return _toggle(
      itemId: projectId,
      type: FavoriteType.project,
      addFn: () => _ds.addProject(projectId),
      displayName: displayName,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  Future<bool> _toggle({
    required String itemId,
    required FavoriteType type,
    required Future<FavoriteItem?> Function() addFn,
    String? displayName,
    String? subtitle,
    String? imageUrl,
  }) async {
    final wasFavorited = state.isFavorited(itemId);
    state = state.copyWith(togglingIds: {...state.togglingIds, itemId});

    try {
      if (wasFavorited) {
        final updated = state.items.where((f) => f.itemId != itemId).toList();
        state = state.copyWith(items: updated);
        await _ds.removeFavoriteByItemId(itemId, type: type);
      } else {
        final placeholder = FavoriteItem(
          favoriteId: 0,
          type: type,
          itemId: itemId,
          title: displayName ?? '',
          subtitle: subtitle ?? '',
          imageUrl: imageUrl,
        );
        state = state.copyWith(items: [...state.items, placeholder]);
        final saved = await addFn();
        if (saved != null) {
          // Merge server favoriteId with placeholder display data
          final merged = FavoriteItem(
            favoriteId: saved.favoriteId != 0 ? saved.favoriteId : 0,
            type: saved.type != FavoriteType.unknown ? saved.type : type,
            itemId: saved.itemId.isNotEmpty ? saved.itemId : itemId,
            title: saved.title.isNotEmpty ? saved.title : (displayName ?? ''),
            subtitle: saved.subtitle.isNotEmpty ? saved.subtitle : (subtitle ?? ''),
            imageUrl: saved.imageUrl ?? imageUrl,
            createdAt: saved.createdAt,
          );
          final updated = state.items
              .map((f) => f.itemId == itemId && f.favoriteId == 0 ? merged : f)
              .toList();
          state = state.copyWith(items: updated);
        }
      }
      return !wasFavorited;
    } on Exception catch (e) {
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('ApiException: ', '');
      _lastError = msg.isNotEmpty ? msg : 'Could not update favorites.';
      await load();
      return wasFavorited;
    } finally {
      final cleared = {...state.togglingIds}..remove(itemId);
      state = state.copyWith(togglingIds: cleared);
    }
  }

  // ── Collections ───────────────────────────────────────────────────────────

  /// Create a new collection. Returns the created collection.
  Future<FavoriteCollection?> createCollection(String name) async {
    try {
      final col = await _ds.createCollection(name);
      state = state.copyWith(collections: [...state.collections, col]);
      return col;
    } on Exception catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  /// Move a favorited item into a collection.
  Future<bool> moveToCollection(FavoriteItem item, int collectionId) async {
    if (item.favoriteId == 0) return false;
    try {
      await _ds.moveItemToCollection(item.favoriteId, collectionId);
      // Update the collection's item count locally
      final updatedCols = state.collections.map((c) {
        if (c.id == collectionId) {
          return c.copyWith(
            itemCount: c.itemCount + 1,
            items: [...c.items, item],
          );
        }
        return c;
      }).toList();
      state = state.copyWith(collections: updatedCols);
      return true;
    } on Exception catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  Future<void> removeFavorite(FavoriteItem item) async {
    final updated = state.items.where((f) => f.favoriteId != item.favoriteId).toList();
    state = state.copyWith(items: updated);
    try {
      if (item.favoriteId != 0) {
        await _ds.removeFavorite(item.favoriteId);
      } else {
        await _ds.removeFavoriteByItemId(item.itemId, type: item.type);
      }
    } catch (_) {
      await load();
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);
