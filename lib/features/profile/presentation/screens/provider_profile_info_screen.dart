import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProviderProfileInfoScreen extends ConsumerStatefulWidget {
  const ProviderProfileInfoScreen({super.key});

  @override
  ConsumerState<ProviderProfileInfoScreen> createState() => _ProviderProfileInfoScreenState();
}

class _ProviderProfileInfoScreenState extends ConsumerState<ProviderProfileInfoScreen> {
  int _selectedTab = 0; // 0: Personal Info, 1: Profile Info

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateNotifierProvider).currentUser;
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CommonAppBar(title: 'provider.nav.profile'.tr(), showNotification: false),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTabs(),
            const SizedBox(height: 24),
            _buildProfilePicture(),
            const SizedBox(height: 24),
            _buildDetailsCard(displayName: displayName, email: email),
            const SizedBox(height: 32),
            _buildEditProfileButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppColors.primaryRed : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'provider.profile.personal_info'.tr(),
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: _selectedTab == 0 ? Colors.white : AppColors.primaryRed),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppColors.primaryRed : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'provider.profile.profile_info'.tr(),
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: _selectedTab == 1 ? Colors.white : AppColors.primaryRed),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryRed, width: 2),
      ),
      child: CircleAvatar(radius: 56, backgroundColor: Colors.grey[300], backgroundImage: const AssetImage('assets/images/cleaner_profile_1.png')),
    );
  }

  Widget _buildDetailsCard({required String displayName, required String email}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.user, size: 18, color: AppColors.primaryRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Name: ${displayName.isEmpty ? '—' : displayName}', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textMain)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(LucideIcons.mail, size: 18, color: AppColors.primaryRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Email: ${email.isEmpty ? '—' : email}', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textMain)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.push('/edit-personal-info'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
          ),
          child: Text('provider.profile.edit_profile'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
