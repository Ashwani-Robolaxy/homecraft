import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildHeader(), const SizedBox(height: 24), _buildSelectionTitle(), const SizedBox(height: 16), _buildFavoritesGrid(), const SizedBox(height: 32)],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage('assets/images/hero_favorites.png'), fit: BoxFit.cover),
          ),
        ),
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.3)]),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              tr('home.tabs.favorites'),
              style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Selection',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textMain),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              'Edit',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRecentlyViewedItem()),
              const SizedBox(width: 16),
              Expanded(child: _buildLoremItem()),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildJamilItem()),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewedItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Image.asset('assets/images/fav_1.png', fit: BoxFit.cover),
                Image.asset('assets/images/fav_2.png', fit: BoxFit.cover),
                Image.asset('assets/images/fav_3.png', fit: BoxFit.cover),
                Image.asset('assets/images/fav_4.png', fit: BoxFit.cover),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Recently Viewed',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
        ),
        const SizedBox(height: 4),
        Text(
          'Today',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildLoremItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(image: AssetImage('assets/images/fav_lorem.png'), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Lorem',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
        ),
        const SizedBox(height: 4),
        Text(
          '3 saved',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildJamilItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(image: AssetImage('assets/images/fav_jamil.png'), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Jamil',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
        ),
      ],
    );
  }
}
