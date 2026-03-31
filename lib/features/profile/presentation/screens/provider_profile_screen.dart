import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/profile_hero_header.dart';

class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  ConsumerState<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends ConsumerState<ProviderProfileScreen> {
  static const double _expandedBody = 248;
  final ValueNotifier<double> _headerExpandT = ValueNotifier(1.0);

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
    final user = ref.watch(authStateNotifierProvider).currentUser;
    final displayName = user?.displayName ?? '';
    final top = MediaQuery.paddingOf(context).top;
    final expandedHeight = _expandedBody + top;

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
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: const AssetImage('assets/images/cleaner_profile_1.png'),
                        ),
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
                  expandT: t,
                  emptyNameFallback: 'Provider',
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _buildMenuSection(context, ref),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
          _buildMenuItem(context, icon: LucideIcons.briefcase, title: 'Portfolio', onTap: () => context.push('/professional-portfolio')),
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
}
