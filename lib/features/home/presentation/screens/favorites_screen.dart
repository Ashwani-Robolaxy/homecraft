import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
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
              label: Text('common.retry'.tr()),
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
            Text('favorites.empty_title'.tr(),
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text(
              'favorites.empty_body'.tr(),
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
              child: Text('favorites.collections'.tr(),
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMain)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCollectionGrid(context, ref, state.collections),
            ),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionGrid(
      BuildContext context, WidgetRef ref, List<FavoriteCollection> collections) {
    return Column(
      children: collections.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _CollectionCard(
          collection: c,
          onTap: () => context.push('/favorite-collection', extra: c),
          onRename: () => _showRenameCollectionDialog(context, ref, c),
          onDelete: () => _confirmDeleteCollection(context, ref, c),
        ),
      )).toList(),
    );
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

  Future<void> _showRenameCollectionDialog(
    BuildContext context,
    WidgetRef ref,
    FavoriteCollection collection,
  ) async {
    final controller = TextEditingController(text: collection.name);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Rename collection', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black)),
        content: TextField(
          controller: controller,
          autofocus: true,
          cursorColor: AppColors.primaryRed,
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Collection name',
            hintStyle: GoogleFonts.outfit(color: Colors.black54, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(ctx).pop();
            }, 
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF8B79A1), fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(ctx).pop(controller.text.trim());
            },
            child: Text('Save', style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    // Delay disposal to allow the dialog pop animation to complete safely
    Future.delayed(const Duration(milliseconds: 400), () {
      controller.dispose();
    });
    final name = (next ?? '').trim();
    if (name.isEmpty || name == collection.name) return;
    final ok = await ref.read(favoritesProvider.notifier).renameCollection(collection.id, name);
    if (!context.mounted) return;
    if (ok) {
      AppToast.success('Collection renamed');
    } else {
      final err = ref.read(favoritesProvider.notifier).consumeError();
      AppToast.error(err ?? 'Could not rename collection.');
    }
  }

  Future<void> _confirmDeleteCollection(
    BuildContext context,
    WidgetRef ref,
    FavoriteCollection collection,
  ) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('favorites.delete_collection_title'.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black)),
        content: Text(
          'favorites.delete_collection_desc'.tr(namedArgs: {'name': collection.name}),
          style: GoogleFonts.outfit(height: 1.4, fontSize: 15, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(ctx).pop(false);
            }, 
            child: Text('common.cancel'.tr(), style: GoogleFonts.outfit(color: const Color(0xFF8B79A1), fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(ctx).pop(true);
            },
            child: Text('common.delete'.tr(), style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final ok = await ref.read(favoritesProvider.notifier).deleteCollection(collection.id);
    if (!context.mounted) return;
    if (ok) {
      AppToast.success('favorites.collection_deleted'.tr());
    } else {
      final err = ref.read(favoritesProvider.notifier).consumeError();
      AppToast.error(err ?? 'Could not delete collection.');
    }
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
            if (item.type != FavoriteType.professional || item.isPro)
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
                    item.type == FavoriteType.professional
                        ? 'Pro'
                        : item.type == FavoriteType.user
                            ? 'Client'
                            : 'Project',
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
    if (item.type == FavoriteType.professional ||
        item.type == FavoriteType.user) {
      return Image.asset(
        AppAssets.profilePlaceholder,
        fit: BoxFit.cover,
      );
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          LucideIcons.clipboardList,
          size: 40,
          color: Colors.black26,
        ),
      ),
    );
  }
}

// ── Collection card ───────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  final FavoriteCollection collection;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.layoutGrid,
                    size: 20, color: Colors.black38),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${collection.itemCount} saved',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                      value: 'delete', child: Text('favorites.delete_collection_menu'.tr())),
                ],
                icon: const Icon(
                  LucideIcons.moreHorizontal,
                  size: 18,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
