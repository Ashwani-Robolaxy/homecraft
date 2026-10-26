import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../features/auth/domain/models/service_area_location.dart';
import '../../features/auth/presentation/widgets/custom_text_field.dart';
import '../constants/app_colors.dart';
import '../services/app_toast.dart';
import '../services/google_places_service.dart';

/// Location field with Google Places Autocomplete + Place Details (session token).
class ProjectLocationPlacesField extends StatefulWidget {
  const ProjectLocationPlacesField({super.key, required this.controller, required this.onLocationResolved, required this.hintText, this.borderless = false});

  final TextEditingController controller;
  final ValueChanged<ServiceAreaLocation?> onLocationResolved;
  final String hintText;
  final bool borderless;

  @override
  State<ProjectLocationPlacesField> createState() => _ProjectLocationPlacesFieldState();
}

class _ProjectLocationPlacesFieldState extends State<ProjectLocationPlacesField> {
  late final GooglePlacesService _places = GooglePlacesService(sessionToken: DateTime.now().microsecondsSinceEpoch.toString());
  final _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  Timer? _debounce;
  OverlayEntry? _overlay;
  List<PlaceAutocompleteSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _resolving = false;
  bool _suppress = false;
  String? _resolvedDisplay;

  @override
  void initState() {
    super.initState();
    final initial = widget.controller.text.trim();
    if (initial.isNotEmpty) {
      _resolvedDisplay = initial;
    }
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ProjectLocationPlacesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);
    final current = widget.controller.text.trim();
    _resolvedDisplay = current.isEmpty ? null : current;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_suppress) return;
    if (mounted) setState(() {});
    final t = widget.controller.text.trim();
    if (t.isEmpty) {
      _resolvedDisplay = null;
      widget.onLocationResolved(null);
      _clearSuggestions();
      return;
    }
    if (_resolvedDisplay != null && t != _resolvedDisplay) {
      _resolvedDisplay = null;
      widget.onLocationResolved(null);
    }
    _debounce?.cancel();
    if (t.length < 2) {
      _clearSuggestions();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(t));
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

  void _clearField() {
    _debounce?.cancel();
    _suppress = true;
    widget.controller.clear();
    _resolvedDisplay = null;
    widget.onLocationResolved(null);
    _clearSuggestions();
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _suppress = false;
    });
  }

  Future<void> _selectSuggestion(PlaceAutocompleteSuggestion s) async {
    setState(() => _resolving = true);
    try {
      final loc = await _places.placeDetails(s.placeId);
      if (!mounted) return;
      if (loc == null || !loc.isValidForApi) {
        AppToast.error('Could not load that place. Try another.');
        return;
      }
      final label = (loc.label != null && loc.label!.trim().isNotEmpty) ? loc.label!.trim() : s.description;
      _suppress = true;
      _resolvedDisplay = label;
      widget.controller.text = label;
      widget.controller.selection = TextSelection.collapsed(offset: label.length);
      widget.onLocationResolved(loc);
      _clearSuggestions();
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _suppress = false;
      });
    } finally {
      if (mounted) setState(() => _resolving = false);
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
    final listMaxHeight = (12 + _suggestions.length * 52.0).clamp(72.0, 220.0);
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(behavior: HitTestBehavior.translucent, onTap: _clearSuggestions),
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
                  constraints: BoxConstraints(maxHeight: listMaxHeight),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.09), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.mapPin, size: 14, color: AppColors.primaryRed),
                        ),
                        title: Text(
                          s.description,
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: _resolving ? null : () => _selectSuggestion(s),
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
  Widget build(BuildContext context) {
    final noBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none);
    final normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.2)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
    );
    final hasText = widget.controller.text.trim().isNotEmpty;
    final busy = _loading || _resolving;
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        key: _fieldKey,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Theme(
              data: widget.borderless
                  ? Theme.of(context).copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: noBorder,
                        enabledBorder: noBorder,
                        focusedBorder: noBorder,
                        disabledBorder: noBorder,
                      ),
                    )
                  : Theme.of(context).copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: normalBorder,
                        enabledBorder: normalBorder,
                        focusedBorder: focusedBorder,
                        disabledBorder: normalBorder,
                      ),
                    ),
              child: CustomTextField(
                hintText: widget.hintText,
                controller: widget.controller,
                readOnly: _resolving,
                keyboardType: TextInputType.streetAddress,
                prefixIcon: LucideIcons.mapPin,
              ),
            ),
            if (hasText)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: _clearField,
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        LucideIcons.x,
                        size: 22,
                        color: AppColors.textSecondary,
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
