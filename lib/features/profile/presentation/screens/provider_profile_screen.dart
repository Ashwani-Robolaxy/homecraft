import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateNotifierProvider).currentUser;
    final displayName = user?.displayName ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, displayName),
            const SizedBox(height: 24),
            _buildMenuSection(context, ref),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String displayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 48, bottom: 60),
      decoration: BoxDecoration(
        color: Colors.black,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            AppColors.primaryRed.withValues(alpha: 0.3),
            Colors.black,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _MaroonWavesPainter(),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: const AssetImage('assets/images/cleaner_profile_1.png'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              displayName.isEmpty ? 'Provider' : displayName,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'provider.profile.verified'.tr(),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
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
      ),
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

class _MaroonWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryRed.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.5, size.width, size.height * 0.35);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
