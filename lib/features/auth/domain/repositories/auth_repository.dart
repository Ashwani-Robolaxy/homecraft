import '../models/app_user.dart';
import '../models/provider_profile.dart';

/// Result of auth operations; either [AppUser] or error message.
typedef AuthResult = ({AppUser? user, String? errorMessage});

abstract class AuthRepository {
  /// Stream of current auth state: null = not logged in, [AppUser] = logged in.
  Stream<AppUser?> get authStateChanges;

  /// Current user if logged in.
  AppUser? get currentUser;

  /// Sign in with email and password. Fetches user doc from Firestore for role.
  Future<AuthResult> signInWithEmailAndPassword({required String email, required String password});

  /// Create account and Firestore user doc with [role]. Returns user or error.
  Future<AuthResult> registerWithEmailAndPassword({required String email, required String password, required String displayName, required UserRole role});

  /// Send password reset email.
  Future<String?> sendPasswordResetEmail(String email);

  /// Sign out.
  Future<void> signOut();

  /// Update profile (Firestore + Firebase Auth). Returns updated user or error.
  Future<AuthResult> updateProfile({
    required String displayName,
    String? phone,
    String? city,
  });

  /// Update full provider profile (profile setup). Use for provider role only.
  Future<AuthResult> updateProviderProfile(ProviderProfile profile);

  /// Fetch current user from Firestore (for refresh after update).
  Future<AppUser?> getCurrentUser();
}
