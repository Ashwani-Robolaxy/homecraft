import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_utils.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/provider_profile.dart';

class AuthRemoteDatasource {
  AuthRemoteDatasource({
    ApiClient? apiClient,
    SessionStorage? sessionStorage,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionStorage ?? SessionStorage() {
    _bootstrapSession();
  }

  final ApiClient _api;
  final SessionStorage _session;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  Stream<AppUser?> get authStateChanges => _controller.stream;
  AppUser? get currentUser => _currentUser;

  Future<void> _bootstrapSession() async {
    final token = await _session.getToken();
    final user = await _session.getUser();

    // No stored session — not logged in.
    if (token == null || token.isEmpty || user == null) {
      _currentUser = null;
      _controller.add(null);
      return;
    }

    // Token is expired — wipe session so GoRouter redirects to /login.
    if (TokenUtils.isExpired(token)) {
      await _session.clear();
      _currentUser = null;
      _controller.add(null);
      return;
    }

    _currentUser = user;
    _controller.add(user);
  }

  Future<void> _persistSession({
    required String token,
    required AppUser user,
  }) async {
    await _session.setToken(token);
    await _session.setUser(user);
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> signOut() async {
    await _session.clear();
    _currentUser = null;
    _controller.add(null);
  }

  Future<AppUser?> getCurrentUser() async {
    final token = await _session.getToken();
    if (token == null) return null;
    final cached = await _session.getUser();
    if (cached == null) return null;
    if (!cached.isProvider) return cached;
    final map = await _api.get('/professionals/me', token: token);
    final me = _extractPayloadMap(map);
    final user = _mapProfessionalToAppUser(me, fallback: cached);
    await _session.setUser(user);
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final endpoint = role == UserRole.provider ? '/professionals/login' : '/users/login';
    final response = await _api.post(endpoint, body: {'email': email.trim(), 'password': password});
    final token = _extractToken(response);
    if (token == null) throw Exception('Missing access token');
    final payload = _extractPayloadMap(response);
    final user = _mapApiUser(payload, roleHint: role, emailFallback: email.trim());
    await _persistSession(token: token, user: user);
    return user;
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    if (role == UserRole.provider) {
      final names = displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final firstName = names.isNotEmpty ? names.first : displayName.trim();
      // API requires non-empty lastName; duplicate first name if user entered only one word.
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : firstName;
      final response = await _api.post('/professionals/signup', body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email.trim(),
        'password': password,
      });
      final token = _extractToken(response, fallback: await _session.getToken());
      final payload = _extractPayloadMap(response);
      final user = _mapApiUser(payload, roleHint: UserRole.provider, emailFallback: email.trim(), displayNameFallback: displayName.trim());
      if (token != null) {
        await _persistSession(token: token, user: user);
      }
      return user;
    }
    final response = await _api.post('/users/signup', body: {
      'username': displayName.trim(),
      'email': email.trim(),
      'password': password,
    });
    final token = _extractToken(response, fallback: await _session.getToken());
    final payload = _extractPayloadMap(response);
    final user = _mapApiUser(payload, roleHint: UserRole.client, emailFallback: email.trim(), displayNameFallback: displayName.trim());
    if (token != null) {
      await _persistSession(token: token, user: user);
    }
    return user;
  }

  Future<void> sendForgotPassword({
    required String email,
    required UserRole role,
  }) {
    final endpoint = role == UserRole.provider ? '/professionals/forgot-password' : '/users/forgot-password';
    return _api.post(endpoint, body: {'email': email.trim()});
  }

  Future<AppUser> socialLogin({
    required String provider,
    required String idToken,
    required UserRole role,
  }) async {
    final endpoint = role == UserRole.provider ? '/professionals/social-login' : '/users/social-login';
    final response = await _api.post(endpoint, body: {'provider': provider, 'idToken': idToken});
    final token = _extractToken(response);
    if (token == null) throw Exception('Missing access token');
    final payload = _extractPayloadMap(response);
    final user = _mapApiUser(payload, roleHint: role);
    await _persistSession(token: token, user: user);
    return user;
  }

  Future<void> verifyResetOtp({
    required String email,
    required String otp,
    required UserRole role,
  }) {
    final endpoint = role == UserRole.provider ? '/professionals/verify-reset-otp' : '/users/verify-reset-otp';
    return _api.post(endpoint, body: {'email': email.trim(), 'otp': otp.trim()});
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required UserRole role,
  }) {
    final endpoint = role == UserRole.provider ? '/professionals/reset-password' : '/users/reset-password';
    return _api.post(
      endpoint,
      body: {'email': email.trim(), 'otp': otp.trim(), 'password': password},
    );
  }

  Future<void> completeProviderProfile(ProviderProfile profile) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('Unauthorized');
    await _api.put(
      '/professionals/complete-profile',
      token: token,
      body: profile.toCompleteProfileApiMap(),
    );
    final refreshed = await getCurrentUser();
    if (refreshed != null) {
      _currentUser = refreshed;
      _controller.add(refreshed);
    }
  }

  Future<void> updateBasicProfile({
    required String displayName,
    String? phone,
    String? city,
  }) async {
    final current = await _session.getUser();
    if (current == null) return;
    final updated = AppUser(
      uid: current.uid,
      email: current.email,
      displayName: displayName,
      role: current.role,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      phone: phone,
      city: city,
      providerProfile: current.providerProfile,
    );
    await _session.setUser(updated);
    _currentUser = updated;
    _controller.add(updated);
  }

  Map<String, dynamic> _extractPayloadMap(Map<String, dynamic> response) {
    for (final key in ['data', 'user', 'professional', 'result']) {
      final v = response[key];
      if (v is Map<String, dynamic>) return v;
    }
    return response;
  }

  String? _extractToken(Map<String, dynamic> response, {String? fallback}) {
    for (final key in ['token', 'accessToken', 'access_token', 'jwt']) {
      final v = response[key];
      if (v is String && v.isNotEmpty) return v;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final dv = data[key];
        if (dv is String && dv.isNotEmpty) return dv;
      }
    }
    return fallback;
  }

  AppUser _mapApiUser(
    Map<String, dynamic> payload, {
    required UserRole roleHint,
    String? emailFallback,
    String? displayNameFallback,
  }) {
    final role = UserRole.fromString((payload['role'] ?? roleHint.name).toString());
    final uid = (payload['id'] ?? payload['_id'] ?? payload['uid'] ?? payload['userId'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();
    final email = (payload['email'] ?? emailFallback ?? '').toString();
    final displayName = (payload['displayName'] ?? payload['username'] ?? payload['name'] ?? payload['fullName'] ?? displayNameFallback ?? '').toString();
    final phone = payload['phone']?.toString();
    final city = (payload['city'] ?? payload['address'])?.toString();
    final providerProfile = payload['providerProfile'] is Map<String, dynamic>
        ? ProviderProfile.fromMap(payload['providerProfile'] as Map<String, dynamic>)
        : null;
    final createdMs = payload['createdAt'];
    final updatedMs = payload['updatedAt'];
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      role: role,
      createdAt: createdMs is int ? DateTime.fromMillisecondsSinceEpoch(createdMs) : DateTime.now(),
      updatedAt: updatedMs is int ? DateTime.fromMillisecondsSinceEpoch(updatedMs) : null,
      phone: phone,
      city: city,
      providerProfile: providerProfile,
    );
  }

  AppUser _mapProfessionalToAppUser(Map<String, dynamic> payload, {required AppUser fallback}) {
    final profile = ProviderProfile.fromMap(payload);
    return AppUser(
      uid: fallback.uid,
      email: (payload['email'] ?? fallback.email).toString(),
      displayName: profile.displayName.isNotEmpty ? profile.displayName : fallback.displayName,
      role: UserRole.provider,
      createdAt: fallback.createdAt,
      updatedAt: DateTime.now(),
      phone: profile.phone.isEmpty ? fallback.phone : profile.phone,
      city: profile.address.isEmpty ? fallback.city : profile.address,
      providerProfile: profile,
    );
  }
}
