import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../features/auth/domain/models/service_area_location.dart';
import '../constants/app_colors.dart';
import '../services/app_toast.dart';
import '../services/google_places_service.dart';

/// Search + suggestions + "Add Area" (geocode fallback). Resolves coordinates client-side per Swagger.
class ServiceAreaSearchBlock extends StatefulWidget {
  const ServiceAreaSearchBlock({
    super.key,
    required this.onAreaAdded,
    this.hintText = 'Search location',
    this.addButtonLabel = 'Add Area',
  });

  final void Function(ServiceAreaLocation location) onAreaAdded;
  final String hintText;
  final String addButtonLabel;

  @override
  State<ServiceAreaSearchBlock> createState() => _ServiceAreaSearchBlockState();
}

class _ServiceAreaSearchBlockState extends State<ServiceAreaSearchBlock> {
  late final GooglePlacesService _places = GooglePlacesService(
    sessionToken: DateTime.now().millisecondsSinceEpoch.toString(),
  );
  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  Timer? _debounce;
  OverlayEntry? _overlay;
  List<PlaceAutocompleteSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _adding = false;
  bool _suppress = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_suppress) return;
    _debounce?.cancel();
    final text = _controller.text.trim();
    if (text.length < 2) {
      _clearSuggestions();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(text));
  }

  Future<void> _fetch(String input) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _places.autocomplete(input);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _suggestions = list;
      });
      if (list.isEmpty) {
        _removeOverlay();
      } else {
        _showOverlay();
      }
    } catch (_) {
      if (mounted) _clearSuggestions();
    }
  }

  void _clearSuggestions() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _suggestions = const [];
    });
    _removeOverlay();
  }

  Future<void> _selectSuggestion(PlaceAutocompleteSuggestion s) async {
    setState(() => _adding = true);
    try {
      final loc = await _places.placeDetails(s.placeId);
      if (!mounted) return;
      if (loc == null || !loc.isValidForApi) {
        AppToast.error('Could not resolve that place. Try another search.');
        return;
      }
      widget.onAreaAdded(loc);
      _suppress = true;
      _controller.clear();
      _clearSuggestions();
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) => _suppress = false);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _addFromTypedAddress() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      AppToast.info('Search or type an address, then add.');
      return;
    }
    setState(() => _adding = true);
    try {
      final loc = await _places.geocodeAddress(text);
      if (!mounted) return;
      if (loc == null || !loc.isValidForApi) {
        AppToast.error(
          'Could not find coordinates for that address. Pick a suggestion or try a fuller address.',
        );
        return;
      }
      widget.onAreaAdded(loc);
      _suppress = true;
      _controller.clear();
      _clearSuggestions();
      WidgetsBinding.instance.addPostFrameCallback((_) => _suppress = false);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _showOverlay() {
    if (_suggestions.isEmpty) {
      _removeOverlay();
      return;
    }
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildOverlay() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 300;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _clearSuggestions,
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: Material(
              elevation: 14,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              shadowColor: Colors.black12,
              child: SizedBox(
                width: width,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 44),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.09),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        title: Text(
                          s.description,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: _adding ? null : () => _selectSuggestion(s),
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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            key: _fieldKey,
            controller: _controller,
            enabled: !_adding,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.outfit(
                color: Colors.black26,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                LucideIcons.search,
                color: Colors.black26,
                size: 20,
              ),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    )
                  : const Icon(
                      LucideIcons.mapPin,
                      color: AppColors.primaryRed,
                      size: 20,
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryRed,
                  width: 1,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFFCFCFC),
            ),
          ),
        ),
      ],
    );
  }
}
