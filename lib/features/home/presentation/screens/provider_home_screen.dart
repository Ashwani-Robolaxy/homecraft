import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../../core/widgets/project_image_placeholder.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/domain/models/project_category.dart';
import '../../../projects/presentation/providers/project_provider.dart';
import '../../../projects/presentation/widgets/project_favorite_button.dart';
import '../../../../core/storage/session_storage.dart';

class ProviderHomeScreen extends ConsumerStatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  ConsumerState<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends ConsumerState<ProviderHomeScreen> {
  late ScrollController _mainScrollController;
  double _headerCollapse = 0.0;

  List<Project> _projects = [];
  bool _projectsLoading = true;
  String? _projectsError;

  int? _selectedCategoryId;
  List<ProjectCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _mainScrollController = ScrollController();
    _mainScrollController.addListener(() {
      const maxCollapseDistance = 180.0;
      final value = (_mainScrollController.offset / maxCollapseDistance).clamp(0.0, 1.0);
      if (value != _headerCollapse) setState(() => _headerCollapse = value);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedCategoryAndProjects());
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCategoryAndProjects() async {
    try {
      final savedId = await SessionStorage().getPreferredHomeCategoryId();
      _selectedCategoryId = savedId;
      final cats = await ref.read(projectRepositoryProvider).getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
        });
      }
    } catch (_) {}
    await _loadRecommendedProjects();
  }

  Future<void> _loadRecommendedProjects() async {
    setState(() {
      _projectsLoading = true;
      _projectsError = null;
    });
    try {
      final repo = ref.read(projectRepositoryProvider);
      final list = await repo.getProfessionalProjects(limit: 50, categoryId: _selectedCategoryId);
      if (!mounted) return;
      setState(() {
        _projects = list;
        _projectsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      setState(() {
        _projectsLoading = false;
        _projectsError = msg;
      });
    }
  }

  Future<void> _updateCategoryFilter(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    await SessionStorage().setPreferredHomeCategoryId(categoryId);
    await _loadRecommendedProjects();
  }

  Widget _buildCategoryVisual(ProjectCategory category, {double size = 20}) {
    final imageUrl = category.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(LucideIcons.layoutGrid, size: 20, color: AppColors.primaryRed),
        ),
      );
    }
    return const Icon(LucideIcons.layoutGrid, size: 20, color: AppColors.primaryRed);
  }

  Widget _buildCategoryLeading(ProjectCategory category, {double size = 36}) {
    final imageUrl = category.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(LucideIcons.layoutGrid, size: size * 0.5, color: AppColors.primaryRed),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(LucideIcons.layoutGrid, size: size * 0.5, color: AppColors.primaryRed),
    );
  }

  Widget _buildFilterButton() {
    final activeCategory = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => const ProjectCategory(id: -1, name: '', slug: ''),
    );
    final hasActiveFilter = _selectedCategoryId != null && activeCategory.id != -1;

    return InkWell(
      onTap: _showCategoryFilterPicker,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasActiveFilter ? AppColors.primaryRed.withValues(alpha: 0.1) : Colors.grey.shade100,
          border: Border.all(color: hasActiveFilter ? AppColors.primaryRed : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.slidersHorizontal, size: 14, color: hasActiveFilter ? AppColors.primaryRed : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              hasActiveFilter ? activeCategory.name : 'common.search'.tr(),
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: hasActiveFilter ? FontWeight.bold : FontWeight.normal, color: hasActiveFilter ? AppColors.primaryRed : AppColors.textMain),
            ),
            if (hasActiveFilter) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  _updateCategoryFilter(null);
                },
                child: const Icon(LucideIcons.x, size: 14, color: AppColors.primaryRed),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCategoryFilterPicker() {
    if (_categories.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                'provider.projects.filter_category'.tr(),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      onTap: () {
                        _updateCategoryFilter(null);
                        Navigator.pop(context);
                      },
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(LucideIcons.layoutGrid, size: 18, color: AppColors.primaryRed),
                      ),
                      title: Text(
                        'provider.projects.all_categories'.tr(),
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal, color: AppColors.textMain),
                      ),
                      trailing: _selectedCategoryId == null ? const Icon(LucideIcons.check, color: AppColors.primaryRed, size: 20) : null,
                    ),
                    ..._categories.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      return ListTile(
                        onTap: () {
                          _updateCategoryFilter(cat.id);
                          Navigator.pop(context);
                        },
                        leading: _buildCategoryLeading(cat),
                        title: Text(
                          cat.name,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppColors.textMain),
                        ),
                        trailing: isSelected ? const Icon(LucideIcons.check, color: AppColors.primaryRed, size: 20) : null,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _mainScrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 380,
            backgroundColor: Colors.white,
            toolbarHeight: 72,
            titleSpacing: 0,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _headerCollapse > 0.5 ? 1 : 0,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildSearchField(compact: true)),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _buildSliverHeader(context)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section header ───────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('provider.home.recommendations'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold))],
                      ),
                      _buildFilterButton(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Content ──────────────────────────────────────────
                  if (_projectsLoading)
                    _buildShimmer()
                  else if (_projectsError != null)
                    _buildError()
                  else if (_projects.isEmpty)
                    _buildEmpty()
                  else
                    ..._projects.map((p) => Padding(padding: const EdgeInsets.only(bottom: 20), child: _buildProjectCard(p))),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return AppShimmer(
      child: Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: 200, radius: 16),
                const SizedBox(height: 10),
                ShimmerBox(width: 200, height: 16, radius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: 140, height: 12, radius: 6),
                const SizedBox(height: 8),
                ShimmerBox(width: double.infinity, height: 12, radius: 6),
                const SizedBox(height: 4),
                ShimmerBox(width: double.infinity, height: 12, radius: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wifiOff, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              _projectsError ?? 'Could not load recommended projects.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadRecommendedProjects,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text('common.retry'.tr()),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.clipboardList, size: 48, color: Colors.black12),
            const SizedBox(height: 12),
            Text(
              'No recommended projects available. Check back later!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    final expandedSearchOpacity = (1 - (_headerCollapse * 1.4)).clamp(0.0, 1.0);
    final logoScale = (1 - (_headerCollapse * 0.2)).clamp(0.86, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage('assets/images/house_interior.png'), fit: BoxFit.cover),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.22)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: logoScale,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                    errorBuilder: (context, error, stackTrace) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('H/', style: GoogleFonts.playfairDisplay(fontSize: 44, color: Colors.white)),
                        Text(
                          'omeCraft',
                          style: GoogleFonts.playfairDisplay(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: expandedSearchOpacity, child: _buildSearchField(compact: false)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField({required bool compact}) {
    return PrimaryGradientButton(text: 'provider.home.search_hint', icon: LucideIcons.search, height: compact ? 42 : 55, onPressed: () => context.push('/professional-projects'));
  }

  Widget _buildProjectCard(Project p) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/project-details', extra: p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    width: double.infinity,
                    height: 190,
                    child: ProjectImagePlaceholder.hasDisplayableUrl(p.imageUrl)
                        ? Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return AppShimmer(child: const ShimmerBox(width: double.infinity, height: 190, radius: 0));
                            },
                            errorBuilder: (_, __, ___) => const ProjectImagePlaceholder(height: 190),
                          )
                        : const ProjectImagePlaceholder(height: 190),
                  ),
                ),
                Positioned(top: 12, right: 12, child: ProjectFavoriteButton(project: p)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.title.isNotEmpty ? p.title : (p.serviceType ?? '—'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.description.isEmpty ? 'No description available.' : p.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 17, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.location.isEmpty ? 'N/A' : p.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(p.date.isEmpty ? 'N/A' : p.date, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain)),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.calendar, size: 17, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(LucideIcons.wallet, size: 18, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Text('Budget (€)', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                      const Spacer(),
                      Text(
                        p.budget ?? 'N/A',
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
}
