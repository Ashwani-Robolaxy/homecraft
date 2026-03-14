import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state_notifier.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

/// Notifier for GoRouter redirect; notifies when auth state changes.
final authStateNotifierProvider = Provider<AuthStateNotifier>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final notifier = AuthStateNotifier(repo);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// Current user stream: null when not logged in.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
