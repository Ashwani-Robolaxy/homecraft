import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
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
  final TextEditingController _locationController = TextEditingController();
  final ValueNotifier<double> _headerExpandT = ValueNotifier(1.0);

  static const double _expandedBody = 312;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _headerExpandT.dispose();
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
    final next = ref.read(professionalSearchFiltersProvider).copyWith(
          location: _locationController.text.trim(),
          categoryId: _selectedCategoryId,
          query: '',
        );
    ref.read(professionalSearchFiltersProvider.notifier).set(next);
    if (_showOverlay) {
      _toggleOverlay();
    }
    if (mounted) {
      context.push('/professional-results');
    }
  }

  void _deferHeaderExpandT(double t) {
    if ((_headerExpandT.value - t).abs() <= 0.002) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if ((_headerExpandT.value - t).abs() > 0.002) {
        _headerExpandT.value = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final expandedHeight = _expandedBody + top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              ..._recommendationSlivers(ref, context, top, expandedHeight),
            ],
          ),
          if (_showOverlay) _buildSearchOverlay(context),
        ],
      ),
    );
  }

  List<Widget> _recommendationSlivers(WidgetRef ref, BuildContext context, double top, double expandedHeight) {
    final recAsync = ref.watch(recommendedProfessionalsProvider);
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
                title: ValueListenableBuilder<double>(
                  valueListenable: _headerExpandT,
                  builder: (context, t, _) {
                    final show = (1.0 - t).clamp(0.0, 1.0);
                    return IgnorePointer(
                      ignoring: show < 0.05,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: show,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleOverlay,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        tr('home.search_hint'),
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 15,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final minH = kToolbarHeight + top;
                    final maxH = expandedHeight;
                    final range = (maxH - minH).clamp(1.0, double.infinity);
                    final t = ((constraints.maxHeight - minH) / range).clamp(0.0, 1.0);
                    _deferHeaderExpandT(t);
                    return _SearchHeroHeader(
                      expandT: t,
                      onOpenSearch: _toggleOverlay,
                      onStartProject: () => context.push('/projects'),
                    );
                  },
                ),
              ),
      ...recAsync.when(
        loading: () => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: const SliverToBoxAdapter(child: _RecommendationShimmer()),
          ),
        ],
        error: (err, _) => [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('home.recommendations'), style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                  const SizedBox(height: 24),
                  const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load recommendations.\nCheck your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(recommendedProfessionalsProvider),
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: const Text('Retry'),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  tr('home.recommendations'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 15),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Search by city or category to see professionals.',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary),
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
                                controller: _locationController,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _applySearchFiltersAndOpenResults(),
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
                              onPressed: _applySearchFiltersAndOpenResults,
                              icon: const Icon(LucideIcons.search, color: AppColors.textMain, size: 20),
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

                      // Categories
                      Text(
                        tr('search_overlay.categories_label'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: _loadingCategories
                            ? const _CategoryShimmer()
                            : (_categoriesError || _categories.isEmpty)
                                ? _CategoryEmptyState(onRetry: _loadCategories, isError: _categoriesError)
                                : ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: _categories.map(_buildCategoryItem).toList(),
                                  ),
                      ),
                      const SizedBox(height: 24),

                      // Intervention Date — real upcoming 7 days
                      Text(
                        tr('search_overlay.date_label'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 7,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final day = DateTime.now().add(Duration(days: index));
                            const dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            const monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            final isToday = index == 0;
                            return Container(
                              width: 70,
                              decoration: BoxDecoration(
                                color: isToday ? AppColors.primaryRed : const Color(0xFFF0E6E6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isToday ? 'Today' : dayAbbr[day.weekday - 1],
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: isToday ? Colors.white : AppColors.primaryRed),
                                  ),
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isToday ? Colors.white : AppColors.primaryRed),
                                  ),
                                  Text(
                                    monthAbbr[day.month - 1],
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: isToday ? Colors.white70 : AppColors.primaryRed),
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

  Widget _buildCategoryItem(ProjectCategory category) {
    final icon = _categoryIcon(category);
    final isSelected = _selectedCategoryId == category.id;
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategoryId = category.id);
          final next = ref.read(professionalSearchFiltersProvider).copyWith(
                location: _locationController.text.trim(),
                categoryId: category.id,
                query: category.name,
              );
          ref.read(professionalSearchFiltersProvider.notifier).set(next);
          context.push('/professional-results');
        },
        child: Column(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: isSelected ? AppColors.primaryRed.withValues(alpha: 0.18) : AppColors.primaryRed.withValues(alpha: 0.08),
              child: Icon(icon, color: AppColors.primaryRed, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textSecondary),
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
}

class _SearchHeroHeader extends StatelessWidget {
  const _SearchHeroHeader({
    required this.expandT,
    required this.onOpenSearch,
    required this.onStartProject,
  });

  final double expandT;
  final VoidCallback onOpenSearch;
  final VoidCallback onStartProject;

  /// Nominal height for logo + spacer + CTAs so [FittedBox] can scale down when the
  /// sliver is shorter than this (collapsing [SliverAppBar]) without [Column] overflow.
  static const double _heroColumnHeight = 292;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage(AppAssets.homeHeaderBg), fit: BoxFit.cover),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: _heroColumnHeight,
                      child: Opacity(
                        opacity: expandT.clamp(0.0, 1.0),
                        child: Column(
                          children: [
                            Image.asset(
                              AppAssets.logoHorizontalWhite,
                              height: 55,
                              errorBuilder: (context, error, stackTrace) => const Text(
                                'HomeCraft',
                                style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const Spacer(),
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
                            const SizedBox(height: 4),
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

class _RecommendationShimmer extends StatelessWidget {
  const _RecommendationShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title placeholder
          ShimmerBox(width: 160, height: 20, radius: 6),
          const SizedBox(height: 16),
          // Horizontal card list
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, __) => Container(
                width: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Second row
          ShimmerBox(width: 140, height: 18, radius: 6),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 12),
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
        itemBuilder: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShimmerCircle(size: 56),
            const SizedBox(height: 8),
            ShimmerBox(width: 56, height: 10, radius: 4),
          ],
        ),
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
          Icon(
            isError ? LucideIcons.wifiOff : LucideIcons.layoutGrid,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            size: 28,
          ),
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
