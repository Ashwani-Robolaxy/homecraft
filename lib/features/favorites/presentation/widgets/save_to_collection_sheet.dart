import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../domain/favorite_collection.dart';
import '../../domain/favorite_item.dart';
import '../providers/favorites_provider.dart';
import '../../../profile/presentation/providers/provider_favorites_provider.dart';

/// Shows an Instagram-style bottom sheet to save a favorited item into a collection.
/// Call after the item is already added to favorites (so [item.favoriteId] is set).
Future<void> showSaveToCollectionSheet(
  BuildContext context, {
  required FavoriteItem item,
  bool isProfessional = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SaveToCollectionSheet(item: item, isProfessional: isProfessional),
  );
}

class _SaveToCollectionSheet extends ConsumerStatefulWidget {
  const _SaveToCollectionSheet({
    required this.item,
    this.isProfessional = false,
  });

  final FavoriteItem item;
  final bool isProfessional;

  @override
  ConsumerState<_SaveToCollectionSheet> createState() =>
      _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState
    extends ConsumerState<_SaveToCollectionSheet> {
  bool _creatingNew = false;
  final _nameController = TextEditingController();
  int? _movingToId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.isProfessional ? providerFavoritesProvider : favoritesProvider;
    final collections =
        ref.watch(provider.select((s) => s.collections));
    final loading =
        ref.watch(provider.select((s) => s.collectionsLoading));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Text(
                  'favorites.save_to_collection'.tr(),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                  style: IconButton.styleFrom(foregroundColor: Colors.black54),
                ),
              ],
            ),
          ),

          // Create new collection row
          if (_creatingNew)
            _buildCreateNewInput()
          else
            _buildCreateNewButton(),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Collections list
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: AppColors.primaryRed, strokeWidth: 2),
            )
          else if (collections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'favorites.no_collections_yet'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: Colors.black45, height: 1.5),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: collections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _CollectionTile(
                  collection: collections[i],
                  isMoving: _movingToId == collections[i].id,
                  onTap: () => _moveTo(collections[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateNewButton() {
    return InkWell(
      onTap: () => setState(() => _creatingNew = true),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primaryRed.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(LucideIcons.plus,
                  color: AppColors.primaryRed, size: 22),
            ),
            const SizedBox(width: 14),
            Text(
              'favorites.create_new_collection'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNewInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'favorites.collection_name_hint'.tr(),
                  hintStyle:
                      GoogleFonts.outfit(fontSize: 14, color: Colors.black38),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _createAndMove,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text('common.save'.tr(),
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: () => setState(() => _creatingNew = false),
            icon: const Icon(LucideIcons.x, size: 18),
            style: IconButton.styleFrom(foregroundColor: Colors.black38),
          ),
        ],
      ),
    );
  }

  Future<void> _createAndMove() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    final provider = widget.isProfessional ? providerFavoritesProvider : favoritesProvider;
    final notifier = ref.read(provider.notifier);
    final col = await notifier.createCollection(name);
    if (!mounted) return;
    final err = notifier.consumeError();
    if (err != null) {
      AppToast.error(err);
      return;
    }
    if (col != null) {
      await _moveTo(col);
    }
  }

  Future<void> _moveTo(FavoriteCollection col) async {
    if (_movingToId != null) return;
    setState(() => _movingToId = col.id);

    final provider = widget.isProfessional ? providerFavoritesProvider : favoritesProvider;
    final notifier = ref.read(provider.notifier);
    final ok = await notifier.moveToCollection(widget.item, col.id);
    if (!mounted) return;
    setState(() => _movingToId = null);

    if (ok) {
      Navigator.pop(context);
      AppToast.success('favorites.saved_to_collection'.tr(args: [col.name]));
    } else {
      final err = notifier.consumeError();
      AppToast.error(err ?? 'favorites.could_not_save'.tr());
    }
  }
}

// ── Collection tile ───────────────────────────────────────────────────────────

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.collection,
    required this.onTap,
    this.isMoving = false,
  });
  final FavoriteCollection collection;
  final VoidCallback onTap;
  final bool isMoving;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isMoving ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // Grid thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: _buildThumbnail(collection),
              ),
            ),
            const SizedBox(width: 14),
            // Name + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'favorites.items_saved'.tr(args: [collection.itemCount.toString()]),
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            if (isMoving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryRed),
              )
            else
              const Icon(LucideIcons.chevronRight,
                  size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(FavoriteCollection col) {
    final images = col.coverImages;
    if (images.length >= 4) {
      return GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        physics: const NeverScrollableScrollPhysics(),
        children: images
            .take(4)
            .map((url) => Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder()))
            .toList(),
      );
    }
    if (images.isNotEmpty) {
      return Image.network(images.first,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        child: const Icon(LucideIcons.image,
            size: 20, color: Colors.black26),
      );
}
