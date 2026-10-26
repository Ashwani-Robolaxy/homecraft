import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/favorite_collection.dart';
import '../domain/favorite_item.dart';

class FavoritesRemoteDatasource {
  FavoritesRemoteDatasource({ApiClient? apiClient, SessionStorage? session, String apiPrefix = '/users'})
      : _api = apiClient ?? ApiClient(),
        _session = session ?? SessionStorage(),
        _apiPrefix = apiPrefix;

  final ApiClient _api;
  final SessionStorage _session;
  final String _apiPrefix;

  // ── List favorite items ──────────────────────────────────────────────────
  // GET /users/favorites/items

  /// GET …/favorites/items — optional [listId], [targetType], [limit] per Swagger.
  Future<List<FavoriteItem>> listFavorites({
    int? listId,
    String? targetType,
    int? limit,
  }) async {
    final token = await _requireToken();
    final query = <String, String>{
      if (listId != null) 'listId': '$listId',
      if (targetType != null && targetType.isNotEmpty) 'targetType': targetType,
      if (limit != null) 'limit': '$limit',
    };
    final qs = query.isEmpty
        ? ''
        : '?${query.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final res = await _api.get('$_apiPrefix/favorites/items$qs', token: token);
    debugPrint('[Favorites] listFavorites top-level keys: ${res.keys.toList()}');
    final raw = _pickList(res, ['items', 'favorites', 'data', 'favoriteItems']);
    debugPrint('[Favorites] listFavorites count: ${raw.length}');
    if (raw.isNotEmpty) {
      debugPrint('[Favorites] first item keys: ${raw.first.keys.toList()}');
      debugPrint('[Favorites] first item: ${raw.first}');
    }
    final mapped = raw
        .map((e) => FavoriteItem.fromMap(Map<String, dynamic>.from(e)))
        .where((f) => f.itemId.isNotEmpty)
        .toList();
    if (mapped.isNotEmpty) {
      debugPrint('[Favorites] first resolved imageUrl: ${mapped.first.imageUrl}');
    }
    return mapped;
  }

  // ── Add professional to favorites ────────────────────────────────────────
  // POST /users/favorites/items  { professionalId }

  Future<FavoriteItem?> addProfessional(String professionalId) async {
    final token = await _requireToken();
    final id = int.tryParse(professionalId);
    if (id == null) throw ApiException('Invalid professional ID.');
    final res = await _api.post(
      '$_apiPrefix/favorites/items',
      body: {'targetType': 'professional', 'targetId': id},
      token: token,
    );
    debugPrint('[Favorites] addProfessional response keys: ${res.keys.toList()}');
    return _parseSingle(res, FavoriteType.professional, professionalId);
  }

  // ── Add project to favorites ─────────────────────────────────────────────
  // POST /users/favorites/items  { targetType: 'project', targetId }

  Future<FavoriteItem?> addProject(String projectId) async {
    final token = await _requireToken();
    final id = int.tryParse(projectId);
    if (id == null) throw ApiException('Invalid project ID.');
    final res = await _api.post(
      '$_apiPrefix/favorites/items',
      body: {'targetType': 'project', 'targetId': id},
      token: token,
    );
    debugPrint('[Favorites] addProject response keys: ${res.keys.toList()}');
    return _parseSingle(res, FavoriteType.project, projectId);
  }

  // ── Collections ──────────────────────────────────────────────────────────
  // GET /users/favorites/lists

  Future<List<FavoriteCollection>> listCollections() async {
    final token = await _requireToken();
    final res = await _api.get('$_apiPrefix/favorites/lists', token: token);
    debugPrint('[Favorites] listCollections keys: ${res.keys.toList()}');
    final raw = _pickList(res, ['lists', 'data', 'items', 'collections']);
    return raw
        .map((e) => FavoriteCollection.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // POST /users/favorites/lists  { name }

  Future<FavoriteCollection> createCollection(String name) async {
    final token = await _requireToken();
    final res = await _api.post(
      '$_apiPrefix/favorites/lists',
      body: {'name': name.trim()},
      token: token,
    );
    debugPrint('[Favorites] createCollection response: ${res.keys.toList()}');
    final raw = res['list'] ?? res['data'] ?? res['collection'] ?? res;
    return FavoriteCollection.fromMap(
      raw is Map ? Map<String, dynamic>.from(raw) : {'name': name},
    );
  }

  // PUT or PATCH …/favorites/lists/{listId} { name } — some backends only register PATCH.
  Future<FavoriteCollection> renameCollection(int listId, String name) async {
    final token = await _requireToken();
    final body = <String, dynamic>{'name': name.trim()};
    final path = '$_apiPrefix/favorites/lists/$listId';

    Map<String, dynamic> res;
    try {
      res = await _api.put(path, body: body, token: token);
    } on ApiException catch (e) {
      if (!_isMissingRoute(e)) rethrow;
      try {
        res = await _api.patch(path, body: body, token: token);
      } on ApiException catch (e2) {
        if (!_isMissingRoute(e2)) rethrow;
        throw ApiException(
          'Cannot rename collection: the API has no PUT/PATCH route for $path. Implement rename on the server (see Swagger).',
          statusCode: e2.statusCode ?? e.statusCode,
        );
      }
    }

    final raw = res['list'] ?? res['data'] ?? res['collection'] ?? res;
    return FavoriteCollection.fromMap(
      raw is Map ? Map<String, dynamic>.from(raw) : {'id': listId, 'name': name},
    );
  }

  bool _isMissingRoute(ApiException e) {
    final msg = e.message.toLowerCase();
    return e.statusCode == 404 ||
        (msg.contains('route not found') && msg.contains('/favorites/lists'));
  }

  // DELETE …/favorites/lists/{listId}
  Future<void> deleteCollection(int listId) async {
    final token = await _requireToken();
    final path = '$_apiPrefix/favorites/lists/$listId';
    try {
      await _api.delete(path, token: token);
    } on ApiException catch (e) {
      if (!_isMissingRoute(e)) rethrow;
      throw ApiException(
        'Cannot delete collection: the API has no DELETE route for $path. Implement delete on the server (see Swagger).',
        statusCode: e.statusCode,
      );
    }
  }

  // PUT /users/favorites/items/{favoriteItemId}/list  { listId }

  Future<void> moveItemToCollection(int favoriteItemId, int listId) async {
    final token = await _requireToken();
    await _api.put(
      '$_apiPrefix/favorites/items/$favoriteItemId/list',
      body: {'listId': listId},
      token: token,
    );
    debugPrint('[Favorites] moveItemToCollection $favoriteItemId → list $listId done');
  }

  // ── Remove favorite item ─────────────────────────────────────────────────
  // DELETE /users/favorites/items/{itemId}

  Future<void> removeFavorite(int favoriteId) async {
    final token = await _requireToken();
    await _api.delete('$_apiPrefix/favorites/items/$favoriteId', token: token);
    debugPrint('[Favorites] removeFavorite $favoriteId done');
  }

  /// Remove by the professional/project itemId when the favoriteId record is unknown.
  Future<void> removeFavoriteByItemId(
    String itemId, {
    required FavoriteType type,
  }) async {
    // Fetch list to find the favoriteId record
    try {
      final all = await listFavorites();
      final match = all.where((f) => f.itemId == itemId && f.type == type);
      for (final fav in match) {
        if (fav.favoriteId != 0) {
          await removeFavorite(fav.favoriteId);
          return;
        }
      }
    } catch (e) {
      debugPrint('[Favorites] removeFavoriteByItemId list failed: $e');
    }
    // Fallback: try deleting by the item id directly
    try {
      final token = await _requireToken();
      await _api.delete('$_apiPrefix/favorites/items/$itemId', token: token);
    } catch (e) {
      debugPrint('[Favorites] removeFavoriteByItemId fallback failed: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<String> _requireToken() async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) throw ApiException('Please login again.');
    return token;
  }

  FavoriteItem? _parseSingle(
    Map<String, dynamic> res,
    FavoriteType type,
    String fallbackItemId,
  ) {
    final raw = res['item'] ?? res['favoriteItem'] ?? res['favorite'] ??
        res['data'] ?? res['result'];
    if (raw is Map) {
      final item = FavoriteItem.fromMap(Map<String, dynamic>.from(raw));
      if (item.itemId.isNotEmpty) return item;
    }
    final id = _parseInt(res['id'] ?? res['favoriteId'] ??
        (raw is Map ? raw['id'] : null));
    return FavoriteItem(
      favoriteId: id ?? 0,
      type: type,
      itemId: fallbackItemId,
      title: '',
      subtitle: '',
    );
  }

  List<Map<String, dynamic>> _pickList(
    Map<String, dynamic> res,
    List<String> keys,
  ) {
    for (final key in keys) {
      final v = res[key];
      if (v is List) {
        return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
