import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../professionals/presentation/providers/recommended_professionals_provider.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/filter_drawer.dart';

class ProfessionalResultsScreen extends ConsumerStatefulWidget {
  const ProfessionalResultsScreen({super.key});

  @override
  ConsumerState<ProfessionalResultsScreen> createState() => _ProfessionalResultsScreenState();
}

class _ProfessionalResultsScreenState extends ConsumerState<ProfessionalResultsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(professionalSearchFiltersProvider);
    _searchController = TextEditingController(text: filters.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final next = ref.read(professionalSearchFiltersProvider).copyWith(query: _searchController.text.trim());
    ref.read(professionalSearchFiltersProvider.notifier).set(next);
  }

  @override
  Widget build(BuildContext context) {
    final asyncPros = ref.watch(recommendedProfessionalsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const FilterDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          tr('professionals.title'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.mapPin, color: AppColors.primaryRed),
            onPressed: () {},
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(LucideIcons.sliders, color: AppColors.textMain),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF0E6E6)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 55,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _submitSearch(),
                          decoration: InputDecoration(
                            hintText: 'Search professionals',
                            hintStyle: const TextStyle(fontFamily: 'Outfit', color: Color(0xFFBDBDBD)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _submitSearch,
                        child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.search, color: Colors.white, size: 20),
                      ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                asyncPros.when(
                  loading: () => AppShimmer(
                    child: Row(
                      children: [
                        ShimmerBox(width: 160, height: 14, radius: 6),
                        const Spacer(),
                        ShimmerBox(width: 60, height: 14, radius: 6),
                      ],
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) {
                    if (list.isEmpty) {
                      return Text(
                        tr('professionals.found_count', namedArgs: const {'count': '0'}),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                      );
                    }
                    final loc = list.isNotEmpty ? list.first.location : '—';
                    final cat = list.isNotEmpty ? list.first.roleLabel : '—';
                    final date = list.isNotEmpty ? list.first.dateDisplay : '—';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tr('professionals.results_summary', namedArgs: {'location': loc, 'category': cat, 'date': date}),
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF828282)),
                          ),
                        ),
                        Text(
                          tr('professionals.found_count', namedArgs: {'count': '${list.length}'}),
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: asyncPros.when(
              loading: () => const _ProfessionalsLoadingShimmer(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        _friendlyErrorMessage(e),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(recommendedProfessionalsProvider),
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
                      ),
                    ],
                  ),
                ),
              ),
              data: (list) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: list.isEmpty ? 1 : list.length,
                itemBuilder: (context, index) {
                  if (list.isEmpty) {
                    final query = ref.read(professionalSearchFiltersProvider).query.trim();
                    return Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Column(
                        children: [
                          Icon(LucideIcons.searchX, size: 42, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                          const SizedBox(height: 14),
                          Text(
                            query.isEmpty ? 'No professionals found yet.' : 'No professionals found for "$query".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try changing category, distance, or availability filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }
                  final p = list[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: RecommendationCard(
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
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('availability must be')) {
      return 'Availability filter is invalid. Please open filters and select one of: today, this week, or this month.';
    }
    if (lower.contains('location permission')) {
      return 'Location permission is required to find nearby professionals.';
    }
    if (lower.contains('enable location services')) {
      return 'Please enable location services and try again.';
    }
    if (lower.contains('timed out')) {
      return 'Request timed out. Please check your internet and retry.';
    }
    if (lower.contains('socket') || lower.contains('network') || lower.contains('connection')) {
      return 'No internet connection. Please check your network and retry.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class _ProfessionalsLoadingShimmer extends StatefulWidget {
  const _ProfessionalsLoadingShimmer();

  @override
  State<_ProfessionalsLoadingShimmer> createState() => _ProfessionalsLoadingShimmerState();
}

class _ProfessionalsLoadingShimmerState extends State<_ProfessionalsLoadingShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _shimmerCard(t + (index * 0.08)),
          ),
        );
      },
    );
  }

  Widget _shimmerCard(double phase) {
    final p = phase % 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-1.0 + (2.0 * p), -0.2),
          end: Alignment(-0.2 + (2.0 * p), 0.2),
          colors: const [Color(0xFFE8E8E8), Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
          stops: const [0.1, 0.35, 0.6],
        ).createShader(rect),
        blendMode: BlendMode.srcATop,
        child: Container(
          height: 160,
          color: const Color(0xFFEDEDED),
          child: Row(
            children: [
              Expanded(flex: 2, child: Container(color: const Color(0xFFE3E3E3))),
              Expanded(child: Container(color: const Color(0xFFDCDCDC))),
            ],
          ),
        ),
      ),
    );
  }
}
