import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';


import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../favorites/domain/favorite_collection.dart';
import '../providers/provider_favorites_provider.dart';
import '../../../../core/services/app_toast.dart';

class ProviderFavoritesScreen extends ConsumerStatefulWidget {
  const ProviderFavoritesScreen({super.key});

  @override
  ConsumerState<ProviderFavoritesScreen> createState() =>
      _ProviderFavoritesScreenState();
}

class _ProviderFavoritesScreenState extends ConsumerState<ProviderFavoritesScreen> {

  Future<void> _promptCreateList() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'provider.profile.favorites_new_list_title'.tr(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: AppColors.primaryRed,
          style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'provider.profile.favorites_new_list_hint'.tr(),
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
              Navigator.of(ctx).pop(ctrl.text.trim());
            },
            child: Text(
              'provider.profile.favorites_create'.tr(),
              style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    // Delay disposal to allow the dialog pop animation to complete safely
    Future.delayed(const Duration(milliseconds: 400), () {
      ctrl.dispose();
    });
    if (!mounted || name == null || name.isEmpty) return;
    await ref.read(providerFavoritesProvider.notifier).createCollection(name);
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerFavoritesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: 'provider.profile.professional_favorites'.tr(),
        showNotification: false,
        trailingActions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.primaryRed),
            onPressed: _promptCreateList,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(context),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.loading)
                    _buildShimmer()
                  else if (state.error != null)
                    _buildError(context, state.error!, ref)
                  else ...[
                    if (state.collections.isNotEmpty) ...[
                      Text(
                        'favorites.collections'.tr(),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: state.collections
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CollectionCard(
                                  collection: c,
                                  onTap: () => context.push(
                                    '/favorite-collection',
                                    extra: {
                                      'collection': c,
                                      'isProfessional': true,
                                    },
                                  ),
                                  onRename: () =>
                                      _showRenameCollectionDialog(context, ref, c),
                                  onDelete: () =>
                                      _confirmDeleteCollection(context, ref, c),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (state.collections.isEmpty)
                      _buildEmpty(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: Image.asset(
            'assets/images/house_interior.png',
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 220,
              color: Colors.grey[300],
              child: Icon(LucideIcons.image, size: 48, color: Colors.grey[600]),
            ),
          ),
        ),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        Text(
          'provider.profile.favorites_hero'.tr(),
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }




  Widget _buildShimmer() {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 100, height: 20, radius: 6),
          const SizedBox(height: 20),
          ShimmerBox(width: double.infinity, height: 200, radius: 16),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wifiOff, size: 40, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () =>
                ref.read(providerFavoritesProvider.notifier).load(),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: Text('common.retry'.tr()),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.heart,
                size: 30,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'provider.profile.favorites_empty_title'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'provider.profile.favorites_empty_body'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
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
    final ok = await ref.read(providerFavoritesProvider.notifier).renameCollection(collection.id, name);
    if (!context.mounted) return;
    if (ok) {
      AppToast.success('Collection renamed');
    } else {
      final err = ref.read(providerFavoritesProvider.notifier).consumeError();
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
    final ok = await ref.read(providerFavoritesProvider.notifier).deleteCollection(collection.id);
    if (!context.mounted) return;
    if (ok) {
      AppToast.success('favorites.collection_deleted'.tr());
    } else {
      final err = ref.read(providerFavoritesProvider.notifier).consumeError();
      AppToast.error(err ?? 'Could not delete collection.');
    }
  }
}

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.folder,
                color: AppColors.primaryRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'favorites.items_saved'.tr(args: ['${collection.itemCount}']),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
                  value: 'delete',
                  child: Text('favorites.delete_collection_menu'.tr()),
                ),
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
    );
  }
}
