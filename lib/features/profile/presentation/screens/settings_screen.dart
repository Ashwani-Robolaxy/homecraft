import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  bool _profileHideOn = true;
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
                'settings.delete_account_title'.tr(),
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
              ),
              const SizedBox(height: 16),
              Text(
                'settings.delete_account_message'.tr(),
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
                        'settings.cancel'.tr(),
                        style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryGradientButton(
                      text: 'settings.delete'.tr(),
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
                      _buildSettingsItem(icon: LucideIcons.lock, title: 'settings.change_password'.tr(), onTap: () => context.push('/reset-password-profile')),
                      const SizedBox(height: 16),
                      _buildProfileHideItem(),
                      const SizedBox(height: 16),
                      _buildModeItem(),
                      const SizedBox(height: 16),
                      _buildLanguageItem(),
                      const SizedBox(height: 16),
                      _buildSettingsItem(icon: LucideIcons.trash2, title: 'settings.delete_account'.tr(), onTap: _showDeleteAccountDialog),
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
              'settings.title'.tr(),
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

  Widget _buildProfileHideItem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(LucideIcons.eyeOff, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'settings.profile_hide'.tr(),
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
            ),
          ),
          Switch(
            value: _profileHideOn,
            onChanged: (v) => setState(() => _profileHideOn = v),
            activeColor: AppColors.primaryRed,
          ),
        ],
      ),
    );
  }

  Widget _buildModeItem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(_isDarkMode ? LucideIcons.moon : LucideIcons.sun, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'settings.mode'.tr(),
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
            ),
          ),
          Switch(
            value: _isDarkMode,
            onChanged: (v) => setState(() => _isDarkMode = v),
            activeColor: AppColors.primaryRed,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem() {
    final isFrench = context.locale.languageCode == 'fr';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(LucideIcons.languages, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'settings.language'.tr(),
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
            ),
          ),
          Text(
            isFrench ? 'settings.french'.tr() : 'settings.english'.tr(),
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'en', label: Text('EN', style: GoogleFonts.outfit(fontSize: 12))),
              ButtonSegment(value: 'fr', label: Text('FR', style: GoogleFonts.outfit(fontSize: 12))),
            ],
            selected: {isFrench ? 'fr' : 'en'},
            onSelectionChanged: (Set<String> selected) {
              final code = selected.first;
              context.setLocale(Locale(code));
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
