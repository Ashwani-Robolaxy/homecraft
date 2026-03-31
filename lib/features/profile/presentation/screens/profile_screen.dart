import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/profile_hero_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ValueNotifier<double> _headerExpandT = ValueNotifier(1.0);
  static const double _expandedBody = 248;

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
            automaticallyImplyLeading: false,
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
                            displayName.isEmpty ? tr('home.tabs.profile') : displayName,
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
                  emptyNameFallback: tr('home.tabs.profile'),
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
          _buildMenuItem(icon: LucideIcons.user, title: 'Personal Info', onTap: () => context.push('/personal-info')),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.bell, title: 'Notification', onTap: () {}),
        ]),
        const SizedBox(height: 20),
        _buildMenuCard([_buildMenuItem(icon: LucideIcons.helpCircle, title: 'Contact Support', onTap: () => context.push('/contact-support'))]),
        const SizedBox(height: 20),
        _buildMenuCard([
          _buildMenuItem(icon: LucideIcons.settings, title: 'Settings', onTap: () => context.push('/settings')),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.fileText, title: 'Term & Condition', onTap: () => context.push('/terms-of-service')),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.shieldAlert, title: 'Privacy Policy', onTap: () => context.push('/privacy-policy')),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.helpCircle, title: 'FAQ - ABOUT US', onTap: () => context.push('/about-us')),
        ]),
        const SizedBox(height: 20),
        _buildMenuCard([
          _buildMenuItem(
            icon: LucideIcons.logOut,
            title: 'Log Out',
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFDF9F9), shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.primaryRed, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
      ),
      trailing: const Icon(LucideIcons.chevronRight, size: 20, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
