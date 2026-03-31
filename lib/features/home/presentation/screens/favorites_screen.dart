import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../favorites/domain/favorite_collection.dart';
import '../../../favorites/domain/favorite_item.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final ValueNotifier<double> _headerExpandT = ValueNotifier(1.0);
  static const double _expandedBody = 268;

  @override
  void dispose() {
    _headerExpandT.dispose();
    super.dispose();
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
    final titleText = tr('home.tabs.favorites');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            automaticallyImplyLeading: false,
            expandedHeight: expandedHeight,
            toolbarHeight: kToolbarHeight,
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: ValueListenableBuilder<double>(
              valueListenable: _headerExpandT,
              builder: (context, t, _) {
                final show = (1.0 - t).clamp(0.0, 1.0);
                return IgnorePointer(
                  ignoring: show < 0.05,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: show,
                    child: Text(
                      titleText,
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
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
                final t =
                    ((constraints.maxHeight - minH) / range).clamp(0.0, 1.0);
                _deferHeaderExpandT(t);
                return _FavoritesHeroHeader(titleText: titleText, expandT: t);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _FavoritesBody(
              onRetry: () => ref.read(favoritesProvider.notifier).load(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _FavoritesBody extends ConsumerWidget {
  const _FavoritesBody({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesProvider);

    if (state.loading) return _buildShimmer();
    if (state.error != null) return _buildError(context, state.error!);
    if (state.items.isEmpty && state.collections.isEmpty) return _buildEmpty();
    return _buildContent(context, ref, state);
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 100, height: 20, radius: 6),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ShimmerBox(
                          width: double.infinity,
                          height: 160,
                          radius: 16),
                      const SizedBox(height: 10),
                      ShimmerBox(width: 100, height: 14, radius: 6),
                      const SizedBox(height: 6),
                      ShimmerBox(width: 70, height: 12, radius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      ShimmerBox(
                          width: double.infinity,
                          height: 160,
                          radius: 16),
                      const SizedBox(height: 10),
                      ShimmerBox(width: 100, height: 14, radius: 6),
                      const SizedBox(height: 6),
                      ShimmerBox(width: 70, height: 12, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wifiOff, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 14, color: Colors.black54, height: 1.5)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.heart,
                  size: 36, color: AppColors.primaryRed),
            ),
            const SizedBox(height: 20),
            Text('No Favorites Yet',
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text(
              'Tap the ♥ on a professional or project to save it here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: Colors.black45, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, FavoritesState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Collections section ─────────────────────────────────────────
          if (state.collections.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Collections',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMain)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCollectionGrid(context, state.collections),
            ),
            const SizedBox(height: 28),
          ],

          // ── All saved items ─────────────────────────────────────────────
          if (state.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Saved (${state.items.length})',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMain)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildItemsGrid(context, ref, state.items),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionGrid(
      BuildContext context, List<FavoriteCollection> collections) {
    final List<Widget> rows = [];
    for (int i = 0; i < collections.length; i += 2) {
      final left = collections[i];
      final right = i + 1 < collections.length ? collections[i + 1] : null;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _CollectionCard(collection: left)),
          const SizedBox(width: 16),
          right != null
              ? Expanded(child: _CollectionCard(collection: right))
              : const Expanded(child: SizedBox()),
        ],
      ));
      rows.add(const SizedBox(height: 20));
    }
    return Column(children: rows);
  }

  Widget _buildItemsGrid(
      BuildContext context, WidgetRef ref, List<FavoriteItem> items) {
    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _FavCard(item: left)),
          const SizedBox(width: 16),
          right != null
              ? Expanded(child: _FavCard(item: right))
              : const Expanded(child: SizedBox()),
        ],
      ));
      rows.add(const SizedBox(height: 20));
    }
    return Column(children: rows);
  }
}

// ── Favorite Card ─────────────────────────────────────────────────────────────

class _FavCard extends ConsumerWidget {
  const _FavCard({required this.item});
  final FavoriteItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToggling = ref.watch(
      favoritesProvider.select((s) => s.togglingIds.contains(item.itemId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey.shade100),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            // Type badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.type == FavoriteType.professional ? 'Pro' : 'Project',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Remove heart button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: isToggling
                    ? null
                    : () => ref
                        .read(favoritesProvider.notifier)
                        .removeFavorite(item),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: isToggling
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primaryRed),
                        )
                      : const Icon(Icons.favorite,
                          color: AppColors.primaryRed, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.title.isNotEmpty ? item.title : '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain),
        ),
        if (item.subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          item.type == FavoriteType.professional
              ? LucideIcons.user
              : LucideIcons.clipboardList,
          size: 40,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ── Collection card ───────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});
  final FavoriteCollection collection;

  @override
  Widget build(BuildContext context) {
    final images = collection.coverImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.shade100,
            ),
            clipBehavior: Clip.antiAlias,
            child: images.length >= 4
                ? GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    children: images
                        .take(4)
                        .map((url) => Image.network(url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder()))
                        .toList(),
                  )
                : images.isNotEmpty
                    ? Image.network(images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          collection.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain),
        ),
        const SizedBox(height: 3),
        Text(
          '${collection.itemCount} saved',
          style: GoogleFonts.outfit(
              fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(LucideIcons.layoutGrid, size: 32, color: Colors.black26),
        ),
      );
}

// ── Hero header (unchanged) ───────────────────────────────────────────────────

class _FavoritesHeroHeader extends StatelessWidget {
  const _FavoritesHeroHeader(
      {required this.titleText, required this.expandT});

  final String titleText;
  final double expandT;

  @override
  Widget build(BuildContext context) {
    final scale = 0.85 + 0.15 * expandT;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/images/hero_favorites.png'),
                fit: BoxFit.cover),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Center(
            child: Opacity(
              opacity: expandT.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Text(
                  titleText,
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
