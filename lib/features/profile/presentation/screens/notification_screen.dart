import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/domain/app_notification.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _markingAll = false;
  bool _optimisticAllRead = false;
  final Set<String> _optimisticReadIds = <String>{};

  bool get _isPro => ref.read(authStateNotifierProvider).currentUser?.isProvider ?? false;

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() {
      _markingAll = true;
      _optimisticAllRead = true;
    });
    try {
      await ref.read(notificationsRemoteDatasourceProvider).markAllRead(isProfessional: _isPro);
      if (!mounted) return;
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticAllRead = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notification.mark_read_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _navigateToConcern(AppNotification n) {
    final type = n.type.toLowerCase();
    final title = n.title.toLowerCase();
    final body = n.body.toLowerCase();

    final isBooking = type.contains('book') || title.contains('book') || body.contains('book');
    final isMessage = type.contains('message') || type.contains('chat') || title.contains('message') || title.contains('chat') || body.contains('message') || body.contains('chat');
    final isVerification = type.contains('verif') || title.contains('verif') || body.contains('verif');

    if (_isPro) {
      if (isBooking) {
        ref.read(providerTabIndexProvider.notifier).setIndex(2);
      } else if (isMessage) {
        ref.read(providerTabIndexProvider.notifier).setIndex(1);
      } else if (isVerification) {
        ref.read(providerTabIndexProvider.notifier).setIndex(3);
      }
      context.go('/provider-home');
    } else {
      if (isBooking) {
        ref.read(clientTabIndexProvider.notifier).setIndex(2);
      } else if (isMessage) {
        ref.read(clientTabIndexProvider.notifier).setIndex(3);
      } else {
        ref.read(clientTabIndexProvider.notifier).setIndex(4);
      }
      context.go('/home');
    }
  }

  Future<void> _onTapItem(AppNotification n) async {
    _navigateToConcern(n);

    if (_isEffectivelyRead(n) || n.id.isEmpty) return;
    setState(() => _optimisticReadIds.add(n.id));
    try {
      await ref.read(notificationsRemoteDatasourceProvider).markRead(isProfessional: _isPro, id: n.id);
      if (!mounted) return;
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticReadIds.remove(n.id));
      }
    }
  }

  bool _isEffectivelyRead(AppNotification n) {
    return _optimisticAllRead || _optimisticReadIds.contains(n.id) || n.isRead;
  }

  static IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('book')) return LucideIcons.calendarCheck;
    if (t.contains('project')) return LucideIcons.folderKanban;
    if (t.contains('subscri') || t.contains('plan') || t.contains('pay')) return LucideIcons.wallet;
    if (t.contains('verif')) return LucideIcons.badgeCheck;
    if (t.contains('message') || t.contains('chat')) return LucideIcons.messageCircle;
    return LucideIcons.bell;
  }

  static String _sectionLabel(DateTime d, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'notification.today'.tr();
    if (day == today.subtract(const Duration(days: 1))) return 'notification.yesterday'.tr();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMMd(localeTag).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(notificationsListProvider);
    final hasUnread = listAsync.maybeWhen(
      data: (list) => list.any((n) => !_isEffectivelyRead(n)),
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: 'notification.title'.tr(),
        showLogo: false,
        showNotification: false,
        trailingActions: [
          if (hasUnread)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: Text(
                'notification.mark_all_read'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('notification.load_error'.tr(), style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(notificationsListProvider),
                  child: Text('common.retry'.tr(), style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyNotificationsView();
          final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final groups = <String, List<AppNotification>>{};
          for (final n in sorted) {
            final label = _sectionLabel(n.createdAt, context);
            groups.putIfAbsent(label, () => []).add(n);
          }
          final orderedKeys = groups.keys.toList();
          return RefreshIndicator(
            color: AppColors.primaryRed,
            onRefresh: () async {
              ref.invalidate(notificationsListProvider);
              ref.invalidate(unreadNotificationCountProvider);
              await ref.read(notificationsListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (var i = 0; i < orderedKeys.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                    child: Text(
                      orderedKeys[i],
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ...groups[orderedKeys[i]]!.map((n) => _NotificationTile(
                        notification: n,
                        isRead: _isEffectivelyRead(n),
                        icon: _iconForType(n.type),
                        onTap: () => _onTapItem(n),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDF3F3),
                border: Border.all(color: const Color(0xFFEAD8D8)),
              ),
              child: const Icon(
                LucideIcons.bell,
                size: 72,
                color: Color(0xFFC8A13A),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'notification.no_notifications_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'notification.no_notifications_desc'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.icon,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isRead;
  final IconData icon;
  final VoidCallback onTap;

  static String _localizeNotificationTitle(String title, BuildContext context) {
    final isFr = context.locale.languageCode == 'fr';
    if (!isFr) return title.isEmpty ? 'Notification' : title;
    final lower = title.trim().toLowerCase();
    if (lower.contains('booking delivery accepted')) {
      return 'Livraison acceptée !';
    }
    if (lower.contains('new booking request')) {
      return 'Nouvelle demande de réservation !';
    }
    if (lower.contains('profile verified')) {
      return 'Profil vérifié !';
    }
    if (lower.contains('welcome to homecraft')) {
      return 'Bienvenue sur HomeCraft !';
    }
    if (lower.contains('booking accepted')) {
      return 'Réservation acceptée !';
    }
    if (lower.contains('booking rejected') || lower.contains('booking declined')) {
      return 'Réservation refusée';
    }
    if (lower.contains('new message') || lower.contains('new chat')) {
      return 'Nouveau message';
    }
    if (lower.contains('project interest') || lower.contains('marked interest')) {
      return 'Intérêt pour un projet';
    }
    if (lower.contains('subscription')) {
      return 'Abonnement';
    }
    if (lower == 'notification' || lower.isEmpty) {
      return 'Notification';
    }
    return title;
  }

  static String _localizeNotificationBody(String body, BuildContext context) {
    final isFr = context.locale.languageCode == 'fr';
    if (!isFr) return body.isEmpty ? ' ' : body;
    final trimmed = body.trim();
    final lower = trimmed.toLowerCase();

    if (lower.contains('client has accepted your delivery for the booking on')) {
      final datePart = trimmed.split(RegExp(r'on\s*', caseSensitive: false)).last.replaceAll('.', '').trim();
      if (datePart.isNotEmpty) {
        return 'Le client a accepté votre livraison pour la réservation du $datePart.';
      }
      return 'Le client a accepté votre livraison pour la réservation.';
    }
    if (lower.contains('you have a new booking request for')) {
      final datePart = trimmed.split(RegExp(r'for\s*', caseSensitive: false)).last.replaceAll('.', '').trim();
      if (datePart.isNotEmpty) {
        return 'Vous avez une nouvelle demande de réservation pour le $datePart.';
      }
      return 'Vous avez une nouvelle demande de réservation.';
    }
    if (lower.contains('your professional profile has been verified')) {
      return 'Votre profil professionnel a été vérifié. Vous pouvez maintenant commencer à recevoir des demandes de projet.';
    }
    if (lower.contains('we\'re glad to have you here') || lower.contains('complete your profile to start receiving project requests')) {
      return 'Nous sommes ravis de vous compter parmi nous. Complétez votre profil pour commencer à recevoir des demandes de projet.';
    }
    if (lower.contains('your booking request has been accepted')) {
      return 'Votre demande de réservation a été acceptée.';
    }
    if (lower.contains('your booking request was declined') || lower.contains('your booking was rejected')) {
      return 'Votre demande de réservation a été refusée.';
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final title = _localizeNotificationTitle(n.title, context);
    final body = _localizeNotificationBody(n.body, context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF9A1111), Color(0xFF710808)],
                ),
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
