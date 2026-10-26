import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notifications_remote_datasource.dart';
import '../../domain/app_notification.dart';

final notificationsRemoteDatasourceProvider = Provider<NotificationsRemoteDatasource>((ref) {
  return NotificationsRemoteDatasource();
});

/// Unread count for the current role (client vs professional).
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(authStateNotifierProvider).currentUser;
  if (user == null) return 0;
  final ds = ref.watch(notificationsRemoteDatasourceProvider);
  return ds.countUnread(isProfessional: user.isProvider);
});

/// Full list for the notification screen (refetch via [invalidate]).
final notificationsListProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final user = ref.watch(authStateNotifierProvider).currentUser;
  if (user == null) return [];
  final ds = ref.watch(notificationsRemoteDatasourceProvider);
  return ds.fetchNotifications(isProfessional: user.isProvider, limit: 100);
});
