import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/presentation/providers/project_provider.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import 'chat_screen.dart';
import '../widgets/project_filter_overlay.dart';
import 'project_details_screen.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/project_image_placeholder.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _showFilter = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          Consumer(
                            builder: (context, ref, _) {
                              final projectsAsync = ref.watch(professionalProjectsProvider);
                              return projectsAsync.when(
                                data: (projects) => Text('Projects: ${projects.length}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                                loading: () => Text('Loading projects...', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                                error: (_, __) => Text('Projects: --', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildProjectsList(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showFilter)
            ProjectFilterOverlay(
              onClose: () => setState(() => _showFilter = false),
              onViewMap: () {
                // TODO: Implement map view
                setState(() => _showFilter = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Projects',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          IconButton(
            icon: const Icon(LucideIcons.sliders, color: Colors.black),
            onPressed: () {
              setState(() {
                _showFilter = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'provider.projects.search_projects'.tr(),
          hintStyle: GoogleFonts.outfit(color: Colors.black26),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Container(
              decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
              child: const Icon(LucideIcons.search, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsList() {
    final projectsAsync = ref.watch(professionalProjectsProvider);
    return projectsAsync.when(
      loading: () => const _ProjectsShimmer(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Text('provider.projects.empty_list'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => ref.invalidate(professionalProjectsProvider), child: Text('common.retry'.tr())),
          ],
        ),
      ),
      data: (projects) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? projects
            : projects.where((p) => p.title.toLowerCase().contains(query) || p.location.toLowerCase().contains(query) || (p.serviceType ?? '').toLowerCase().contains(query)).toList();
        if (query.isEmpty && projects.isEmpty) {
          return _buildEmptyState();
        }
        if (filtered.isEmpty) {
          return _buildNoSearchResultState();
        }
        return Column(
          children: [
            for (final p in filtered) ...[_buildProjectCard(project: p), const SizedBox(height: 16)],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(LucideIcons.clipboardList, color: AppColors.primaryRed, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No projects available right now',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'User projects will appear here as soon as new requests are posted.',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(professionalProjectsProvider),
              icon: const Icon(LucideIcons.refreshCw, size: 16, color: AppColors.primaryRed),
              label: Text(
                'Refresh',
                style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResultState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(LucideIcons.searchX, size: 34, color: Colors.black38),
            const SizedBox(height: 10),
            Text(
              'No matching projects',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different keyword for title, location, or service type.',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard({required Project project}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectDetailsScreen(project: project)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: ProjectImagePlaceholder.hasDisplayableUrl(project.imageUrl)
                      ? Image.network(
                          project.imageUrl!,
                          height: 210,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const ProjectImagePlaceholder(height: 210),
                        )
                      : const ProjectImagePlaceholder(height: 210),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Row(children: [_buildCircleIcon(LucideIcons.trash2, AppColors.primaryRed), const SizedBox(width: 8), _buildCircleIcon(LucideIcons.pencil, Colors.black87)]),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.serviceType?.isNotEmpty == true ? project.serviceType! : project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textMain),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Interested(${project.acceptedCount.toString().padLeft(2, '0')})',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryRed),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.mapPin, size: 18, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project.location.isEmpty ? 'N/A' : project.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(project.date.isEmpty ? 'N/A' : project.date, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.calendar, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(LucideIcons.wallet, size: 20, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Text('Budget (€)', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                      const Spacer(),
                      Text(
                        project.budget ?? 'N/A',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryRed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _ProjectsShimmer extends StatelessWidget {
  const _ProjectsShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(children: List.generate(3, (_) => _projectCardSkeleton())),
      ),
    );
  }

  Widget _projectCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: double.infinity, height: 180, radius: 0),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 200, height: 16, radius: 4),
                const SizedBox(height: 10),
                ShimmerBox(width: 140, height: 12, radius: 4),
                const SizedBox(height: 10),
                ShimmerBox(width: 100, height: 12, radius: 4),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
