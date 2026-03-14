import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildMenuSection(context, ref),
            const SizedBox(height: 100), // Bottom padding for navigation bar
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipPath(
          clipper: HeaderClipper(),
          child: Container(
            height: 300,
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/texture_bg.jpg'), fit: BoxFit.cover),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.8), AppColors.primaryRed.withValues(alpha: 0.6)]),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const CircleAvatar(radius: 65, backgroundImage: AssetImage('assets/images/cleaner_profile_1.png')),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFF0095FF), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
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
            _buildMenuItem(icon: LucideIcons.shieldAlert, title: 'Privacy Ppolicy', onTap: () => context.push('/privacy-policy')),
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
      ),
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

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 80);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 80);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
