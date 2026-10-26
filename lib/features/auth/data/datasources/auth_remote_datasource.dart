import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/token_utils.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/provider_profile.dart';

class AuthRemoteDatasource {
  AuthRemoteDatasource({ApiClient? apiClient, SessionStorage? sessionStorage}) : _api = apiClient ?? ApiClient(), _session = sessionStorage ?? SessionStorage() {
    _bootstrapSession();
  }

  final ApiClient _api;
  final SessionStorage _session;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  Stream<AppUser?> get authStateChanges => _controller.stream;
  AppUser? get currentUser => _currentUser;

  Future<String?> _getFcmToken() async {
    try {
      if (kIsWeb) return null;

      // NOTE: Do NOT call deleteToken() here. Token deletion must only happen
      // at sign-out (see signOut()) to prevent leakage between users.
      // Deleting during login tears down the active FCM connection and breaks
      // push delivery for the entire session.

      if (Platform.isIOS) {
        // iOS requires APNs token before FCM token can be reliably generated.
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          for (int i = 0; i < 6; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
      }

      final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 10));
      if (token == null) return null;
      final trimmed = token.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      // FCM token is optional for auth request resilience.
      return null;
    }
  }

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

  Future<void> _persistSession({required String token, required AppUser user}) async {
    await _session.setToken(token);
    await _session.setUser(user);
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> signOut() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await _session.clear();
    _currentUser = null;
    _controller.add(null);
  }

  /// **PUT** `/users/change-password` — changes the password for local accounts.
  /// Requires `currentPassword` and `newPassword` (8–64 chars).
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again.', statusCode: 401);
    }
    final res = await _api.put('/users/change-password', token: token, body: {'currentPassword': currentPassword, 'newPassword': newPassword}, skipUnauthorized: true);
    debugPrint('[Auth] change-password response: $res');
  }

  /// **DELETE** `/users/me/profile` — permanently deletes the account then
  /// clears the local session (same as sign-out).
  Future<void> deleteAccount() async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again.', statusCode: 401);
    }
    final current = await _session.getUser();
    final isProvider = current?.isProvider == true;
    final endpoint = isProvider ? '/professionals/me' : '/users/me/profile';
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.Request('DELETE', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await signOut();
      return;
    }

    Map<String, dynamic> map = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) map = decoded;
      } catch (_) {}
    }
    final msg = (map['message'] ?? map['error'] ?? 'Could not delete account.').toString();
    throw ApiException(msg, statusCode: response.statusCode);
  }

  Future<AppUser?> getCurrentUser() async {
    final token = await _session.getToken();
    if (token == null) return null;
    final cached = await _session.getUser();
    if (cached == null) return null;
    if (cached.isProvider) {
      final map = await _api.get('/professionals/me', token: token);
      _logFullProfessionalPayload(map);
      final me = _extractPayloadMap(map);
      final user = _mapProfessionalToAppUser(me, fallback: cached);
      await _session.setUser(user);
      _currentUser = user;
      _controller.add(user);
      return user;
    }
    if (token.isEmpty) return cached;
    try {
      final map = await _api.get('/users/me/profile', token: token);
      final payload = _extractClientProfilePayload(map);
      final merged = _mergeClientProfileFromPayload(cached, payload);
      await _session.setUser(merged);
      _currentUser = merged;
      _controller.add(merged);
      return merged;
    } on ApiException catch (e) {
      debugPrint('[Auth] GET /users/me/profile: $e');
      return cached;
    } catch (e) {
      debugPrint('[Auth] GET /users/me/profile: $e');
      return cached;
    }
  }

  void _logFullProfessionalPayload(Map<String, dynamic> payload) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(payload);
      debugPrint('[Auth] /professionals/me payload start');
      for (final line in pretty.split('\n')) {
        debugPrint(line);
      }
      debugPrint('[Auth] /professionals/me payload end');
    } catch (_) {
      debugPrint('[Auth] /professionals/me payload: $payload');
    }
  }

  Future<AppUser> login({required String email, required String password, required UserRole role}) async {
    final endpoint = role == UserRole.provider ? '/professionals/login' : '/users/login';
    final fcmToken = await _getFcmToken();
    final response = await _api.post(endpoint, body: {'email': email.trim(), 'password': password, if (fcmToken != null) 'fcmToken': fcmToken});
    final token = _extractToken(response);
    if (token == null) throw Exception('Missing access token');
    final payload = _extractPayloadMap(response);
    final user = _mapApiUser(payload, roleHint: role, emailFallback: email.trim());
    await _persistSession(token: token, user: user);
    return user;
  }

  Future<AppUser> register({required String email, required String password, required String displayName, required UserRole role}) async {
    final fcmToken = await _getFcmToken();
    if (role == UserRole.provider) {
      final names = displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final firstName = names.isNotEmpty ? names.first : displayName.trim();
      // API requires non-empty lastName; duplicate first name if user entered only one word.
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : firstName;
      final response = await _api.post(
        '/professionals/signup',
        body: {'firstName': firstName, 'lastName': lastName, 'email': email.trim(), 'password': password, if (fcmToken != null) 'fcmToken': fcmToken},
      );
      final token = _extractToken(response, fallback: await _session.getToken());
      final payload = _extractPayloadMap(response);
      final user = _mapApiUser(payload, roleHint: UserRole.provider, emailFallback: email.trim(), displayNameFallback: displayName.trim());
      if (token != null) {
        await _persistSession(token: token, user: user);
      }
      return user;
    }
    final response = await _api.post('/users/signup', body: {'username': displayName.trim(), 'email': email.trim(), 'password': password, if (fcmToken != null) 'fcmToken': fcmToken});
    final token = _extractToken(response, fallback: await _session.getToken());
    final payload = _extractPayloadMap(response);
    final user = _mapApiUser(payload, roleHint: UserRole.client, emailFallback: email.trim(), displayNameFallback: displayName.trim());
    if (token != null) {
      await _persistSession(token: token, user: user);
    }
    return user;
  }

  Future<void> sendForgotPassword({required String email, required UserRole role}) {
    final endpoint = role == UserRole.provider ? '/professionals/forgot-password' : '/users/forgot-password';
    return _api.post(endpoint, body: {'email': email.trim()});
  }

  Future<AppUser> socialLogin({required String provider, required String idToken, required UserRole role}) async {
    final endpoint = role == UserRole.provider ? '/professionals/social-login' : '/users/social-login';
    final fcmToken = await _getFcmToken();
    final response = await _api.post(endpoint, body: {'provider': provider, 'idToken': idToken, if (fcmToken != null) 'fcmToken': fcmToken});
    final token = _extractToken(response);
    if (token == null) throw Exception('Missing access token');
    final payload = _extractPayloadMap(response);
    final user = _mapApiUser(payload, roleHint: role);
    await _persistSession(token: token, user: user);
    return user;
  }

  Future<void> verifyResetOtp({required String email, required String otp, required UserRole role}) {
    final endpoint = role == UserRole.provider ? '/professionals/verify-reset-otp' : '/users/verify-reset-otp';
    return _api.post(endpoint, body: {'email': email.trim(), 'otp': otp.trim()});
  }

  Future<void> resetPassword({required String email, required String otp, required String password, required UserRole role}) {
    final endpoint = role == UserRole.provider ? '/professionals/reset-password' : '/users/reset-password';
    return _api.post(endpoint, body: {'email': email.trim(), 'otp': otp.trim(), 'password': password});
  }

  Future<void> completeProviderProfile(ProviderProfile profile) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) throw ApiException('Unauthorized', statusCode: 401);

    final current = await _session.getUser();
    final uri = Uri.parse('${ApiConfig.baseUrl}/professionals/complete-profile');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final payload = profile.toCompleteProfileApiMap();

    // Fetch and re-upload the existing profile photo if one exists to prevent the backend from deleting it.
    if (current?.profilePhotoUrl != null && _looksLikeHttpUrl(current!.profilePhotoUrl!)) {
      try {
        final existingBytes = await _api.getBytes(current.profilePhotoUrl!);
        request.files.add(http.MultipartFile.fromBytes('profileImage', existingBytes, filename: 'profile.jpg', contentType: MediaType('image', 'jpeg')));
      } catch (e) {
        debugPrint('[Auth] Failed to fetch existing profile image for preservation: $e');
      }
    }

    final rawKbisFromProfile = (profile.kbisExtractUrl ?? '').trim();
    final rawKbisFromPayload = (payload.remove('kbisExtractUrl') ?? '').toString().trim();
    final rawKbis = rawKbisFromProfile.isNotEmpty ? rawKbisFromProfile : rawKbisFromPayload;
    final certificateValues = (payload.remove('certificateUploads') as List<dynamic>? ?? const []).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();

    for (final entry in payload.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;
      if (value is List || value is Map<String, dynamic>) {
        request.fields[key] = jsonEncode(value);
      } else {
        request.fields[key] = value.toString();
      }
    }

    if (rawKbis.isNotEmpty) {
      if (_looksLikeHttpUrl(rawKbis)) {
        // Preserve only trusted backend-managed storage URLs.
        if (_isTrustedStorageUrl(rawKbis)) {
          request.fields['kbisExtractUrl'] = rawKbis;
        }
      } else {
        final kbisFile = File(rawKbis);
        if (!kbisFile.existsSync()) {
          throw ApiException('Selected KBIS file could not be read. Please reselect the file.');
        }
        request.files.add(await http.MultipartFile.fromPath('kbisExtract', rawKbis, contentType: _mediaTypeForPath(rawKbis)));
      }
    }

    final certFilePaths = <String>[];
    final certUrlValues = <String>[];
    for (final item in certificateValues) {
      if (_looksLikeHttpUrl(item)) {
        if (_isTrustedStorageUrl(item)) {
          certUrlValues.add(item);
        }
        continue;
      }
      final file = File(item);
      if (file.existsSync()) {
        certFilePaths.add(item);
      } else {
        // Backward compatibility: previously stored certificate values may be
        // plain file names/keys instead of absolute URLs.
        certUrlValues.add(item);
      }
    }

    // Swagger: certificates (array of files in multipart/form-data).
    for (final path in certFilePaths) {
      request.files.add(await http.MultipartFile.fromPath('certificates', path, contentType: _mediaTypeForPath(path)));
    }

    // Keep previously uploaded URL-based certificates when editing profile.
    if (certUrlValues.isNotEmpty) {
      request.fields['certificateUploads'] = jsonEncode(certUrlValues);
    }

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> map = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) map = decoded;
      } catch (_) {
        map = {'message': response.body};
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[Auth] completeProviderProfile failed: ${response.statusCode} - ${response.body}');
      var msg = (map['message'] ?? map['error'] ?? 'Could not complete professional profile.').toString();
      final errors = map['errors'];
      if (errors is List) {
        final parts = <String>[];
        for (final e in errors) {
          if (e is Map) {
            final m = e['message'] ?? e['error'];
            if (m != null && m.toString().isNotEmpty) parts.add(m.toString());
          } else if (e != null) {
            parts.add(e.toString());
          }
        }
        if (parts.isNotEmpty) msg = '$msg\n${parts.join('\n')}';
      } else if (errors is Map) {
        final parts = <String>[];
        errors.forEach((key, val) {
          if (val is List) {
            parts.add('$key: ${val.join(', ')}');
          } else if (val != null) {
            parts.add('$key: $val');
          }
        });
        if (parts.isNotEmpty) msg = '$msg\n${parts.join('\n')}';
      }
      throw ApiException(msg, statusCode: response.statusCode);
    }

    final refreshed = await getCurrentUser();
    if (refreshed != null) {
      _currentUser = refreshed;
      _controller.add(refreshed);
    }
  }

  MediaType? _mediaTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return null;
  }

  bool _looksLikeHttpUrl(String raw) {
    final t = raw.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  bool _isTrustedStorageUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host.contains('homecraft-robolaxy.s3.eu-west-3.amazonaws.com')) return true;
    return false;
  }

  /// Clients: **PUT** `/users/me/profile` then merge response (or GET profile if body is empty).
  /// Providers: local session merge only (use [completeProviderProfile] for API).
  Future<void> updateBasicProfile({required String displayName, String? username, String? phone, String? city}) async {
    final token = await _session.getToken();
    final current = await _session.getUser();
    if (current == null) return;

    if (current.isProvider) {
      final updated = AppUser(
        uid: current.uid,
        email: current.email,
        displayName: displayName,
        username: username ?? current.username,
        role: current.role,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
        phone: phone,
        city: city,
        profilePhotoUrl: current.profilePhotoUrl,
        providerProfile: current.providerProfile,
      );
      await _session.setUser(updated);
      _currentUser = updated;
      _controller.add(updated);
      return;
    }

    if (token == null || token.isEmpty) {
      throw ApiException('Please login again.', statusCode: 401);
    }

    final nameParts = displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : displayName.trim();
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : firstName;

    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me/profile');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['firstName'] = firstName;
    request.fields['lastName'] = lastName;
    if (username != null && username.trim().isNotEmpty) {
      request.fields['username'] = username.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      request.fields['phone'] = phone.trim();
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    debugPrint('DEBUG UPDATE PROFILE: ${response.statusCode} ${response.body}');
    Map<String, dynamic> map = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) map = decoded;
      } catch (_) {
        map = {'message': response.body};
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = (map['message'] ?? map['error'] ?? 'Could not update profile.').toString();
      throw ApiException(msg, statusCode: response.statusCode);
    }
    await _persistClientProfileFromApiResponse(map, current);
  }

  /// **PUT** `/users/me/profile` with multipart/form-data.
  ///
  /// Swagger expects fields: `firstName`, `lastName`, optional `phone`, plus image file (`profileImage`).
  /// Large picks are resized and JPEG-compressed before upload to avoid 413 payload errors.
  static const List<({int minSide, int quality})> _profilePhotoSizeTiers = [(minSide: 1080, quality: 82), (minSide: 720, quality: 74), (minSide: 512, quality: 70), (minSide: 400, quality: 65)];

  Future<Uint8List> _compressProfilePhotoJpeg(String filePath, {required int minSide, required int quality}) async {
    try {
      final out = await FlutterImageCompress.compressWithFile(filePath, minWidth: minSide, minHeight: minSide, quality: quality, format: CompressFormat.jpeg);
      if (out == null || out.isEmpty) {
        throw ApiException('Could not process the image. Try a different photo.');
      }
      debugPrint('[Auth] Profile photo JPEG: ${out.length} bytes (max side ≤$minSide, quality $quality).');
      return out;
    } on MissingPluginException catch (_) {
      // Fallback for hot-reload sessions where newly added plugin isn't registered yet.
      final bytes = await File(filePath).readAsBytes();
      if (bytes.isEmpty) {
        throw ApiException('Could not read the selected image.');
      }
      debugPrint('[Auth] Compression plugin unavailable; using original bytes (${bytes.length} bytes).');
      return bytes;
    }
  }

  Future<void> uploadClientProfilePhoto(String filePath, {required String displayName, String? username, String? phone, String? city}) async {
    final token = await _session.getToken();
    final current = await _session.getUser();
    if (token == null || token.isEmpty || current == null) {
      throw ApiException('Please login again.', statusCode: 401);
    }
    if (current.isProvider) {
      throw ApiException('Use professional profile to change your photo.');
    }
    if (TokenUtils.isExpired(token)) {
      throw ApiException('Session expired. Please log in again.', statusCode: 401);
    }

    final nameParts = displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : displayName.trim();
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : firstName;

    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me/profile');
    ApiException? lastFailure;

    for (var i = 0; i < _profilePhotoSizeTiers.length; i++) {
      final tier = _profilePhotoSizeTiers[i];
      try {
        final jpegBytes = await _compressProfilePhotoJpeg(filePath, minSide: tier.minSide, quality: tier.quality);

        final request = http.MultipartRequest('PUT', uri);
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['firstName'] = firstName;
        request.fields['lastName'] = lastName;
        if (username != null && username.trim().isNotEmpty) {
          request.fields['username'] = username.trim();
        }
        if (phone != null && phone.trim().isNotEmpty) {
          request.fields['phone'] = phone.trim();
        }
        request.files.add(http.MultipartFile.fromBytes('profileImage', jpegBytes, filename: 'profile.jpg', contentType: MediaType('image', 'jpeg')));

        final streamed = await request.send().timeout(const Duration(seconds: 90));
        final response = await http.Response.fromStream(streamed);
        Map<String, dynamic> map = {};
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>)
              map = decoded;
            else
              map = {'data': decoded};
          } catch (_) {
            map = {'message': response.body};
          }
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _persistClientProfileFromApiResponse(map, current);
          debugPrint('[Auth] Profile photo upload OK.');
          return;
        }

        final message = (map['message'] ?? map['error'] ?? 'Could not update profile photo.').toString();
        lastFailure = ApiException(message, statusCode: response.statusCode);
        debugPrint('[Auth] Profile photo upload ${response.statusCode}: $message');

        final lower = message.toLowerCase();
        final tooLarge = response.statusCode == 413 || lower.contains('too large') || lower.contains('entity too large') || lower.contains('payload too');

        if (tooLarge && i < _profilePhotoSizeTiers.length - 1) {
          debugPrint('[Auth] Payload too large; retrying with smaller JPEG…');
          continue;
        }
        throw lastFailure;
      } on ApiException catch (e) {
        lastFailure = e;
        final lower = e.message.toLowerCase();
        final tooLarge = e.statusCode == 413 || lower.contains('too large') || lower.contains('entity too large') || lower.contains('payload too');
        if (tooLarge && i < _profilePhotoSizeTiers.length - 1) {
          debugPrint('[Auth] Payload too large; retrying with smaller JPEG…');
          continue;
        }
        rethrow;
      }
    }
    throw lastFailure ?? ApiException('Could not update profile photo.');
  }

  /// Professional profile photo upload.
  ///
  /// Uses Swagger profile update endpoint `/professionals/complete-profile`
  /// and sends existing provider fields with `profileImage` as multipart file.
  Future<void> uploadProviderProfilePhoto(String filePath) async {
    final token = await _session.getToken();
    final current = await _session.getUser();
    if (token == null || token.isEmpty || current == null) {
      throw ApiException('Please login again.', statusCode: 401);
    }
    if (!current.isProvider) {
      throw ApiException('Only professional accounts can use this action.');
    }
    final provider = current.providerProfile;
    if (provider == null) {
      throw ApiException('Please complete your professional profile first.');
    }

    ApiException? lastFailure;
    final uri = Uri.parse('${ApiConfig.baseUrl}/professionals/complete-profile');
    final payload = provider.toCompleteProfileApiMap();
    if ((payload['username'] as String?)?.trim().isEmpty ?? true) {
      payload['username'] = current.displayName;
    }
    if ((payload['contactEmail'] as String?)?.trim().isEmpty ?? true) {
      payload['contactEmail'] = current.email;
    }

    for (var i = 0; i < _profilePhotoSizeTiers.length; i++) {
      final tier = _profilePhotoSizeTiers[i];
      try {
        final jpegBytes = await _compressProfilePhotoJpeg(filePath, minSide: tier.minSide, quality: tier.quality);

        final request = http.MultipartRequest('PUT', uri);
        request.headers['Authorization'] = 'Bearer $token';
        payload.forEach((key, value) {
          if (value == null) return;
          if (value is List || value is Map<String, dynamic>) {
            request.fields[key] = jsonEncode(value);
          } else {
            request.fields[key] = value.toString();
          }
        });
        request.files.add(http.MultipartFile.fromBytes('profileImage', jpegBytes, filename: 'profile.jpg', contentType: MediaType('image', 'jpeg')));

        final streamed = await request.send().timeout(const Duration(seconds: 90));
        final response = await http.Response.fromStream(streamed);
        Map<String, dynamic> map = {};
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>)
              map = decoded;
            else
              map = {'data': decoded};
          } catch (_) {
            map = {'message': response.body};
          }
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final refreshed = await getCurrentUser();
          if (refreshed != null) {
            _currentUser = refreshed;
            _controller.add(refreshed);
          }
          return;
        }

        final message = (map['message'] ?? map['error'] ?? 'Could not update profile photo.').toString();
        lastFailure = ApiException(message, statusCode: response.statusCode);
        final lower = message.toLowerCase();
        final tooLarge = response.statusCode == 413 || lower.contains('too large') || lower.contains('entity too large') || lower.contains('payload too');
        if (tooLarge && i < _profilePhotoSizeTiers.length - 1) {
          continue;
        }
        throw lastFailure;
      } on ApiException catch (e) {
        lastFailure = e;
        final lower = e.message.toLowerCase();
        final tooLarge = e.statusCode == 413 || lower.contains('too large') || lower.contains('entity too large') || lower.contains('payload too');
        if (tooLarge && i < _profilePhotoSizeTiers.length - 1) {
          continue;
        }
        rethrow;
      }
    }

    throw lastFailure ?? ApiException('Could not update profile photo.');
  }

  Future<void> _persistClientProfileFromApiResponse(Map<String, dynamic> res, AppUser current) async {
    var payload = _extractClientProfilePayload(res);
    if (!_looksLikeUserPayload(payload)) {
      final token = await _session.getToken();
      if (token != null && token.isNotEmpty) {
        final again = await _api.get('/users/me/profile', token: token);
        payload = _extractClientProfilePayload(again);
      }
    }
    final merged = _mergeClientProfileFromPayload(current, payload);
    await _session.setUser(merged);
    _currentUser = merged;
    _controller.add(merged);
  }

  Map<String, dynamic> _extractClientProfilePayload(Map<String, dynamic> response) {
    var m = _extractPayloadMap(response);
    for (var i = 0; i < 3; i++) {
      final inner = m['user'] ?? m['profile'];
      if (inner is Map) {
        m = Map<String, dynamic>.from(inner);
      } else {
        break;
      }
    }
    return m;
  }

  bool _looksLikeUserPayload(Map<String, dynamic> p) {
    return p.containsKey('id') || p.containsKey('userId') || p.containsKey('username') || p.containsKey('email') || p.containsKey('phone');
  }

  String? _firstNonEmptyStr(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? _absoluteProfileUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    return '$base${s.startsWith('/') ? s : '/$s'}';
  }

  DateTime? _parseUserDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.tryParse(v.toString());
  }

  AppUser _mergeClientProfileFromPayload(AppUser current, Map<String, dynamic> p) {
    final firstName = p['firstName']?.toString().trim() ?? '';
    final lastName = p['lastName']?.toString().trim() ?? '';
    final fullNameFromParts = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final displayName = _firstNonEmptyStr([fullNameFromParts.isNotEmpty ? fullNameFromParts : null, p['username'], p['displayName'], p['name'], p['fullName']]) ?? current.displayName;
    final phone = _firstNonEmptyStr([p['phone'], p['phoneNumber'], p['mobile']]) ?? current.phone;
    final city = _firstNonEmptyStr([p['city'], p['address']]) ?? current.city;
    final email = _firstNonEmptyStr([p['email']]) ?? current.email;
    final uid = _firstNonEmptyStr([p['id'], p['userId'], p['uid']]) ?? current.uid;

    final hasPhotoKey = p.containsKey('profilePhotoUrl') || p.containsKey('profileImage') || p.containsKey('profileImageUrl') || p.containsKey('avatarUrl') || p.containsKey('photoUrl');

    final rawPhoto = _firstNonEmptyStr([p['profilePhotoUrl'], p['profileImage'], p['profileImageUrl'], p['avatarUrl'], p['photoUrl']]);
    final createdAt = _parseUserDate(p['createdAt']) ?? current.createdAt;
    final updatedAt = _parseUserDate(p['updatedAt']) ?? DateTime.now();
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      username: p['username']?.toString() ?? current.username,
      role: current.role,
      createdAt: createdAt,
      updatedAt: updatedAt,
      phone: phone,
      city: city,
      profilePhotoUrl: hasPhotoKey ? _absoluteProfileUrl(rawPhoto) : (_absoluteProfileUrl(rawPhoto) ?? current.profilePhotoUrl),
      providerProfile: current.providerProfile,
    );
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

  AppUser _mapApiUser(Map<String, dynamic> payload, {required UserRole roleHint, String? emailFallback, String? displayNameFallback}) {
    final role = UserRole.fromString((payload['role'] ?? roleHint.name).toString());
    final uid = (payload['id'] ?? payload['_id'] ?? payload['uid'] ?? payload['userId'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();
    final email = (payload['email'] ?? emailFallback ?? '').toString();
    final fn = payload['firstName']?.toString().trim() ?? '';
    final ln = payload['lastName']?.toString().trim() ?? '';
    final fullFromParts = [fn, ln].where((s) => s.isNotEmpty).join(' ');
    final displayName =
        _firstNonEmptyStr([
          fullFromParts.isNotEmpty ? fullFromParts : null,
          payload['displayName']?.toString(),
          payload['username']?.toString(),
          payload['name']?.toString(),
          payload['fullName']?.toString(),
          displayNameFallback,
        ]) ??
        '';
    final phone = payload['phone']?.toString();
    final city = (payload['city'] ?? payload['address'])?.toString();
    final rawPhoto = _firstNonEmptyStr([payload['profilePhotoUrl'], payload['profileImage'], payload['profileImageUrl'], payload['avatarUrl'], payload['photoUrl']]);
    final providerProfile = payload['providerProfile'] is Map<String, dynamic> ? ProviderProfile.fromMap(payload['providerProfile'] as Map<String, dynamic>) : null;
    final createdMs = payload['createdAt'];
    final updatedMs = payload['updatedAt'];
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      username: payload['username']?.toString(),
      role: role,
      createdAt: createdMs is int ? DateTime.fromMillisecondsSinceEpoch(createdMs) : (_parseUserDate(createdMs) ?? DateTime.now()),
      updatedAt: updatedMs is int ? DateTime.fromMillisecondsSinceEpoch(updatedMs) : _parseUserDate(updatedMs),
      phone: phone,
      city: city,
      profilePhotoUrl: _absoluteProfileUrl(rawPhoto),
      providerProfile: providerProfile,
    );
  }

  AppUser _mapProfessionalToAppUser(Map<String, dynamic> payload, {required AppUser fallback}) {
    final profile = ProviderProfile.fromMap(payload);

    final hasPhotoKey =
        payload.containsKey('profilePhotoUrl') ||
        payload.containsKey('profileImageUrl') ||
        payload.containsKey('profileImage') ||
        (payload['professional'] is Map && ((payload['professional'] as Map).containsKey('profileImageUrl') || (payload['professional'] as Map).containsKey('profileImage')));

    final rawPhoto = _firstNonEmptyStr([
      payload['profilePhotoUrl'],
      payload['profileImageUrl'],
      payload['profileImage'],
      (payload['professional'] is Map ? (payload['professional'] as Map)['profileImageUrl'] : null),
      (payload['professional'] is Map ? (payload['professional'] as Map)['profileImage'] : null),
    ]);
    return AppUser(
      uid: fallback.uid,
      email: (payload['email'] ?? fallback.email).toString(),
      displayName: profile.displayName.isNotEmpty ? profile.displayName : fallback.displayName,
      role: UserRole.provider,
      createdAt: fallback.createdAt,
      updatedAt: DateTime.now(),
      phone: profile.phone.isEmpty ? fallback.phone : profile.phone,
      city: profile.address.isEmpty ? fallback.city : profile.address,
      profilePhotoUrl: hasPhotoKey ? _absoluteProfileUrl(rawPhoto) : (_absoluteProfileUrl(rawPhoto) ?? fallback.profilePhotoUrl),
      providerProfile: profile,
    );
  }
}
