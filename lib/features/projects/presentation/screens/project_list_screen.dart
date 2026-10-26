import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../providers/project_provider.dart';
import '../widgets/project_card.dart';

import '../../../../core/widgets/common_app_bar.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(myProjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: CommonAppBar(title: tr('projects.all_projects')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: PrimaryGradientButton(
              text: tr('projects.new_project'),
              onPressed: () async {
                final created = await context.push('/create-project');
                if (created == true) {
                  ref.invalidate(myProjectsProvider);
                }
              },
              icon: LucideIcons.plus,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: () async => ref.refresh(myProjectsProvider.future),
              child: projectsAsync.when(
                loading: _buildLoadingShimmer,
                error: (_, __) => _buildErrorState(ref),
                data: (result) {
                  final projects = result.projects;
                  if (projects.isEmpty) return _buildEmptyState();
                  final remaining = result.remainingDisplay;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (remaining != null) ...[
                        Text(
                          tr('projects.remaining_count', namedArgs: {'count': remaining}),
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        tr('projects.my_projects'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      ...projects.map(
                        (p) => ProjectCard(
                          project: p,
                          isClientOwnProject: true,
                          onEdit: () async {
                            final updated = await context.push('/create-project', extra: p);
                            if (updated == true) {
                              ref.invalidate(myProjectsProvider);
                            }
                          },
                          onDelete: () async {
                            final shouldDelete = await _showDeleteProjectConfirmDialog(context);
                            if (!shouldDelete) return;
                            final result = await ref.read(projectRepositoryProvider).deleteProject(p.id);
                            if (result.errorMessage != null) {
                              AppToast.error(result.errorMessage!);
                              return;
                            }
                            if (!context.mounted) return;
                            AppToast.success('Project deleted successfully');
                            ref.invalidate(myProjectsProvider);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: const [
        _ShimmerBox(height: 18, width: 170),
        SizedBox(height: 12),
        _ShimmerBox(height: 20, width: 120),
        SizedBox(height: 16),
        _ProjectCardShimmer(),
        SizedBox(height: 20),
        _ProjectCardShimmer(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 360,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    tr('projects.no_projects_remaining'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 360,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Unable to load projects.',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(myProjectsProvider),
                  child: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _showDeleteProjectConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete project?',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to delete this project? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Outfit', color: Colors.black54, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('settings.cancel'),
              style: const TextStyle(fontFamily: 'Outfit', color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _ProjectCardShimmer extends StatelessWidget {
  const _ProjectCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShimmerBox(height: 170, width: double.infinity, radius: 12),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(height: 22, width: 170),
                _ShimmerBox(height: 22, width: 80),
              ],
            ),
            SizedBox(height: 12),
            _ShimmerBox(height: 14, width: 220),
            SizedBox(height: 10),
            _ShimmerBox(height: 14, width: double.infinity),
            SizedBox(height: 8),
            _ShimmerBox(height: 14, width: 250),
            SizedBox(height: 14),
            _ShimmerBox(height: 28, width: 100, radius: 20),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.height,
    required this.width,
    this.radius = 8,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final x = -1.2 + (_controller.value * 2.4);
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x, -0.3),
              end: Alignment(x + 1.0, 0.3),
              colors: const [
                Color(0xFFEFEFEF),
                Color(0xFFF8F8F8),
                Color(0xFFEFEFEF),
              ],
              stops: const [0.1, 0.45, 0.9],
            ),
          ),
        );
      },
    );
  }
}
