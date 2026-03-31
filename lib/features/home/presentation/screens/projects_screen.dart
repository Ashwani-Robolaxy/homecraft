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
import 'map_screen.dart';
import 'project_details_screen.dart';
import '../../../../core/widgets/app_shimmer.dart';

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
                                data: (projects) => Text(
                                  'Projects: ${projects.length}',
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                                ),
                                loading: () => Text(
                                  'Loading projects...',
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                                ),
                                error: (_, __) => Text(
                                  'Projects: --',
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                                ),
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
                setState(() => _showFilter = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
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
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search Projects',
          hintStyle: GoogleFonts.outfit(color: Colors.black26),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
                shape: BoxShape.circle,
              ),
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
            Text('Unable to load projects.', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(professionalProjectsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (projects) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? projects
            : projects
                .where(
                  (p) =>
                      p.title.toLowerCase().contains(query) ||
                      p.location.toLowerCase().contains(query) ||
                      (p.serviceType ?? '').toLowerCase().contains(query),
                )
                .toList();
        if (query.isEmpty && projects.isEmpty) {
          return _buildEmptyState();
        }
        if (filtered.isEmpty) {
          return _buildNoSearchResultState();
        }
        return Column(
          children: [
            for (final p in filtered) ...[
              _buildProjectCard(project: p),
              const SizedBox(height: 16),
            ],
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
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
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
              label: Text('Refresh', style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
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

  Widget _buildProjectCard({
    required Project project,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProjectDetailsScreen(project: project)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    project.imageUrl ?? '',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Icon(LucideIcons.image, color: Colors.black12, size: 40),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _buildCircleIcon(LucideIcons.heart, AppColors.primaryRed),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _openChatWithClient(context, project),
                        child: _buildCircleIcon(LucideIcons.messageCircle, Colors.black87),
                      ),
                    ],
                  ),
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
                    children: [
                      Text(
                        project.serviceType?.isNotEmpty == true ? project.serviceType! : project.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        project.budget ?? 'N/A',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        project.location,
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        project.date,
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF800000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Reject',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF238E10),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Accept',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
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
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  void _openChatWithClient(BuildContext context, Project project) {
    final uid = project.clientUserId?.trim();
    if (uid == null || uid.isEmpty) {
      AppToast.info('Client information is not available for this project yet.');
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChatScreen(
          args: ProfessionalChatArgs(
            clientUserId: uid,
            clientDisplayName: project.clientDisplayName,
            projectId: project.id,
          ),
        ),
      ),
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
        child: Column(
          children: List.generate(3, (_) => _projectCardSkeleton()),
        ),
      ),
    );
  }

  Widget _projectCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
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
