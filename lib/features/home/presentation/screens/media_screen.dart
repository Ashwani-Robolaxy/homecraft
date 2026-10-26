import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../professionals/data/professionals_remote_datasource.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key, this.professionalId});

  /// The professional's user ID. When provided, their portfolio is fetched.
  final String? professionalId;

  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen> {
  final _proDs = ProfessionalsRemoteDatasource();

  List<String> _photoUrls = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      List<String> urls = [];
      if (widget.professionalId != null && widget.professionalId!.isNotEmpty) {
        urls = await _proDs.fetchPortfolioPhotoUrls(widget.professionalId!);
      }
      if (!mounted) return;
      setState(() {
        _photoUrls = urls;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final unread = unreadAsync.when<int>(data: (c) => c, loading: () => 0, error: (_, __) => 0);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: 'Media',
        showBackButton: true,
        showLogo: true,
        showNotification: true,
        notificationCount: unread,
        onNotificationTap: () {
          context.push('/notifications').then((_) {
            ref.invalidate(unreadNotificationCountProvider);
          });
        },
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _MediaShimmer();

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'Could not load media.\nCheck your connection and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: Text('common.retry'.tr()),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
              ),
            ],
          ),
        ),
      );
    }

    if (_photoUrls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.image, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'No media yet.\nThis professional hasn\'t added any portfolio photos.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _photoUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1),
      itemBuilder: (context, index) {
        final url = _photoUrls[index];
        return GestureDetector(
          onTap: () => _openViewer(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: url.startsWith('http')
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : AppShimmer(
                            child: ShimmerBox(width: double.infinity, height: double.infinity, radius: 12),
                          ),
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
        );
      },
    );
  }

  void _openViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewer(photoUrls: _photoUrls, initialIndex: initialIndex),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFEEEEEE),
    child: const Icon(LucideIcons.image, color: Colors.black26, size: 32),
  );
}

// ── Photo full-screen viewer ──────────────────────────────────────────────────

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photoUrls, required this.initialIndex});
  final List<String> photoUrls;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_current + 1} / ${widget.photoUrls.length}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15)),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          final url = widget.photoUrls[i];
          return InteractiveViewer(
            child: Center(
              child: url.startsWith('http')
                  ? Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(LucideIcons.image, color: Colors.white30, size: 64),
                    )
                  : const Icon(LucideIcons.image, color: Colors.white30, size: 64),
            ),
          );
        },
      ),
    );
  }
}

// ── Shimmer loading grid ───────────────────────────────────────────────────────

class _MediaShimmer extends StatelessWidget {
  const _MediaShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1),
        itemBuilder: (_, __) => ShimmerBox(width: double.infinity, height: double.infinity, radius: 12),
      ),
    );
  }
}
