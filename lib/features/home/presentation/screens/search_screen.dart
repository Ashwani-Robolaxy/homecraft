import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../../../../core/storage/session_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/project_location_places_field.dart';
import '../../../auth/domain/models/service_area_location.dart';
import '../../../projects/domain/models/project_category.dart';
import '../../../projects/presentation/providers/project_provider.dart';
import '../../../professionals/presentation/providers/recommended_professionals_provider.dart';
import '../widgets/recommendation_card.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../../core/widgets/app_shimmer.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  bool _showOverlay = false;
  bool _loadingCategories = true;
  bool _categoriesError = false;
  List<ProjectCategory> _categories = const [];
  int? _selectedCategoryId;
  ServiceAreaLocation? _selectedLocation;
  DateTime? _selectedInterventionDate;
  final TextEditingController _locationController = TextEditingController();

  static const double _expandedBody = 300;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSavedCategory();
  }

  Future<void> _loadSavedCategory() async {
    try {
      final savedId = await SessionStorage().getPreferredHomeCategoryId();
      if (savedId != null) {
        ref.read(clientRecommendationCategoryProvider.notifier).setCategory(savedId);
      }
    } catch (_) {}
  }

  Future<void> _updateRecommendationCategoryFilter(int? categoryId) async {
    ref.read(clientRecommendationCategoryProvider.notifier).setCategory(categoryId);
    await SessionStorage().setPreferredHomeCategoryId(categoryId);
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
    final activeCategoryId = ref.watch(clientRecommendationCategoryProvider);
    final activeCategory = _categories.firstWhere(
      (c) => c.id == activeCategoryId,
      orElse: () => const ProjectCategory(id: -1, name: '', slug: ''),
    );
    final hasActiveFilter = activeCategoryId != null && activeCategory.id != -1;

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
                  _updateRecommendationCategoryFilter(null);
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
    final activeCategoryId = ref.read(clientRecommendationCategoryProvider);

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
                        _updateRecommendationCategoryFilter(null);
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
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: activeCategoryId == null ? FontWeight.bold : FontWeight.normal, color: AppColors.textMain),
                      ),
                      trailing: activeCategoryId == null ? const Icon(LucideIcons.check, color: AppColors.primaryRed, size: 20) : null,
                    ),
                    ..._categories.map((cat) {
                      final isSelected = activeCategoryId == cat.id;
                      return ListTile(
                        onTap: () {
                          _updateRecommendationCategoryFilter(cat.id);
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
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = false;
    });
    try {
      final categories = await ref.read(projectRepositoryProvider).getCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      if (!mounted) return;
      setState(() => _categoriesError = true);
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  void _applySearchFiltersAndOpenResults() {
    if (_selectedLocation == null || _selectedCategoryId == null || _selectedInterventionDate == null) {
      AppToast.info('Please select location, category, and intervention date.');
      return;
    }
    final next = ref
        .read(professionalSearchFiltersProvider)
        .copyWith(
          location: _selectedLocation?.label ?? _locationController.text.trim(),
          categoryId: _selectedCategoryId,
          query: '',
          latitude: _selectedLocation?.latitude,
          longitude: _selectedLocation?.longitude,
          interventionDate: _selectedInterventionDate,
        );
    developer.log(
      'Search click payload => '
      'location="${next.location}", '
      'categoryId=${next.categoryId}, '
      'lat=${next.latitude}, '
      'long=${next.longitude}, '
      'date=${next.interventionDate?.toIso8601String()}, '
      'limit=${next.limit}, '
      'maxDistanceKm=${next.maxDistanceKm}, '
      'availability=${next.availability.toList()}, '
      'minRating=${next.minRating}',
      name: 'SearchScreen',
    );
    ref.read(professionalSearchFiltersProvider.notifier).set(next);
    if (_showOverlay) {
      _toggleOverlay();
    }
    if (mounted) {
      context.push('/professional-results');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final expandedHeight = _expandedBody + top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(slivers: [..._recommendationSlivers(ref, context, top, expandedHeight)]),
          if (_showOverlay) _buildSearchOverlay(context),
        ],
      ),
    );
  }

  List<Widget> _recommendationSlivers(WidgetRef ref, BuildContext context, double top, double expandedHeight) {
    final recAsync = ref.watch(allProfessionalsProvider);
    return [
      SliverAppBar(
        pinned: true,
        stretch: true,
        automaticallyImplyLeading: false,
        expandedHeight: expandedHeight,
        toolbarHeight: kToolbarHeight,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        flexibleSpace: LayoutBuilder(
          builder: (context, constraints) {
            final minH = kToolbarHeight + top;
            final maxH = expandedHeight;
            final range = (maxH - minH).clamp(1.0, double.infinity);
            final t = ((constraints.maxHeight - minH) / range).clamp(0.0, 1.0);
            return _SearchHeroHeader(expandT: t, onOpenSearch: _toggleOverlay, onStartProject: () => context.push('/projects'));
          },
        ),
      ),
      // ── "Recommendations" title ───────────────────────────────────────────
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('home.recommendations'),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              _buildFilterButton(),
            ],
          ),
        ),
      ),

      // ── Cards area — shimmer while loading, real cards when ready ─────────
      ...recAsync.when(
        loading: () => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: const SliverToBoxAdapter(child: _CardsShimmer()),
          ),
        ],
        error: (err, _) => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'home.recommendations_error'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(allProfessionalsProvider),
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: Text('common.retry'.tr()),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        data: (list) => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(LucideIcons.users, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'home.no_professionals_found'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ...list.map(
                    (p) => RecommendationCard(
                      category: p.specialty,
                      location: p.location,
                      cost: p.costDisplay,
                      date: p.dateDisplay,
                      role: p.roleLabel,
                      name: p.displayName,
                      backgroundAsset: p.backgroundAssetFallback,
                      profileAsset: p.profileAssetFallback,
                      backgroundImageUrl: p.coverPhotoUrl,
                      profileImageUrl: p.profilePhotoUrl,
                      professionalId: p.id,
                      rating: p.rating,
                      onTap: () => context.push('/professional-detail', extra: p),
                    ),
                  ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    ];
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
                  padding: const EdgeInsets.fromLTRB(25, 25, 25, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location + dismiss overlay (center-aligned so X lines up with title)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              tr('search_overlay.location_label'),
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, height: 1.2, color: AppColors.textMain),
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleOverlay,
                            tooltip: 'Close',
                            padding: EdgeInsets.zero,
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            icon: const Icon(LucideIcons.x, size: 22, color: AppColors.textMain),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProjectLocationPlacesField(
                        controller: _locationController,
                        hintText: tr('search_overlay.location_hint'),
                        onLocationResolved: (loc) {
                          setState(() => _selectedLocation = loc);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Categories
                      Text(
                        tr('search_overlay.categories_label'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 122,
                        child: _loadingCategories
                            ? const _CategoryShimmer()
                            : (_categoriesError || _categories.isEmpty)
                            ? _CategoryEmptyState(onRetry: _loadCategories, isError: _categoriesError)
                            : ListView(scrollDirection: Axis.horizontal, children: _categories.map(_buildCategoryItem).toList()),
                      ),
                      const SizedBox(height: 24),

                      // Intervention Date — selectable from today to +1 month
                      Text(
                        tr('search_overlay.date_label'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 31,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final day = DateTime.now().add(Duration(days: index));
                            final locale = Localizations.localeOf(context).toLanguageTag();
                            final dayLabel = index == 0
                                ? tr('search_overlay.today_label')
                                : DateFormat('EEE', locale).format(day); // e.g. Lun, Mar in French
                            final monthLabel = DateFormat('MMM', locale).format(day); // e.g. août in French
                            final isSelected =
                                _selectedInterventionDate != null &&
                                _selectedInterventionDate!.year == day.year &&
                                _selectedInterventionDate!.month == day.month &&
                                _selectedInterventionDate!.day == day.day;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedInterventionDate = day);
                              },
                              child: Container(
                                width: 70,
                                decoration: BoxDecoration(color: isSelected ? AppColors.primaryRed : const Color(0xFFF0E6E6), borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        dayLabel,
                                        style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.primaryRed),
                                        maxLines: 1,
                                      ),
                                    ),
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.primaryRed),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        monthLabel,
                                        style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white70 : AppColors.primaryRed),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      PrimaryGradientButton(text: 'common.search', icon: LucideIcons.search, onPressed: _applySearchFiltersAndOpenResults),
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

  static const double _categoryRingSize = 76;
  static const double _categoryBorderWidth = 3;

  Widget _buildCategoryItem(ProjectCategory category) {
    final isSelected = _selectedCategoryId == category.id;
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategoryId = category.id);
        },
        borderRadius: BorderRadius.circular(_categoryRingSize / 2),
        child: Column(
          children: [
            SizedBox(
              width: _categoryRingSize,
              height: _categoryRingSize,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primaryRed.withValues(alpha: 0.14) : AppColors.primaryRed.withValues(alpha: 0.08),
                  border: Border.all(color: isSelected ? AppColors.primaryRed : Colors.transparent, width: _categoryBorderWidth),
                ),
                child: _buildCategoryVisual(category),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: _categoryRingSize + 14,
              child: Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryRed : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(ProjectCategory category) {
    final key = '${category.slug} ${category.name}'.toLowerCase();
    if (key.contains('plumb')) return LucideIcons.wrench;
    if (key.contains('paint')) return LucideIcons.palette;
    if (key.contains('tile')) return LucideIcons.layoutGrid;
    if (key.contains('kitchen')) return LucideIcons.utensilsCrossed;
    if (key.contains('pool') || key.contains('pisc')) return LucideIcons.waves;
    if (key.contains('exterior') || key.contains('architect')) return LucideIcons.home;
    if (key.contains('carpent') || key.contains('wood')) return LucideIcons.hammer;
    if (key.contains('clean')) return LucideIcons.sparkles;
    if (key.contains('electric')) return LucideIcons.zap;
    return LucideIcons.briefcase;
  }

  static const double _categoryAvatarSize = 70;

  Widget _buildCategoryVisual(ProjectCategory category) {
    final imageUrl = category.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: _categoryAvatarSize,
          height: _categoryAvatarSize,
          child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _iconFallback(category)),
        ),
      );
    }
    return _iconFallback(category);
  }

  Widget _iconFallback(ProjectCategory category) {
    return Icon(_categoryIcon(category), color: AppColors.primaryRed, size: 32);
  }
}

class _SearchHeroHeader extends StatelessWidget {
  const _SearchHeroHeader({required this.expandT, required this.onOpenSearch, required this.onStartProject});

  final double expandT;
  final VoidCallback onOpenSearch;
  final VoidCallback onStartProject;

  /// Minimum layout height so [FittedBox] can scale down when the sliver collapses
  /// without [Column] overflow. Actual height uses [LayoutBuilder] max height when larger.
  static const double _heroColumnHeight = 292;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage(AppAssets.heroFavorites), fit: BoxFit.cover),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent, Colors.black.withValues(alpha: 0.7)]),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(25, 8, 25, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layoutHeight = math.max(constraints.maxHeight, _heroColumnHeight);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: layoutHeight,
                      child: Opacity(
                        opacity: expandT.clamp(0.0, 1.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Center(
                                child: Image.asset(
                                  AppAssets.logo,
                                  height: 75,
                                  errorBuilder: (context, error, stackTrace) => const Text(
                                    'HomeCraft',
                                    style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                  child: PrimaryGradientButton(text: tr('home.start_project'), onPressed: onStartProject),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                  child: InkWell(
                                    onTap: onOpenSearch,
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      height: 55,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.search, color: Colors.white, size: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              tr('home.search_hint'),
                                              style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(LucideIcons.x, color: Colors.white, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shimmer placeholders ──────────────────────────────────────────────────────

/// Shimmer for the cards-only area (shown while professionals are loading,
/// after the title and category chips are already visible).
class _CardsShimmer extends StatelessWidget {
  const _CardsShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 160,
              decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(15)),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _CategoryShimmer extends StatelessWidget {
  const _CategoryShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [ShimmerCircle(size: 56), const SizedBox(height: 8), ShimmerBox(width: 56, height: 10, radius: 4)]),
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({required this.onRetry, required this.isError});
  final VoidCallback onRetry;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isError ? LucideIcons.wifiOff : LucideIcons.layoutGrid, color: AppColors.textSecondary.withValues(alpha: 0.4), size: 28),
          const SizedBox(height: 6),
          Text(
            isError ? 'Could not load categories' : 'No categories available',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          ),
          if (isError) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Tap to retry',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
