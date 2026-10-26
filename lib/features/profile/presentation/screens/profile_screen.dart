import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/widgets/logout_confirm_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/profile_hero_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ValueNotifier<double> _headerExpandT = ValueNotifier(1.0);
  final _session = SessionStorage();
  static const double _expandedBody = 248;
  int _avatarNonce = 0;
  String? _localProfilePhotoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshProfileData();
    });
  }

  Future<void> _refreshProfileData() async {
    final localPath = await _session.getLocalProfilePhotoPath();
    if (!mounted) return;
    _localProfilePhotoPath = localPath;
    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    setState(() => _avatarNonce++);
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
    // When PersonalInfoScreen signals a save, immediately reload local photo + auth.
    ref.listen<int>(profileRefreshTriggerProvider, (_, __) {
      _refreshProfileData();
    });

    final user = ref.watch(authStateNotifierProvider).currentUser;
    final displayName = user?.displayName ?? '';
    final profilePhotoUrl = user?.profilePhotoUrl;
    final avatarVersion = user?.updatedAt?.millisecondsSinceEpoch;
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
                        _toolbarAvatar(profilePhotoUrl, avatarVersion),
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
                  profilePhotoUrl: profilePhotoUrl,
                  localProfilePhotoPath: _localProfilePhotoPath,
                  avatarVersion: avatarVersion,
                  avatarNonce: _avatarNonce,
                  expandT: t,
                  emptyNameFallback: tr('home.tabs.profile'),
                  showVerificationBadge: false,
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
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }

  Widget _toolbarAvatar(String? url, int? avatarVersion) {
    if (_localProfilePhotoPath != null && _localProfilePhotoPath!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.file(
            File(_localProfilePhotoPath!),
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              AppAssets.profilePlaceholder,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    final imageUrl = _avatarUrlWithVersion(url, avatarVersion, _avatarNonce);
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        backgroundImage: const AssetImage(AppAssets.profilePlaceholder),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            AppAssets.profilePlaceholder,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  String? _avatarUrlWithVersion(String? url, int? version, int nonce) {
    final base = url?.trim();
    if (base == null || base.isEmpty) return null;
    final effectiveVersion = version ?? nonce;
    if (effectiveVersion == 0) return base;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}v=$effectiveVersion';
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildMenuCard([
          _buildMenuItem(
            icon: LucideIcons.user,
            title: 'client_profile.personal_info'.tr(),
            onTap: () => context.push('/personal-info'),
          ),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.bell, title: 'client_profile.notification'.tr(), onTap: () => context.push('/notification-preference')),
        ]),
        const SizedBox(height: 20),
        _buildMenuCard([_buildMenuItem(icon: LucideIcons.helpCircle, title: 'client_profile.contact_support'.tr(), onTap: () => context.push('/contact-support'))]),
        const SizedBox(height: 20),
        _buildMenuCard([
          _buildMenuItem(icon: LucideIcons.settings, title: 'client_profile.settings_item'.tr(), onTap: () => context.push('/settings')),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.fileText, title: 'client_profile.term_condition'.tr(), onTap: () => context.push('/terms-of-service')),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.shieldAlert, title: 'client_profile.privacy_policy'.tr(), onTap: () => context.push('/privacy-policy')),
          const Divider(height: 1),
          _buildMenuItem(icon: LucideIcons.helpCircle, title: 'client_profile.faq_about_us'.tr(), onTap: () => context.push('/about-us')),
        ]),
        const SizedBox(height: 20),
        _buildMenuCard([
          _buildMenuItem(
            icon: LucideIcons.logOut,
            title: 'client_profile.log_out'.tr(),
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
