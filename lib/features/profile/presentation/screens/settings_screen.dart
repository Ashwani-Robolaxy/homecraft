import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete Account',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure want to delete your Account?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primaryRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryGradientButton(
                      text: 'Delete',
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/login');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Texture
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/texture_bg.jpg'), fit: BoxFit.cover),
            ),
            child: Container(color: Colors.black.withValues(alpha: 0.8)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildSettingsItem(icon: LucideIcons.refreshCw, title: 'Change password', onTap: () => context.push('/reset-password-profile')),
                      const SizedBox(height: 16),
                      _buildThemeItem(),
                      const SizedBox(height: 16),
                      _buildSettingsItem(icon: LucideIcons.trash2, title: 'Delete account', onTap: _showDeleteAccountDialog),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          const SizedBox(width: 48), // Padding to balance back button
        ],
      ),
    );
  }

  Widget _buildSettingsItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primaryRed, size: 20),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 20, color: Colors.black),
      ),
    );
  }

  Widget _buildThemeItem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(LucideIcons.sun, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Theme',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isDarkMode = !_isDarkMode),
            child: Container(
              width: 50,
              height: 26,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xFFE0E0E0)),
              child: AnimatedStack_ThemeSwitch(isDarkMode: _isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedStack_ThemeSwitch extends StatelessWidget {
  final bool isDarkMode;
  const AnimatedStack_ThemeSwitch({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          left: isDarkMode ? 24 : 2,
          top: 2,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(isDarkMode ? LucideIcons.moon : LucideIcons.sun, size: 14, color: AppColors.primaryRed),
          ),
        ),
      ],
    );
  }
}
