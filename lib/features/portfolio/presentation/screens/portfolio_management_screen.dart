import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../data/datasources/portfolio_remote_datasource.dart';
import '../../domain/models/portfolio_item.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../providers/portfolio_provider.dart';

void _showPortfolioPhotoGallery(
  BuildContext context, {
  required List<PortfolioPhoto> photos,
  int initialIndex = 0,
}) {
  if (photos.isEmpty) return;
  final i = initialIndex.clamp(0, photos.length - 1);
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => _PortfolioPhotoGalleryPage(photos: photos, initialIndex: i),
    ),
  );
}

class _PortfolioPhotoGalleryPage extends StatefulWidget {
  const _PortfolioPhotoGalleryPage({required this.photos, required this.initialIndex});

  final List<PortfolioPhoto> photos;
  final int initialIndex;

  @override
  State<_PortfolioPhotoGalleryPage> createState() => _PortfolioPhotoGalleryPageState();
}

class _PortfolioPhotoGalleryPageState extends State<_PortfolioPhotoGalleryPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
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
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final url = widget.photos[index].url;
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          maxHeight: constraints.maxHeight,
                        ),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  color: Colors.white54,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.imageOff, color: Colors.white38, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'portfolio_mgmt.gallery_image_error'.tr(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (widget.photos.length > 1)
                    Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PortfolioManagementScreen extends ConsumerStatefulWidget {
  const PortfolioManagementScreen({super.key});

  @override
  ConsumerState<PortfolioManagementScreen> createState() => _PortfolioManagementScreenState();
}

class _PortfolioManagementScreenState extends ConsumerState<PortfolioManagementScreen> {
  bool _creating = false;
  int? _busyItemId;

  Future<void> _refresh() async {
    ref.invalidate(professionalPortfolioProvider);
    await ref.read(professionalPortfolioProvider.future);
  }

  Future<List<String>> _pickPhotoPaths({required int maxCount}) async {
    if (maxCount <= 0) return const [];
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result == null) return const [];
    final paths = result.files.map((e) => e.path).whereType<String>().where((e) => e.trim().isNotEmpty).toList();
    if (paths.isEmpty) return const [];
    if (paths.length <= maxCount) return paths;
    if (mounted) {
      AppToast.info('portfolio_mgmt.photos_truncated'.tr(namedArgs: {'max': '$maxCount'}));
    }
    return paths.sublist(0, maxCount);
  }

  Future<void> _createItem() async {
    final items = ref.read(professionalPortfolioProvider).asData?.value ?? const [];
    if (items.length >= 4) {
      _snack('portfolio_mgmt.max_items_reached'.tr());
      return;
    }

    final form = await showDialog<_PortfolioFormValue>(
      context: context,
      builder: (_) => const _PortfolioFormDialog(titleText: 'portfolio_mgmt.add_dialog_title'),
    );
    if (form == null) return;

    if (form.photoPaths.isEmpty) {
      _snack('portfolio_mgmt.select_photo_required'.tr());
      return;
    }

    setState(() => _creating = true);
    final result = await ref.read(portfolioRepositoryProvider).createItem(
          CreatePortfolioInput(
            title: form.title,
            description: form.description,
            completedPlace: form.completedPlace?.trim().isEmpty == true ? null : form.completedPlace?.trim(),
            amount: form.amount?.trim().isEmpty == true ? null : form.amount?.trim(),
            photoPaths: form.photoPaths,
          ),
        );
    if (!mounted) return;
    setState(() => _creating = false);
    if (result.errorMessage != null) {
      _snack(result.errorMessage!);
      return;
    }
    await _refresh();
    if (!mounted) return;
    _snack('portfolio_mgmt.item_added'.tr());
  }

  Future<void> _editItem(PortfolioItem item) async {
    final form = await showDialog<_PortfolioFormValue>(
      context: context,
      builder: (_) => _PortfolioFormDialog(
        titleText: 'portfolio_mgmt.edit_dialog_title',
        initial: _PortfolioFormValue(
          title: item.title,
          description: item.description,
          completedPlace: item.completedPlace ?? '',
          amount: item.amount?.toString() ?? '',
          photoPaths: const [],
        ),
        hidePhotoPicker: true,
      ),
    );
    if (form == null) return;

    setState(() => _busyItemId = item.id);
    final result = await ref.read(portfolioRepositoryProvider).updateItem(
          item.id,
          UpdatePortfolioInput(
            title: form.title,
            description: form.description,
            completedPlace: form.completedPlace,
            amount: form.amount,
          ),
        );
    if (!mounted) return;
    setState(() => _busyItemId = null);
    if (result.errorMessage != null) {
      _snack(result.errorMessage!);
      return;
    }
    await _refresh();
    if (!mounted) return;
    _snack('portfolio_mgmt.item_updated'.tr());
  }

  Future<void> _deleteItem(PortfolioItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'portfolio_mgmt.delete_confirm_title'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'portfolio_mgmt.delete_confirm_body'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  height: 1.35,
                  color: AppColors.textMain.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primaryRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text(
                        'common.cancel'.tr(),
                        style: GoogleFonts.outfit(
                          color: AppColors.primaryRed,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryGradientButton(
                      text: 'common.delete'.tr(),
                      height: 46,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    setState(() => _busyItemId = item.id);
    final result = await ref.read(portfolioRepositoryProvider).deleteItem(item.id);
    if (!mounted) return;
    setState(() => _busyItemId = null);
    if (result.errorMessage != null) {
      _snack(result.errorMessage!);
      return;
    }
    await _refresh();
  }

  Future<void> _addPhotos(PortfolioItem item) async {
    final remaining = PortfolioRemoteDatasource.maxPhotosPerItem - item.photos.length;
    if (remaining <= 0) {
      _snack('portfolio_mgmt.max_photos_reached'.tr(
          namedArgs: {'max': '${PortfolioRemoteDatasource.maxPhotosPerItem}'}));
      return;
    }
    final paths = await _pickPhotoPaths(maxCount: remaining);
    if (paths.isEmpty) return;

    setState(() => _busyItemId = item.id);
    final result = await ref.read(portfolioRepositoryProvider).addPhotos(item.id, paths);
    if (!mounted) return;
    setState(() => _busyItemId = null);
    if (result.errorMessage != null) {
      _snack(result.errorMessage!);
      return;
    }
    await _refresh();
  }

  Future<void> _deletePhoto(PortfolioItem item, PortfolioPhoto photo) async {
    setState(() => _busyItemId = item.id);
    final result = await ref.read(portfolioRepositoryProvider).deletePhoto(item.id, photo.id);
    if (!mounted) return;
    setState(() => _busyItemId = null);
    if (result.errorMessage != null) {
      _snack(result.errorMessage!);
      return;
    }
    await _refresh();
  }

  void _snack(String text) {
    AppToast.info(text);
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(professionalPortfolioProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: CommonAppBar(
        title: portfolioAsync.when(
          data: (items) => '${'portfolio_mgmt.title'.tr()} (${items.length}/4)',
          loading: () => 'portfolio_mgmt.title'.tr(),
          error: (_, __) => 'portfolio_mgmt.title'.tr(),
        ),
        showNotification: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createItem,
        backgroundColor: AppColors.primaryRed,
        icon: _creating
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(LucideIcons.plus, color: Colors.white, size: 18),
        label: Text('portfolio_mgmt.add_item'.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: portfolioAsync.when(
          loading: () => const _PortfolioShimmer(),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 140),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.alertTriangle, color: Colors.black45),
                      const SizedBox(height: 12),
                      Text(e.toString(), textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.black54)),
                      const SizedBox(height: 14),
                      PrimaryGradientButton(text: 'common.retry'.tr(), onPressed: _refresh, width: 160, height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 140),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.09),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.briefcase, color: AppColors.primaryRed),
                          ),
                          const SizedBox(height: 14),
                          Text('portfolio_mgmt.empty_title'.tr(), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            'portfolio_mgmt.empty_body'.tr(),
                            style: GoogleFonts.outfit(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _PortfolioCard(
                  item: item,
                  busy: _busyItemId == item.id,
                  onEdit: () => _editItem(item),
                  onDelete: () => _deleteItem(item),
                  onAddPhotos: () => _addPhotos(item),
                  onDeletePhoto: (photo) => _deletePhoto(item, photo),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onAddPhotos,
    required this.onDeletePhoto,
  });

  final PortfolioItem item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddPhotos;
  final void Function(PortfolioPhoto photo) onDeletePhoto;

  @override
  Widget build(BuildContext context) {
    final amountText = item.amount == null ? null : '€ ${item.amount!.toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.photos.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showPortfolioPhotoGallery(context, photos: item.photos, initialIndex: 0),
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        item.photos.first.url,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return AppShimmer(
                            child: ShimmerBox(
                              width: double.infinity,
                              height: 160,
                              radius: 10,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          height: 160,
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.imageOff, color: Colors.black38),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.maximize2, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'portfolio_mgmt.tap_fullscreen'.tr(),
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(item.title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))
              else ...[
                IconButton(onPressed: onEdit, icon: const Icon(LucideIcons.pencil, size: 18)),
                IconButton(onPressed: onDelete, icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent)),
              ],
            ],
          ),
          Text(item.description, style: GoogleFonts.outfit(color: Colors.black87, height: 1.35)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.completedPlace != null && item.completedPlace!.isNotEmpty) _pill(LucideIcons.mapPin, item.completedPlace!),
              if (amountText != null) _amountPill(amountText),
              _pill(
                LucideIcons.image,
                item.photos.length == 1
                    ? 'portfolio_mgmt.photos_count_one'.tr()
                    : 'portfolio_mgmt.photos_count_other'.tr(namedArgs: {'count': '${item.photos.length}'}),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: busy || item.photos.length >= PortfolioRemoteDatasource.maxPhotosPerItem
                    ? null
                    : onAddPhotos,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('${'portfolio_mgmt.add_photo'.tr()} (${item.photos.length}/4)'),
              ),
            ],
          ),
          if (item.photos.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final photo = item.photos[i];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showPortfolioPhotoGallery(context, photos: item.photos, initialIndex: i),
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              photo.url,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return AppShimmer(
                                  child: ShimmerBox(width: 70, height: 70, radius: 8),
                                );
                              },
                              errorBuilder: (_, __, ___) =>
                                  Container(width: 70, height: 70, color: Colors.grey.shade200),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: busy ? null : () => onDeletePhoto(photo),
                            customBorder: const CircleBorder(),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.x, color: Colors.white, size: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryRed),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _amountPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _PortfolioFormValue {
  const _PortfolioFormValue({
    required this.title,
    required this.description,
    required this.completedPlace,
    required this.amount,
    required this.photoPaths,
  });

  final String title;
  final String description;
  final String? completedPlace;
  final String? amount;
  final List<String> photoPaths;
}

class _PortfolioFormDialog extends StatefulWidget {
  const _PortfolioFormDialog({required this.titleText, this.initial, this.hidePhotoPicker = false});

  final String titleText;
  final _PortfolioFormValue? initial;
  final bool hidePhotoPicker;

  @override
  State<_PortfolioFormDialog> createState() => _PortfolioFormDialogState();
}

class _PortfolioFormDialogState extends State<_PortfolioFormDialog> {
  static const String _googlePlacesApiKey = 'AIzaSyDmS2dadlo4YW7AR4iDlKcJtNGRc-mnTSA';

  final _formKey = GlobalKey<FormState>();
  final GlobalKey _placeFieldKey = GlobalKey();
  final LayerLink _placeLayerLink = LayerLink();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _place;
  late final TextEditingController _amount;
  Timer? _placeDebounce;
  bool _loadingPlaces = false;
  bool _pickingPhotos = false;
  bool _suppressPlaceListener = false;
  List<_PlaceSuggestion> _placeSuggestions = const [];
  OverlayEntry? _placeOverlayEntry;
  final String _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  List<String> _photoPaths = const [];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _desc = TextEditingController(text: widget.initial?.description ?? '');
    _place = TextEditingController(text: widget.initial?.completedPlace ?? '');
    _amount = TextEditingController(text: widget.initial?.amount ?? '');
    _photoPaths = List<String>.from(widget.initial?.photoPaths ?? const []);
    _place.addListener(_onPlaceInputChanged);
  }

  @override
  void dispose() {
    _placeDebounce?.cancel();
    _removePlaceOverlay();
    _place.removeListener(_onPlaceInputChanged);
    _title.dispose();
    _desc.dispose();
    _place.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onPlaceInputChanged() {
    if (_suppressPlaceListener) return;
    _placeDebounce?.cancel();
    final text = _place.text.trim();
    if (text.length < 2) {
      if (_placeSuggestions.isNotEmpty || _loadingPlaces) {
        setState(() {
          _loadingPlaces = false;
          _placeSuggestions = const [];
        });
        _removePlaceOverlay();
      }
      return;
    }
    _placeDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPlaceSuggestions(text);
    });
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    setState(() => _loadingPlaces = true);
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'types': 'geocode',
          'language': 'fr',
          'components': 'country:fr',
          'sessiontoken': _sessionToken,
          'key': _googlePlacesApiKey,
        },
      );
      final response = await http.get(uri);
      if (!mounted) return;
      final map = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
      final status = (map['status'] ?? '').toString();
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        setState(() {
          _loadingPlaces = false;
          _placeSuggestions = const [];
        });
        _removePlaceOverlay();
        return;
      }
      final predictions = map['predictions'];
      if (predictions is! List) {
        setState(() {
          _loadingPlaces = false;
          _placeSuggestions = const [];
        });
        _removePlaceOverlay();
        return;
      }
      setState(() {
        _loadingPlaces = false;
        _placeSuggestions = predictions
            .whereType<Map>()
            .map((e) => _PlaceSuggestion.fromMap(Map<String, dynamic>.from(e)))
            .where((e) => e.description.isNotEmpty)
            .toList();
      });
      _showOrUpdatePlaceOverlay();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPlaces = false;
        _placeSuggestions = const [];
      });
      _removePlaceOverlay();
    }
  }

  void _showOrUpdatePlaceOverlay() {
    if (_placeSuggestions.isEmpty) {
      _removePlaceOverlay();
      return;
    }
    if (_placeOverlayEntry == null) {
      _placeOverlayEntry = OverlayEntry(builder: (_) => _buildPlaceOverlay());
      Overlay.of(context, rootOverlay: true).insert(_placeOverlayEntry!);
      return;
    }
    _placeOverlayEntry!.markNeedsBuild();
  }

  void _removePlaceOverlay() {
    _placeOverlayEntry?.remove();
    _placeOverlayEntry = null;
  }

  Widget _buildPlaceOverlay() {
    final box = _placeFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 300;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() => _placeSuggestions = const []);
              _removePlaceOverlay();
            },
          ),
          CompositedTransformFollower(
            link: _placeLayerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              child: SizedBox(
                width: width,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _placeSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _placeSuggestions[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primaryRed),
                        title: Text(
                          s.description,
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _suppressPlaceListener = true;
                          _place.text = s.description;
                          _place.selection = TextSelection.fromPosition(TextPosition(offset: _place.text.length));
                          setState(() {
                            _loadingPlaces = false;
                            _placeSuggestions = const [];
                          });
                          _removePlaceOverlay();
                          FocusScope.of(context).unfocus();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _suppressPlaceListener = false;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick() async {
    setState(() => _pickingPhotos = true);
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (!mounted) return;
    setState(() => _pickingPhotos = false);
    if (result == null) return;
    final paths = result.files.map((e) => e.path).whereType<String>().where((e) => e.trim().isNotEmpty).toList();
    if (paths.isEmpty) return;
    final cap = PortfolioRemoteDatasource.maxPhotosPerItem;
    setState(() {
      final merged = [..._photoPaths, ...paths];
      if (merged.length > cap) {
        _photoPaths = merged.sublist(0, cap);
        AppToast.info('portfolio_mgmt.photos_truncated'.tr(namedArgs: {'max': '$cap'}));
      } else {
        _photoPaths = merged;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(widget.titleText.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_title, 'portfolio_mgmt.form_title_hint'.tr(), validator: (v) => v == null || v.trim().isEmpty ? 'portfolio_mgmt.form_required'.tr() : null),
                const SizedBox(height: 10),
                _field(_desc, 'portfolio_mgmt.form_description_hint'.tr(), maxLines: 3, validator: (v) => v == null || v.trim().isEmpty ? 'portfolio_mgmt.form_required'.tr() : null),
                const SizedBox(height: 10),
                CompositedTransformTarget(
                  link: _placeLayerLink,
                  child: TextFormField(
                    key: _placeFieldKey,
                    controller: _place,
                    maxLines: 1,
                    validator: (v) => v == null || v.trim().isEmpty ? 'portfolio_mgmt.form_required'.tr() : null,
                    decoration: InputDecoration(
                      hintText: 'portfolio_mgmt.form_location_hint'.tr(),
                      suffixIcon: _loadingPlaces
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _field(
                  _amount,
                  'portfolio_mgmt.form_cost_hint'.tr(),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'portfolio_mgmt.form_required'.tr();
                    return double.tryParse(value) == null ? 'portfolio_mgmt.form_invalid_number'.tr() : null;
                  },
                ),
                if (!widget.hidePhotoPicker) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _pickingPhotos ? null : _pick,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                      ),
                      icon: _pickingPhotos
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.imagePlus, size: 16),
                      label: Text(_pickingPhotos
                          ? 'portfolio_mgmt.picking'.tr()
                          : '${'portfolio_mgmt.pick_photo'.tr()} (${_photoPaths.length}/4)'),
                    ),
                  ),
                  if (_photoPaths.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _photoPaths.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final path = _photoPaths[i];
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          File(path),
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 96,
                                            height: 96,
                                            color: Colors.grey.shade200,
                                            alignment: Alignment.center,
                                            child: const Icon(LucideIcons.imageOff, color: Colors.black45, size: 20),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _photoPaths = List<String>.from(_photoPaths)..removeAt(i);
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(LucideIcons.x, color: Colors.white, size: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => setState(() => _photoPaths = const []),
                              child: Text(
                                'portfolio_mgmt.remove_all_photos'.tr(),
                                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (!widget.hidePhotoPicker && _photoPaths.isEmpty) {
              AppToast.error('portfolio_mgmt.select_photo_required'.tr());
              return;
            }
            Navigator.pop(
              context,
              _PortfolioFormValue(
                title: _title.text.trim(),
                description: _desc.text.trim(),
                completedPlace: _place.text,
                amount: _amount.text,
                photoPaths: _photoPaths,
              ),
            );
          },
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _PortfolioShimmer extends StatelessWidget {
  const _PortfolioShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 3,
        itemBuilder: (_, __) => _ShimmerCard(),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image placeholder
          ShimmerBox(width: double.infinity, height: 160, radius: 10),
          const SizedBox(height: 10),
          // Title row with action icons
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 18, radius: 5)),
              const SizedBox(width: 40),
              ShimmerBox(width: 24, height: 24, radius: 12),
              const SizedBox(width: 8),
              ShimmerBox(width: 24, height: 24, radius: 12),
            ],
          ),
          const SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 13, radius: 4),
          const SizedBox(height: 4),
          ShimmerBox(width: 180, height: 13, radius: 4),
          const SizedBox(height: 10),
          // Pills row
          Row(
            children: [
              ShimmerBox(width: 80, height: 26, radius: 13),
              const SizedBox(width: 8),
              ShimmerBox(width: 60, height: 26, radius: 13),
              const SizedBox(width: 8),
              ShimmerBox(width: 70, height: 26, radius: 13),
            ],
          ),
          const SizedBox(height: 10),
          ShimmerBox(width: 90, height: 30, radius: 6),
          const SizedBox(height: 10),
          // Thumbnail strip
          Row(
            children: [
              ShimmerBox(width: 70, height: 70, radius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({required this.description});

  final String description;

  factory _PlaceSuggestion.fromMap(Map<String, dynamic> map) {
    return _PlaceSuggestion(description: (map['description'] ?? '').toString());
  }
}
