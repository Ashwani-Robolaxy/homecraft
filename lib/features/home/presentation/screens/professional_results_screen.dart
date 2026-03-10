import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/filter_drawer.dart';

class ProfessionalResultsScreen extends StatelessWidget {
  const ProfessionalResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const FilterDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          tr('professionals.title'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.mapPin, color: AppColors.primaryRed),
            onPressed: () {},
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(LucideIcons.sliders, color: AppColors.textMain),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF0E6E6)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Location Bar
                Container(
                  height: 55,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: tr('professionals.search_hint'),
                            hintStyle: const TextStyle(fontFamily: 'Outfit', color: Color(0xFFBDBDBD)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.search, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Results Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tr('professionals.results_summary', namedArgs: {'location': 'Paris', 'category': 'Cleaner', 'date': 'the 5th may 2025'}),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF828282)),
                      ),
                    ),
                    Text(
                      tr('professionals.found_count', namedArgs: {'count': '5'}),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildProfessionalCard('Kitchen Renovation', 'Paris, FR', '322€', 'the 5th may 2025', 'Cleaner', 'David Miller', AppAssets.homeHeaderBg, AppAssets.profCleanerMale),
                _buildProfessionalCard('Living Room Decor', 'Paris, FR', '450€', 'the 6th may 2025', 'Painter', 'Sarah Jenkins', AppAssets.textureBg, AppAssets.profPainterFemale),
                _buildProfessionalCard('Pipe Repair', 'Paris, FR', '180€', 'the 5th may 2025', 'Plumber', 'Mark Stevens', AppAssets.homeHeaderBg, AppAssets.profPlumberMale),
                _buildProfessionalCard('Office Cleaning', 'Paris, FR', '210€', 'the 7th may 2025', 'Cleaner', 'James Wilson', AppAssets.textureBg, AppAssets.profCleanerMale),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard(String category, String location, String cost, String date, String role, String name, String backgroundAsset, String profileAsset) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: RecommendationCard(category: category, location: location, cost: cost, date: date, role: role, name: name, backgroundAsset: backgroundAsset, profileAsset: profileAsset),
    );
  }
}
