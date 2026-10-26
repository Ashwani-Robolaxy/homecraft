import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/logout_confirm_dialog.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/data/subscription_remote_datasource.dart';
import '../../../subscription/domain/subscription_data.dart';
import '../widgets/profile_hero_header.dart';

String _normalizeApiVerificationStatus(String raw) => raw.trim().toLowerCase();

/// True when the saved provider profile matches what we require before treating
/// verification as submitted (subscription API may still say profile_incomplete briefly).
bool _providerLooksSubmittedForVerification(AppUser? user) {
  if (user == null || !user.isProvider) return false;
  final p = user.providerProfile;
  if (p == null) return false;
  final hasSpecialty = (p.specialty?.trim().isNotEmpty == true) ||
      (p.categoryId != null && p.categoryId! > 0);
  final siret = (p.siret ?? '').trim();
  final hasSiret = siret.isNotEmpty && siret != '-';
  final hasCompany = (p.companyName ?? '').trim().isNotEmpty;
  final hasServiceAreas = p.serviceAreas.any((e) => e.isValidForApi);
  return hasSpecialty && hasSiret && hasCompany && hasServiceAreas;
}

String _effectiveVerificationStatus(String apiRaw, AppUser? user) {
  final api = _normalizeApiVerificationStatus(apiRaw);
  switch (api) {
    case 'verified':
    case 'rejected':
    case 'blocked':
      return api;
    case 'pending':
    case 'pending_verification':
      return 'pending_verification';
    case 'profile_incomplete':
    case '':
      if (_providerLooksSubmittedForVerification(user)) {
        return 'pending_verification';
      }
      return api.isEmpty ? 'profile_incomplete' : api;
    default:
      return api.isEmpty ? 'profile_incomplete' : api;
  }
}

class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  ConsumerState<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends ConsumerState<ProviderProfileScreen> {
  static const double _expandedBody = 248;
  final ValueNotifier<double> _headerExpandT = ValueNotifier(1.0);

  final _subDs = SubscriptionRemoteDatasource();
  SubscriptionContext? _subCtx;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    try {
      final ctx = await _subDs.fetchContext();
      if (!mounted) return;
      setState(() => _subCtx = ctx);
    } catch (_) {
      // Non-fatal — UI falls back to defaults
    }
  }

  @override
  void dispose() {
    _headerExpandT.dispose();
    super.dispose();
  }

  void _deferHeaderExpandT(double t) {
    if ((_headerExpandT.value - t).abs() <= 0.002) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if ((_headerExpandT.value - t).abs() > 0.002) {
        _headerExpandT.value = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(profileRefreshTriggerProvider, (_, __) {
      _loadSubscription();
    });
    final user = ref.watch(authStateNotifierProvider).currentUser;
    final displayName = user?.displayName ?? '';
    final top = MediaQuery.paddingOf(context).top;
    final expandedHeight = _expandedBody + top;
    final apiVerificationStatus =
        _subCtx?.subscriptionState.verificationStatus ?? '';
    final verificationStatus =
        _effectiveVerificationStatus(apiVerificationStatus, user);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: expandedHeight,
            toolbarHeight: kToolbarHeight,
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: ValueListenableBuilder<double>(
              valueListenable: _headerExpandT,
              builder: (context, t, _) {
                final show = (1.0 - t).clamp(0.0, 1.0);
                return IgnorePointer(
                  ignoring: show < 0.05,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: show,
                    child: Row(
                      children: [
                        _toolbarAvatar(user?.profilePhotoUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            displayName.isEmpty ? 'Provider' : displayName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final minH = kToolbarHeight + top;
                final maxH = expandedHeight;
                final range = (maxH - minH).clamp(1.0, double.infinity);
                final t = ((constraints.maxHeight - minH) / range).clamp(0.0, 1.0);
                _deferHeaderExpandT(t);
                return ProfileHeroHeader(
                  displayName: displayName,
                  profilePhotoUrl: user?.profilePhotoUrl,
                  expandT: t,
                  emptyNameFallback: 'Provider',
                  verificationStatus: verificationStatus,
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                children: [
                  _SubscriptionCard(preloaded: _subCtx),
                  const SizedBox(height: 16),
                  _buildMenuSection(context, ref),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildMenuCard([
          _buildMenuItem(context, icon: LucideIcons.user, title: 'provider.profile.profile_info'.tr(), onTap: () => context.push('/provider-profile-info')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.bell, title: 'provider.profile.notification_preference'.tr(), onTap: () => context.push('/notification-preference')),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(context, icon: LucideIcons.layers, title: 'provider.profile.accepted_projects'.tr(), onTap: () => context.push('/accepted-projects')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.star, title: 'provider.profile.my_reviews'.tr(), onTap: () => context.push('/professional-reviews')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.briefcase, title: 'portfolio_mgmt.title'.tr(), onTap: () => context.push('/professional-portfolio')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.heart, title: 'provider.profile.favorites'.tr(), onTap: () => context.push('/provider-favorites')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.crown, title: 'provider.profile.subscription'.tr(), onTap: () => context.push('/subscription-plans')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.helpCircle, title: 'provider.profile.contact_support'.tr(), onTap: () => context.push('/contact-support')),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(context, icon: LucideIcons.settings, title: 'settings.title'.tr(), onTap: () => context.push('/settings')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.fileText, title: 'provider.profile.term_condition'.tr(), onTap: () => context.push('/terms-of-service')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.shieldAlert, title: 'provider.profile.privacy_policy'.tr(), onTap: () => context.push('/privacy-policy')),
          const Divider(height: 1),
          _buildMenuItem(context, icon: LucideIcons.info, title: 'provider.profile.faq_about_us'.tr(), onTap: () => context.push('/about-us')),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            context,
            icon: LucideIcons.logOut,
            title: 'provider.profile.log_out'.tr(),
            onTap: () async {
              final ok = await showLogoutConfirmDialog(context);
              if (!ok || !context.mounted) return;
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/splash');
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primaryRed, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textMain),
      ),
      trailing: const Icon(LucideIcons.chevronRight, size: 20, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _toolbarAvatar(String? url) {
    final imageUrl = url?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        backgroundImage: const AssetImage(AppAssets.profilePlaceholder),
      );
    }
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[300],
          backgroundImage: const AssetImage(AppAssets.profilePlaceholder),
        ),
      ),
    );
  }
}

// ── Subscription status card ──────────────────────────────────────────────────

class _SubscriptionCard extends StatefulWidget {
  const _SubscriptionCard({this.preloaded});

  /// If the parent already fetched the context, pass it here to skip a
  /// redundant network call. The card still shows while preloaded is null.
  final SubscriptionContext? preloaded;

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard> {
  final _ds = SubscriptionRemoteDatasource();
  SubscriptionContext? _ctx;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.preloaded != null) {
      _ctx = widget.preloaded;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(_SubscriptionCard old) {
    super.didUpdateWidget(old);
    if (widget.preloaded != null && widget.preloaded != old.preloaded) {
      setState(() { _ctx = widget.preloaded; _loading = false; });
    }
  }

  Future<void> _load() async {
    try {
      final ctx = await _ds.fetchContext();
      if (!mounted) return;
      setState(() { _ctx = ctx; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _ctx;
    final sub = ctx?.subscriptionState;
    final shouldShowCard =
        !_loading &&
        ctx != null &&
        sub != null &&
        !(sub.status == 'none' &&
            !sub.promoEligible &&
            !sub.trialStartsAfterVerification);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: !shouldShowCard
          ? const SizedBox.shrink(key: ValueKey('sub-empty'))
          : GestureDetector(
              key: const ValueKey('sub-card'),
              onTap: () => context.push('/subscription-plans'),
              child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors(sub.status),
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryRed.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_statusIcon(sub.status), color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusTitle(sub),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusSubtitle(sub, ctx.pricing, ctx.subscriptionEndsAt),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                  // ── End-date chip ────────────────────────────────────
                  if (_endDateLine(sub, ctx.subscriptionEndsAt, cancelAtPeriodEnd: ctx.cancelAtPeriodEnd) != null) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendarClock,
                              color: Colors.white.withOpacity(0.9), size: 12),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _endDateLine(sub, ctx.subscriptionEndsAt, cancelAtPeriodEnd: ctx.cancelAtPeriodEnd)!,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Status badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Text(
                    _badgeLabel(sub),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(LucideIcons.chevronRight,
                    color: Colors.white.withOpacity(0.7), size: 16),
              ],
            ),
          ],
        ),
      ),
            ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Returns the text for the end-date chip, or null if not applicable.
  String? _endDateLine(SubscriptionState sub, DateTime? stripeEnd, {bool cancelAtPeriodEnd = false}) {
    if (sub.status == 'active' && stripeEnd != null) {
      if (cancelAtPeriodEnd) {
        return 'provider.subscription_card.expires'.tr(namedArgs: {'date': _fmt(stripeEnd)});
      }
      return 'provider.subscription_card.renews'.tr(namedArgs: {'date': _fmt(stripeEnd)});
    }
    if (sub.status == 'trial' && sub.trialEndsAt != null) {
      return 'provider.subscription_card.trial_ends'.tr(namedArgs: {'date': _fmt(sub.trialEndsAt!)});
    }
    return null;
  }

  List<Color> _gradientColors(String status) {
    switch (status) {
      case 'active':
        return [const Color(0xFF1B6B2F), const Color(0xFF2E8B47)];
      case 'trial':
        return [const Color(0xFF6B1A1A), AppColors.primaryRed];
      case 'lapsed':
        return [const Color(0xFF555555), const Color(0xFF777777)];
      default:
        return [const Color(0xFF4A0000), AppColors.primaryRed];
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active': return LucideIcons.checkCircle;
      case 'trial':  return LucideIcons.clock;
      case 'lapsed': return LucideIcons.alertCircle;
      default:       return LucideIcons.crown;
    }
  }

  String _statusTitle(SubscriptionState sub) {
    switch (sub.status) {
      case 'active':
        return 'provider.subscription_card.premium_active'.tr();
      case 'trial':
        if (!sub.trialActive) return 'provider.subscription_card.trial_period'.tr();
        final d = sub.trialDaysRemaining;
        return d == 1
            ? 'provider.subscription_card.free_trial_one'.tr()
            : 'provider.subscription_card.free_trial_many'.tr(namedArgs: {'days': '$d'});
      case 'lapsed':
        return 'provider.subscription_card.subscription_lapsed'.tr();
      default:
        return sub.trialStartsAfterVerification
            ? 'provider.subscription_card.trial_after_verify'.tr()
            : 'provider.subscription_card.no_subscription'.tr();
    }
  }

  String _statusSubtitle(SubscriptionState sub, SubscriptionPricing pricing, DateTime? stripeEnd) {
    switch (sub.status) {
      case 'active':
        return 'provider.subscription_card.subtitle_active'.tr();
      case 'trial':
        return 'provider.subscription_card.subtitle_trial'.tr(namedArgs: {'days': '${pricing.trialDays}'});
      case 'lapsed':
        return 'provider.subscription_card.subtitle_lapsed'.tr();
      default:
        if (sub.trialStartsAfterVerification) {
          return 'provider.subscription_card.subtitle_verify'.tr(namedArgs: {'days': '${pricing.trialDays}'});
        }
        if (sub.promoEligible) {
          return 'provider.subscription_card.subtitle_promo'.tr(namedArgs: {'days': '${pricing.trialDays}'});
        }
        return 'provider.subscription_card.subtitle_default'.tr();
    }
  }

  String _badgeLabel(SubscriptionState sub) {
    switch (sub.status) {
      case 'active':
        return 'provider.subscription_card.badge_active'.tr();
      case 'trial':
        return 'provider.subscription_card.badge_trial'.tr();
      case 'lapsed':
        return 'provider.subscription_card.badge_lapsed'.tr();
      default:
        return 'provider.subscription_card.badge_free'.tr();
    }
  }
}
