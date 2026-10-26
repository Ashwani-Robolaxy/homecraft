import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/category_localizer.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../favorites/presentation/widgets/save_to_collection_sheet.dart';

class RecommendationCard extends ConsumerWidget {
  static const List<Shadow> _textShadows = [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Color(0xCC000000))];

  final String category;
  final String location;
  final String cost;
  final String date;
  final String role;
  final String name;
  final String backgroundAsset;
  final String profileAsset;
  final String? backgroundImageUrl;
  final String? profileImageUrl;
  final VoidCallback? onTap;

  /// When set, the heart icon becomes functional and toggles this professional as a favourite.
  final String? professionalId;
  final double? rating;

  const RecommendationCard({
    super.key,
    required this.category,
    required this.location,
    required this.cost,
    required this.date,
    required this.role,
    required this.name,
    required this.backgroundAsset,
    required this.profileAsset,
    this.backgroundImageUrl,
    this.profileImageUrl,
    this.onTap,
    this.professionalId,
    this.rating,
  });

  static Widget _coverImage({required String? networkUrl, required String assetPath, required BoxFit fit}) {
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          assetPath,
          fit: fit,
          errorBuilder: (context, _, __) => Container(
            color: Colors.grey[300],
            child: Center(child: Icon(LucideIcons.image, color: Colors.white.withValues(alpha: 0.3), size: 32)),
          ),
        ),
      );
    }
    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: Center(child: Icon(LucideIcons.image, color: Colors.white.withValues(alpha: 0.3), size: 32)),
      ),
    );
  }

  static Widget _profileSideImage({required String? networkUrl, required String assetPath, required BoxFit fit}) {
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          AppAssets.profilePlaceholder,
          fit: fit,
          errorBuilder: (context, _, __) => Container(color: Colors.grey[300]),
        ),
      );
    }
    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        AppAssets.profilePlaceholder,
        fit: fit,
        errorBuilder: (context, _, __) => Container(color: Colors.grey[300]),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pid = professionalId;
    final isFav = pid != null ? ref.watch(favoritesProvider.select((s) => s.isFavorited(pid))) : false;
    final isToggling = pid != null ? ref.watch(favoritesProvider.select((s) => s.togglingIds.contains(pid))) : false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _coverImage(networkUrl: backgroundImageUrl, assetPath: backgroundAsset, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CategoryLocalizer.localize(category, context),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, shadows: _textShadows),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500, shadows: _textShadows),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${tr('home.cost_prefix')} $cost',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, shadows: _textShadows),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${tr('home.name_prefix')} $name',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: _textShadows),
                                overflow: TextOverflow.ellipsis,
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
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _profileSideImage(networkUrl: profileImageUrl, assetPath: profileAsset, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                role,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, shadows: _textShadows),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // ── Heart / favourite button ───────────────────
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: pid == null || isToggling
                                  ? null
                                  : () async {
                                      final notifier = ref.read(favoritesProvider.notifier);
                                      final wasFav = ref.read(favoritesProvider).isFavorited(pid);
                                      final nowFav = await notifier.toggleProfessional(pid, displayName: name, subtitle: category, imageUrl: profileImageUrl);
                                      if (!context.mounted) return;
                                      final err = notifier.consumeError();
                                      if (err != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                      } else if (!wasFav && nowFav) {
                                        final item = ref.read(favoritesProvider).items.where((f) => f.itemId == pid).firstOrNull;
                                        if (item != null && context.mounted) {
                                          await showSaveToCollectionSheet(context, item: item);
                                        }
                                      }
                                    },
                              child: isToggling
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? AppColors.primaryRed : Colors.white, size: 20),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (rating != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                rating!.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: _textShadows),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          '${tr('home.date_prefix')} $date',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, shadows: _textShadows),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
