import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import '../../../projects/domain/models/project.dart';
import '../../../professionals/domain/models/professional_listing.dart';
import '../../domain/favorite_collection.dart';
import '../../domain/favorite_item.dart';
import '../providers/favorites_provider.dart';
import '../../../profile/presentation/providers/provider_favorites_provider.dart';
import '../../../projects/presentation/providers/project_provider.dart';

class FavoriteCollectionDetailScreen extends ConsumerStatefulWidget {
  const FavoriteCollectionDetailScreen({
    super.key,
    required this.collection,
    this.isProfessional = false,
  });

  final FavoriteCollection collection;
  final bool isProfessional;

  @override
  ConsumerState<FavoriteCollectionDetailScreen> createState() =>
      _FavoriteCollectionDetailScreenState();
}

class _FavoriteCollectionDetailScreenState
    extends ConsumerState<FavoriteCollectionDetailScreen> {
  List<FavoriteItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = widget.isProfessional ? providerFavoritesProvider : favoritesProvider;
      var list = await ref
          .read(provider.notifier)
          .fetchItemsForList(widget.collection.id);

      // Hydrate missing project images by cross-referencing available project APIs
      if (widget.isProfessional && list.any((it) => it.type == FavoriteType.project && it.imageUrl == null)) {
        try {
          final repo = ref.read(projectRepositoryProvider);
          final discoverList = await repo.getProfessionalProjects(limit: 50);
          final interestedList = await repo.getProfessionalInterestedProjects();
          
          final imagesMap = <String, String>{};
          for (final p in discoverList) {
            if (p.imageUrl != null) imagesMap[p.id] = p.imageUrl!;
          }
          for (final p in interestedList) {
            if (p.project.imageUrl != null) imagesMap[p.project.id] = p.project.imageUrl!;
          }
          
          list = list.map((item) {
            if (item.type == FavoriteType.project && item.imageUrl == null) {
              final foundUrl = imagesMap[item.itemId];
              if (foundUrl != null) {
                return item.copyWith(imageUrl: foundUrl);
              }
            }
            return item;
          }).toList();
        } catch (_) {
          // Fail silently if hydration fails
        }
      }

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load collection.';
      });
    }
  }

  void _openItem(BuildContext context, FavoriteItem item) {
    if (item.type == FavoriteType.professional) {
      context.push(
        '/professional-detail',
        extra: ProfessionalListing(
          id: item.itemId,
          displayName: item.title,
          specialty: item.subtitle,
          roleLabel: item.subtitle,
          location: '—',
          costDisplay: '—',
          dateDisplay: '—',
          profilePhotoUrl: item.imageUrl,
          profileAssetFallback: AppAssets.profilePlaceholder,
          backgroundAssetFallback: AppAssets.homeHeaderBg,
        ),
      );
    } else if (item.type == FavoriteType.project) {
      final proj = item.rawData != null
          ? Project.fromMap(item.rawData!)
          : Project(
              id: item.itemId,
              title: item.title,
              description: '',
              location: '',
              date: '',
              serviceType: item.subtitle,
              imageUrl: item.imageUrl,
            );
      context.push(
        '/project-details',
        extra: proj,
      );
    } else if (item.type == FavoriteType.user) {
      context.push(
        '/chat',
        extra: ProfessionalChatArgs(
          clientUserId: item.itemId,
          clientDisplayName: item.title,
          isCurrentUserProfessional: false,
          professionalId: item.itemId,
          clientImageUrl: item.imageUrl,
          clientProfession: item.subtitle,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.collection.name,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(
            child: Column(
              children: [
                Text(
                  _error!,
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _load,
                  child: Text(
                    'Retry',
                    style: GoogleFonts.outfit(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Nothing saved in this collection yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: _buildGrid(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < _items.length; i += 2) {
      final left = _items[i];
      final right = i + 1 < _items.length ? _items[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _itemTile(context, left)),
            const SizedBox(width: 16),
            right != null
                ? Expanded(child: _itemTile(context, right))
                : const Expanded(child: SizedBox()),
          ],
        ),
      );
      rows.add(const SizedBox(height: 20));
    }
    return Column(children: rows);
  }

  Widget _itemTile(BuildContext context, FavoriteItem item) {
    final provider = widget.isProfessional ? providerFavoritesProvider : favoritesProvider;
    final isToggling = ref.watch(
      provider.select((s) => s.togglingIds.contains(item.itemId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.type == FavoriteType.unknown
                    ? null
                    : () => _openItem(context, item),
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey.shade100,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(item),
                          )
                        : _placeholder(item),
                  ),
                ),
              ),
            ),
            if (item.type != FavoriteType.professional || item.isPro)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.type == FavoriteType.professional
                        ? 'Pro'
                        : item.type == FavoriteType.user
                            ? 'Client'
                            : item.type == FavoriteType.project
                                ? 'Project'
                                : '—',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: isToggling
                    ? null
                    : () async {
                        final provider = widget.isProfessional ? providerFavoritesProvider : favoritesProvider;
                        await ref
                            .read(provider.notifier)
                            .removeFavorite(item);
                        if (mounted) await _load();
                      },
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
                            color: AppColors.primaryRed,
                          ),
                        )
                      : const Icon(Icons.favorite,
                          color: AppColors.primaryRed, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: item.type == FavoriteType.unknown
              ? null
              : () => _openItem(context, item),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title.isNotEmpty ? item.title : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder(FavoriteItem item) {
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
