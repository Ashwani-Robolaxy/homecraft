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
    String? phone,
    String? city,
  }) async {
    try {
      await _ds.updateBasicProfile(displayName: displayName, phone: phone, city: city);
      final appUser = await _ds.getCurrentUser();
      return (user: appUser, errorMessage: null);
    } on ApiException catch (e) {
      return (user: null, errorMessage: _friendlyError(e.message));
    } catch (_) {
      return (user: null, errorMessage: 'Network error. Check your connection.');
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
  Future<AppUser?> getCurrentUser() async {
    return _ds.getCurrentUser();
  }

  String _friendlyError(String raw) {
    final msg = raw.trim();
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login: 535') ||
        lower.contains('badcredentials') ||
        lower.contains('smtp')) {
      return 'Reset email service is temporarily unavailable. Please try again later.';
    }
    // MySQL: Table 'service_backend.professionals' doesn't exist (quotes in message).
    if (lower.contains('service_backend.professionals') &&
        (lower.contains("doesn't exist") || lower.contains('does not exist'))) {
      return 'Professional accounts are temporarily unavailable. Please try again later or contact support.';
    }
    return msg;
  }
}
