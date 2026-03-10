import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../widgets/recommendation_card.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  bool _showOverlay = false;

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Fixed Header Section
              _buildHeader(context),

              // Scrollable Recommendations Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('home.recommendations'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 15),
                      RecommendationCard(
                        category: 'Kitchen Renovation',
                        location: 'New York,US',
                        cost: '322€',
                        date: 'June 12, 2025',
                        role: 'Cleaner',
                        name: 'Bench Lee',
                        backgroundAsset: AppAssets.homeHeaderBg,
                        profileAsset: AppAssets.cleanerProfile1,
                      ),
                      RecommendationCard(
                        category: 'Bathroom Remodel',
                        location: 'London,UK',
                        cost: '450£',
                        date: 'July 05, 2025',
                        role: 'Plumber',
                        name: 'John Doe',
                        backgroundAsset: AppAssets.homeHeaderBg,
                        profileAsset: AppAssets.cleanerProfile1,
                      ),
                      RecommendationCard(
                        category: 'Garden Design',
                        location: 'Paris,FR',
                        cost: '210€',
                        date: 'August 20, 2025',
                        role: 'Gardener',
                        name: 'Marie Claire',
                        backgroundAsset: AppAssets.homeHeaderBg,
                        profileAsset: AppAssets.cleanerProfile1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showOverlay) _buildSearchOverlay(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        // Background Image with dark overlay
        Container(
          height: MediaQuery.of(context).size.height * 0.45,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage(AppAssets.homeHeaderBg), fit: BoxFit.cover),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent, Colors.black.withValues(alpha: 0.7)]),
            ),
          ),
        ),

        // Content
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                children: [
                  // Logo
                  Image.asset(
                    AppAssets.logoHorizontalWhite,
                    height: 55,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'HomeCraft',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  // Start a Project Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: PrimaryGradientButton(text: tr('home.start_project'), onPressed: () => context.push('/projects')),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: InkWell(
                      onTap: _toggleOverlay,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        height: 55,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.search, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              tr('home.search_hint'),
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, color: Colors.white),
                            ),
                            const Spacer(),
                            const Icon(LucideIcons.x, color: Colors.white, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Column(
          children: [
            const Spacer(flex: 3),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emplacement
                      Text(
                        tr('search_overlay.location_label'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.textMain, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.search, color: AppColors.textMain, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: tr('search_overlay.location_hint'),
                                  hintStyle: TextStyle(fontFamily: 'Outfit', color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleOverlay,
                              icon: const Icon(LucideIcons.x, color: AppColors.textMain, size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(color: Color(0xFF4A0000), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            tr('search_overlay.paris'),
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textMain),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Catégories
                      Text(
                        tr('search_overlay.categories_label'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildCategoryItem(tr('search_overlay.categories.cleaning'), AppAssets.categoryCleaning),
                            _buildCategoryItem(tr('search_overlay.categories.painters'), AppAssets.categoryPainters),
                            _buildCategoryItem(tr('search_overlay.categories.plumbing'), AppAssets.categoryPlumbing),
                            _buildCategoryItem(tr('search_overlay.categories.electrician'), AppAssets.categoryElectrician),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Date d'intervention
                      Text(
                        tr('search_overlay.date_label'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 5,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return Container(
                              width: 70,
                              decoration: BoxDecoration(color: const Color(0xFFF0E6E6), borderRadius: BorderRadius.circular(12)),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Ven',
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                                  ),
                                  Text(
                                    '30',
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                                  ),
                                  Text(
                                    'Peut',
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Slider
                      Row(
                        children: [
                          const Icon(LucideIcons.chevronLeft, color: AppColors.textMain),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(color: const Color(0xFFD9CACA), borderRadius: BorderRadius.circular(4)),
                                child: FractionallySizedBox(
                                  widthFactor: 0.4,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Icon(LucideIcons.chevronRight, color: AppColors.textMain),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String label, String imageAsset) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: () => context.push('/professional-results'),
        child: Column(
          children: [
            CircleAvatar(radius: 35, backgroundImage: AssetImage(imageAsset)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
