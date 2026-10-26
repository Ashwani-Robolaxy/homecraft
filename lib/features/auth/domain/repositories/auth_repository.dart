import '../models/app_user.dart';
import '../models/provider_profile.dart';

/// Result of auth operations; either [AppUser] or error message.
typedef AuthResult = ({AppUser? user, String? errorMessage});

abstract class AuthRepository {
  /// Stream of current auth state: null = not logged in, [AppUser] = logged in.
  Stream<AppUser?> get authStateChanges;

  /// Current user if logged in.
  AppUser? get currentUser;

  /// Sign in with email and password.
  /// When [role] is provided, login is attempted only for that role.
  Future<AuthResult> signInWithEmailAndPassword({required String email, required String password, UserRole? role});

  /// Create account with [role]. Returns user or error.
  Future<AuthResult> registerWithEmailAndPassword({required String email, required String password, required String displayName, required UserRole role});

  /// Send password reset email.
  Future<String?> sendPasswordResetEmail(String email, {UserRole role});

  /// Social login with provider token.
  Future<AuthResult> socialLogin({required String provider, required String idToken, required UserRole role});

  /// Verify reset OTP.
  Future<String?> verifyResetOtp({required String email, required String otp, required UserRole role});

  /// Reset password with OTP.
  Future<String?> resetPassword({required String email, required String otp, required String password, required UserRole role});

  /// Sign out.
  Future<void> signOut();

  /// Update basic profile fields.
  Future<AuthResult> updateProfile({required String displayName, String? username, String? phone, String? city});

  /// Client: multipart **PUT** `/users/me/profile` (firstName/lastName/phone + `profileImage` file).
  Future<AuthResult> updateClientProfilePhoto(
    String filePath, {
    required String displayName,
    String? username,
    String? phone,
    String? city,
  });

  /// Professional: multipart upload using Swagger update profile endpoint.
  Future<AuthResult> updateProviderProfilePhoto(String filePath);

  /// Update full provider profile (profile setup). Use for provider role only.
  Future<AuthResult> updateProviderProfile(ProviderProfile profile);

  /// Fetch current user from API/session for refresh.
  Future<AppUser?> getCurrentUser();

  /// Permanently delete the authenticated user's account and sign out.
  /// Returns null on success or an error message string on failure.
  Future<String?> deleteAccount();

  /// Change password for local (non-social) accounts.
  /// Returns null on success or an error message string on failure.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
