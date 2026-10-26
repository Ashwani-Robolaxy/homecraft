import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/common_app_bar.dart';

class ServiceDetailsScreen extends StatelessWidget {
  const ServiceDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(title: tr('service_details.title')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section: Portrait with Blur Background
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(image: AssetImage(AppAssets.profilePlaceholder), fit: BoxFit.cover),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.black.withValues(alpha: 0.1)),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(AppAssets.profilePlaceholder, height: 200, width: 160, fit: BoxFit.cover),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Kitchen renovation',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(LucideIcons.heart, color: AppColors.textMain),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(LucideIcons.share2, color: AppColors.primaryRed),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Provider Info
                      Row(
                        children: [
                          const Text(
                            'David Jues',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A0000)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location
                      Row(
                        children: [
                          const Icon(LucideIcons.mapPin, color: AppColors.primaryRed, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'New York, US',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Biography Section
                      Text(
                        tr('service_details.biography'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type.',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8), height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      // Certificate Section
                      Text(
                        tr('service_details.certificate'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.fileText, color: AppColors.primaryRed, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Certificate.jpg',
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF1B2C41)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Portfolio Section
                      Text(
                        tr('service_details.portfolio'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Image.asset(AppAssets.homeHeaderBg, height: 300, width: double.infinity, fit: BoxFit.cover),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.briefcase, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Lile, Kitchen renovation, 300(€)',
                                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.calendar, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      const Text('05/20/2026', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      const Spacer(),
                                      const Icon(LucideIcons.banknote, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        tr('service_details.cost_of', namedArgs: {'price': '322€'}),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Actions
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textMain,
                      side: const BorderSide(color: Color(0xFFE8E8E8)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      tr('service_details.decline'),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF900000), Color(0xFF4A0000)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        tr('service_details.confirm_now'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
