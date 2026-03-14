import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/app_user.dart';

/// Firebase Auth + Firestore data source for auth.
class AuthRemoteDatasource {
  AuthRemoteDatasource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> setDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName);
    }
  }

  /// Create or overwrite user document in Firestore (call after account creation).
  Future<void> setUserDocument(AppUser appUser) async {
    await _firestore.collection(_usersCollection).doc(appUser.uid).set(appUser.toMap());
  }

  /// Get user document by uid. Returns null if not found.
  Future<AppUser?> getUserDocument(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromMap(doc.data()!);
    }
    return null;
  }

  /// Update display name in Firestore and Firebase Auth.
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(displayName.trim());
    await _firestore.collection(_usersCollection).doc(user.uid).update({
      'displayName': displayName.trim(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Update profile fields in Firestore (and Auth for displayName).
  Future<void> updateProfile({
    required String displayName,
    String? phone,
    String? city,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(displayName.trim());
    final data = <String, dynamic>{
      'displayName': displayName.trim(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (phone != null) {
      data['phone'] = phone.trim().isEmpty ? FieldValue.delete() : phone.trim();
    }
    if (city != null) {
      data['city'] = city.trim().isEmpty ? FieldValue.delete() : city.trim();
    }
    await _firestore.collection(_usersCollection).doc(user.uid).update(data);
  }
}
