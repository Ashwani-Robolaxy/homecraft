import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';

class ProviderFavoritesScreen extends StatelessWidget {
  const ProviderFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(title: 'provider.profile.professional_favorites'.tr(), showNotification: false),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(context),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectionRow(context),
                  const SizedBox(height: 24),
                  _buildSection('provider.profile.recently_viewed'.tr(), 'provider.profile.today'.tr(), _buildRecentlyViewedGrid(context)),
                  const SizedBox(height: 24),
                  _buildSection('Lorem', 'provider.profile.saved_count'.tr(namedArgs: {'count': '3'}), _buildPlaceholderCard(const Color(0xFFE8E4E0))),
                  const SizedBox(height: 24),
                  _buildSection('Jamil', 'provider.profile.saved_count'.tr(namedArgs: {'count': '3'}), _buildPlaceholderCard(const Color(0xFFE0D4C4))),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: Image.asset(
            'assets/images/house_interior.png',
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 220,
              color: Colors.grey[300],
              child: Icon(LucideIcons.image, size: 48, color: Colors.grey[600]),
            ),
          ),
        ),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)]),
          ),
        ),
        Text(
          'provider.profile.favorites_hero'.tr(),
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSelectionRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('provider.profile.selection'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'provider.profile.city_specialist'.tr(),
                  hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {},
              child: Text('provider.profile.edit'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, String subtitle, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain)),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildRecentlyViewedGrid(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: List.generate(4, (i) => _buildGridImage(i)),
      ),
    );
  }

  Widget _buildGridImage(int index) {
    final assets = ['assets/images/garden.png', 'assets/images/house_interior.png', 'assets/images/garden.png', 'assets/images/house_interior.png'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        assets[index % assets.length],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: Icon(LucideIcons.image, color: Colors.grey[600])),
      ),
    );
  }

  Widget _buildPlaceholderCard(Color bgColor) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(LucideIcons.heart, size: 48, color: Colors.grey[400]),
        ),
      ),
    );
  }
}
