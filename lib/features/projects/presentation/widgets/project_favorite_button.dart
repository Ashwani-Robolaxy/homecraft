import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../favorites/domain/favorite_item.dart';
import '../../../favorites/presentation/widgets/save_to_collection_sheet.dart';
import '../../../profile/presentation/providers/provider_favorites_provider.dart';
import '../../domain/models/project.dart';

class ProjectFavoriteButton extends ConsumerWidget {
  const ProjectFavoriteButton({
    super.key,
    required this.project,
  });

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerFavoritesProvider);
    final isFav = state.isFavorited(project.id);
    final isToggling = state.togglingIds.contains(project.id);

    return GestureDetector(
      onTap: isToggling
          ? null
          : () async {
              try {
                if (isFav) {
                  final item = state.items.firstWhere(
                    (f) => f.itemId == project.id && f.type == FavoriteType.project,
                    orElse: () => FavoriteItem(
                      favoriteId: 0,
                      type: FavoriteType.project,
                      itemId: project.id,
                      title: project.title,
                      subtitle: project.serviceType ?? '',
                    ),
                  );
                  await ref.read(providerFavoritesProvider.notifier).removeFavorite(item);
                  AppToast.success('Project removed from favorites');
                } else {
                  final nowFav = await ref.read(providerFavoritesProvider.notifier).toggleProject(
                        project.id,
                        displayName: project.title,
                        subtitle: project.serviceType,
                        imageUrl: project.imageUrl,
                      );
                  if (!context.mounted) return;
                  if (nowFav) {
                    final item = ref
                        .read(providerFavoritesProvider)
                        .items
                        .where((f) => f.itemId == project.id && f.type == FavoriteType.project)
                        .firstOrNull;
                    if (item != null) {
                      await showSaveToCollectionSheet(
                        context,
                        item: item,
                        isProfessional: true,
                      );
                    }
                  }
                }
              } catch (e) {
                AppToast.error(
                  e.toString()
                      .replaceFirst('ApiException: ', '')
                      .replaceFirst('Exception: ', ''),
                );
              }
            },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isToggling
            ? const Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryRed,
                ),
              )
            : Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? AppColors.primaryRed : Colors.black54,
                size: 20,
              ),
      ),
    );
  }
}
