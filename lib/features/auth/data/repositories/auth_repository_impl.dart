import 'package:flutter/foundation.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/provider_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/network/api_exception.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthRemoteDatasource? datasource})
      : _ds = datasource ?? AuthRemoteDatasource();

  final AuthRemoteDatasource _ds;

  @override
  Stream<AppUser?> get authStateChanges => _ds.authStateChanges;

  @override
  AppUser? get currentUser => _ds.currentUser;

  @override
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
    UserRole? role,
  }) async {
    try {
      final appUser = await _ds.login(
        email: email,
        password: password,
        role: role ?? UserRole.client,
      );
      return (user: appUser, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (_) {
      return (user: null, errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      final appUser = await _ds.register(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
      return (user: appUser, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (_) {
      return (user: null, errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<String?> sendPasswordResetEmail(String email, {UserRole role = UserRole.client}) async {
    try {
      await _ds.sendForgotPassword(email: email, role: role);
      return null;
    } on ApiException catch (e) {
      // A 5xx from the forgot-password endpoint almost always means the
      // server's email/SMTP service is misconfigured — not a user error.
      if (e.statusCode != null && e.statusCode! >= 500) {
        return 'Email service is temporarily unavailable. Please try again later.';
      }
      return _friendlyError(e.message);
    } catch (_) {
      return 'Network error. Check your connection.';
    }
  }

  @override
  Future<AuthResult> socialLogin({
    required String provider,
    required String idToken,
    required UserRole role,
  }) async {
    try {
      final user = await _ds.socialLogin(provider: provider, idToken: idToken, role: role);
      return (user: user, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (_) {
      return (user: null, errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<String?> verifyResetOtp({
    required String email,
    required String otp,
    required UserRole role,
  }) async {
    try {
      await _ds.verifyResetOtp(email: email, otp: otp, role: role);
      return null;
    } on ApiException catch (e) {
      return _friendlyError(e.message);
    } catch (_) {
      return 'Network error. Check your connection.';
    }
  }

  @override
  Future<String?> resetPassword({
    required String email,
    required String otp,
    required String password,
    required UserRole role,
  }) async {
    try {
      await _ds.resetPassword(email: email, otp: otp, password: password, role: role);
      return null;
    } on ApiException catch (e) {
      return _friendlyError(e.message);
    } catch (_) {
      return 'Network error. Check your connection.';
    }
  }

  @override
  Future<void> signOut() => _ds.signOut();

  @override
  Future<AuthResult> updateProfile({
    required String displayName,
    String? username,
    String? phone,
    String? city,
  }) async {
    try {
      await _ds.updateBasicProfile(displayName: displayName, username: username, phone: phone, city: city);
      return (user: _ds.currentUser, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (_) {
      return (user: null, errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<AuthResult> updateClientProfilePhoto(
    String filePath, {
    required String displayName,
    String? username,
    String? phone,
    String? city,
  }) async {
    try {
      await _ds.uploadClientProfilePhoto(
        filePath,
        displayName: displayName,
        username: username,
        phone: phone,
        city: city,
      );
      return (user: _ds.currentUser, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (e) {
      debugPrint('[AuthRepository] updateClientProfilePhoto failed: $e');
      return (user: null, errorMessage: _friendlyError(e.toString()));
    }
  }

  @override
  Future<AuthResult> updateProviderProfile(ProviderProfile profile) async {
    try {
      await _ds.completeProviderProfile(profile);
      final appUser = await _ds.getCurrentUser();
      return (user: appUser, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (_) {
      return (user: null, errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<AuthResult> updateProviderProfilePhoto(String filePath) async {
    try {
      await _ds.uploadProviderProfilePhoto(filePath);
      return (user: _ds.currentUser, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (e) {
      debugPrint('[AuthRepository] updateProviderProfilePhoto failed: $e');
      return (user: null, errorMessage: _friendlyError(e.toString()));
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return _ds.getCurrentUser();
  }

  @override
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _ds.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (e) {
      return _friendlyError(e.message);
    } catch (_) {
      return 'Network error. Check your connection.';
    }
  }

  @override
  Future<String?> deleteAccount() async {
    try {
      await _ds.deleteAccount();
      return null;
    } on ApiException catch (e) {
      return _friendlyError(e.message);
    } catch (_) {
      return 'Network error. Check your connection.';
    }
  }

  String _friendlyError(String raw) {
    final msg = raw.trim();
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login: 535') ||
        lower.contains('badcredentials') ||
        lower.contains('smtp') ||
        lower.contains('5.7.8') ||
        lower.contains('username and password not accepted') ||
        lower.contains('mail') && lower.contains('not accepted')) {
      return 'Email service is temporarily unavailable. Please try again later.';
    }
    // MySQL: Table 'service_backend.professionals' doesn't exist (quotes in message).
    if (lower.contains('service_backend.professionals') &&
        (lower.contains("doesn't exist") || lower.contains('does not exist'))) {
      return 'Professional accounts are temporarily unavailable. Please try again later or contact support.';
    }
    if (lower.contains('missingpluginexception')) {
      return 'Image upload service is not ready yet. Please fully restart the app and try again.';
    }
    if (lower.contains('network error') ||
        lower.contains('socketexception') ||
        lower.contains('connection')) {
      return 'Network error. Check your connection.';
    }
    return msg;
  }
}
