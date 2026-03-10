import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../domain/models/project.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: CommonAppBar(title: tr('details_title')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Image
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: project.imageUrl != null && project.imageUrl!.startsWith('http')
                  ? Image.network(project.imageUrl!, height: 220, width: double.infinity, fit: BoxFit.cover)
                  : Image.asset(project.imageUrl ?? AppAssets.homeHeaderBg, height: 220, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),

            // Title and Budget
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                ),
                Text(
                  project.budget ?? 'N/A',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location and Date
            Row(
              children: [
                Text(
                  project.location,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Text(
                  project.date.replaceAll('/', '-'), // Matching design format Jun14, 2025
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              project.description,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              project.description, // Duplicated in design for scroll effect demo
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Accepted Section
            Text(
              tr('details_accepted', namedArgs: {'count': '17'}),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 16),

            // Mock Accepted Providers Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisExtent: 160, mainAxisSpacing: 16),
              itemCount: 2,
              itemBuilder: (context, index) {
                return _ProviderCard(
                  title: 'Kitchen Renovation',
                  location: 'New York, US',
                  cost: '322€',
                  date: 'June 12, 2025',
                  role: 'Cleaner',
                  name: 'Bench Lee',
                  image: AppAssets.homeHeaderBg,
                  profile: AppAssets.cleanerProfile1,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String title;
  final String location;
  final String cost;
  final String date;
  final String role;
  final String name;
  final String image;
  final String profile;

  const _ProviderCard({required this.title, required this.location, required this.cost, required this.date, required this.role, required this.name, required this.image, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/service-details'),
          child: Row(
            children: [
              // Left Side: Project Info
              Expanded(
                flex: 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.startsWith('http') ? Image.network(image, fit: BoxFit.cover) : Image.asset(image, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text(location, style: const TextStyle(color: Colors.white, fontSize: 10))],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Coût : $cost',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text('Date: $date', style: const TextStyle(color: Colors.white, fontSize: 8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Right Side: Provider Info
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    profile.startsWith('http') ? Image.network(profile, fit: BoxFit.cover) : Image.asset(profile, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            role,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const Icon(LucideIcons.heart, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Text(
                        'Name:$name',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
