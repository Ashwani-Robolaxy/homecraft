import 'package:firebase_auth/firebase_auth.dart' as fba;

import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthRemoteDatasource? datasource})
      : _ds = datasource ?? AuthRemoteDatasource();

  final AuthRemoteDatasource _ds;

  @override
  Stream<AppUser?> get authStateChanges async* {
    await for (final user in _ds.authStateChanges) {
      if (user == null) {
        yield null;
      } else {
        final appUser = await _ds.getUserDocument(user.uid);
        yield appUser;
      }
    }
  }

  @override
  AppUser? get currentUser => null; // Sync current user would require a cache; we use stream.

  @override
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _ds.signInWithEmailAndPassword(email: email, password: password);
      final fbUser = _ds.currentFirebaseUser;
      if (fbUser == null) {
        return (user: null, errorMessage: 'auth.errors.generic');
      }
      final appUser = await _ds.getUserDocument(fbUser.uid);
      if (appUser == null) {
        await _ds.signOut();
        return (user: null, errorMessage: 'auth.errors.generic');
      }
      return (user: appUser, errorMessage: null);
    } on fba.FirebaseAuthException catch (e) {
      return (user: null, errorMessage: _mapAuthException(e.code));
    } catch (_) {
      return (user: null, errorMessage: 'auth.errors.network');
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
      await _ds.createUserWithEmailAndPassword(email: email, password: password);
      final fbUser = _ds.currentFirebaseUser;
      if (fbUser == null) {
        return (user: null, errorMessage: 'auth.errors.generic');
      }
      await _ds.setDisplayName(displayName);
      final appUser = AppUser(
        uid: fbUser.uid,
        email: fbUser.email ?? email,
        displayName: displayName.trim(),
        role: role,
        createdAt: DateTime.now(),
      );
      await _ds.setUserDocument(appUser);
      return (user: appUser, errorMessage: null);
    } on fba.FirebaseAuthException catch (e) {
      return (user: null, errorMessage: _mapAuthException(e.code));
    } catch (_) {
      return (user: null, errorMessage: 'auth.errors.network');
    }
  }

  @override
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _ds.sendPasswordResetEmail(email);
      return null;
    } on fba.FirebaseAuthException catch (e) {
      return _mapAuthException(e.code);
    } catch (_) {
      return 'auth.errors.network';
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
      final uid = _ds.currentFirebaseUser?.uid;
      if (uid == null) return (user: null, errorMessage: 'auth.errors.generic');
      await _ds.updateProfile(displayName: displayName, phone: phone, city: city);
      final appUser = await _ds.getUserDocument(uid);
      return (user: appUser, errorMessage: null);
    } catch (_) {
      return (user: null, errorMessage: 'auth.errors.network');
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final uid = _ds.currentFirebaseUser?.uid;
    if (uid == null) return null;
    return _ds.getUserDocument(uid);
  }

  String _mapAuthException(String code) {
    switch (code) {
      case 'user-not-found':
        return 'auth.errors.user_not_found';
      case 'wrong-password':
      case 'invalid-credential':
        return 'auth.errors.wrong_password';
      case 'email-already-in-use':
        return 'auth.errors.email_already_in_use';
      case 'invalid-email':
        return 'auth.errors.invalid_email';
      case 'weak-password':
        return 'auth.errors.weak_password';
      case 'too-many-requests':
        return 'auth.errors.too_many_requests';
      default:
        return 'auth.errors.generic';
    }
  }
}
