import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    final error = await ref.read(authRepositoryProvider).deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) {
      AppToast.error(error);
      return;
    }
    context.go('/login');
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryGradientButton(
                    text: 'settings.delete'.tr(),
                    isLoading: _deleting,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _deleteAccount();
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _deleting ? null : () => Navigator.pop(dialogContext),
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
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset(AppAssets.subscriptionBackground, fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.62), Colors.black.withValues(alpha: 0.35), AppColors.primaryRed.withValues(alpha: 0.22)],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.18))),
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

  Widget _buildLanguageItem() {
    final isFrench = context.locale.languageCode == 'fr';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(LucideIcons.languages, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Text(
            'settings.language'.tr(),
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          const SizedBox(width: 12),
          const Spacer(),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'en',
                label: Text('EN', style: GoogleFonts.outfit(fontSize: 12)),
              ),
              ButtonSegment(
                value: 'fr',
                label: Text('FR', style: GoogleFonts.outfit(fontSize: 12)),
              ),
            ],
            selected: {isFrench ? 'fr' : 'en'},
            onSelectionChanged: (Set<String> selected) {
              final code = selected.first;
              if (code == (isFrench ? 'fr' : 'en')) return; // already selected
              context.setLocale(Locale(code));
              // Navigate to root so every cached screen rebuilds with the new locale
              context.go('/splash');
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
