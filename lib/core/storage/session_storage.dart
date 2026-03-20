import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/models/app_user.dart';

class SessionStorage {
  static const _tokenKey = 'session_token';
  static const _userKey = 'session_user';

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

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
