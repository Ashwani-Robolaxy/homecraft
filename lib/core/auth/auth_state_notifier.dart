import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

/// Notifies GoRouter when auth state changes so redirect can run.
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._repo) {
    _sub = _repo.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  final AuthRepository _repo;
  late final StreamSubscription<AppUser?> _sub;

  AppUser? _user;
  AppUser? get currentUser => _user;

  /// Re-fetch current user from backend/session (e.g. after profile update).
  Future<void> refresh() async {
    _user = await _repo.getCurrentUser();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
