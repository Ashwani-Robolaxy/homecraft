import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state_notifier.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

/// Incremented by PersonalInfoScreen after a successful profile save.
/// ProfileScreen listens to this to trigger an immediate data + image refresh.
class ProfileRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void trigger() => state++;
}

final profileRefreshTriggerProvider =
    NotifierProvider<ProfileRefreshNotifier, int>(ProfileRefreshNotifier.new);

/// Persists selected tab index for the client bottom nav across route changes.
/// Profile tab = 4.
class ClientTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final clientTabIndexProvider = NotifierProvider<ClientTabIndexNotifier, int>(ClientTabIndexNotifier.new);

/// Persists selected tab index for the provider bottom nav across route changes.
/// Profile tab = 3.
class ProviderTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final providerTabIndexProvider = NotifierProvider<ProviderTabIndexNotifier, int>(ProviderTabIndexNotifier.new);

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
