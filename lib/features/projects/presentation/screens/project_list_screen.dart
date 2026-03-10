import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../domain/models/project.dart';
import '../widgets/project_card.dart';

import '../../../../core/widgets/common_app_bar.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  // Mock data for now
  final List<Project> _mockProjects = [
    Project(
      id: '1',
      title: 'Building a terrace',
      description: 'Bonjour, je suis à la recherche d\'un.e ( Insérer spécialiste) afin de ( écrivez ce dont vous avez besoin) .',
      location: 'New York, US',
      date: '05-20-2026',
      budget: '€ 1,200',
      imageUrl: AppAssets.homeHeaderBg,
      acceptedCount: 5,
    ),
    Project(
      id: '2',
      title: 'Kitchen renovation',
      description: 'Need a professional to remodel the entire kitchen area.',
      location: 'New York, US',
      date: '06-15-2026',
      budget: '€ 4,500',
      imageUrl: AppAssets.homeHeaderBg,
      acceptedCount: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    bool isEmpty = _mockProjects.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: CommonAppBar(title: tr('projects.all_projects')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: PrimaryGradientButton(text: tr('projects.new_project'), onPressed: () => context.push('/create-project'), icon: LucideIcons.plus),
          ),
          if (isEmpty)
            _buildEmptyState()
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Text(
                    tr('projects.remaining_count', namedArgs: {'count': '0'}),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('projects.my_projects'),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 16),
                  ..._mockProjects.map((p) => ProjectCard(project: p)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tr('projects.no_projects_remaining'),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textSecondary),
            ),
            Text(
              tr('projects.add_limit_info'),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
