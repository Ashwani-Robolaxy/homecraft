import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
      appBar: CommonAppBar(title: tr('details.title')),
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
            if (project.serviceType != null && project.serviceType!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  project.serviceType!,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
