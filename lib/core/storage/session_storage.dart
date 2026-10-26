import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/models/app_user.dart';

class SessionStorage {
  static const _tokenKey = 'session_token';
  static const _userKey = 'session_user';
  static const _localProfilePhotoPathKey = 'local_profile_photo_path';

  static const _deletedConvTimestampsKey = 'deleted_conversations_timestamps';
  static const _preferredHomeCategoryKey = 'preferred_home_category_id';

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toMap()));
  }

  Future<AppUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_userKey);
    if (value == null) return null;
    return AppUser.fromMap(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> setLocalProfilePhotoPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localProfilePhotoPathKey, path);
  }

  Future<String?> getLocalProfilePhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localProfilePhotoPathKey);
  }

  Future<void> clearLocalProfilePhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localProfilePhotoPathKey);
  }

  // ── Conversation Deletion Timestamps ──────────────────────────────────────
  Future<DateTime?> getConversationDeleteTime(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_deletedConvTimestampsKey);
    if (jsonStr == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
      final val = map[conversationId.toString()];
      if (val is String) {
        return DateTime.tryParse(val);
      }
    } catch (_) {}
    return null;
  }

  Future<void> setConversationDeleteTime(int conversationId, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_deletedConvTimestampsKey);
    final map = <String, dynamic>{};
    if (jsonStr != null) {
      try {
        map.addAll(Map<String, dynamic>.from(jsonDecode(jsonStr)));
      } catch (_) {}
    }
    map[conversationId.toString()] = time.toUtc().toIso8601String();
    await prefs.setString(_deletedConvTimestampsKey, jsonEncode(map));
  }

  Future<DateTime?> getConversationDeleteTimeByUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_deletedConvTimestampsKey);
    if (jsonStr == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
      final val = map[userId];
      if (val is String) {
        return DateTime.tryParse(val);
      }
    } catch (_) {}
    return null;
  }

  Future<void> setConversationDeleteTimeByUserId(String userId, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_deletedConvTimestampsKey);
    final map = <String, dynamic>{};
    if (jsonStr != null) {
      try {
        map.addAll(Map<String, dynamic>.from(jsonDecode(jsonStr)));
      } catch (_) {}
    }
    map[userId] = time.toUtc().toIso8601String();
    await prefs.setString(_deletedConvTimestampsKey, jsonEncode(map));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_localProfilePhotoPathKey);
    await prefs.remove(_deletedConvTimestampsKey);
  }

  Future<void> setPreferredHomeCategoryId(int? categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    if (categoryId == null) {
      await prefs.remove(_preferredHomeCategoryKey);
    } else {
      await prefs.setInt(_preferredHomeCategoryKey, categoryId);
    }
  }

  Future<int?> getPreferredHomeCategoryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_preferredHomeCategoryKey);
  }
}
