import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/services/google_places_service.dart';
import '../../../../features/auth/domain/models/service_area_location.dart';
import '../../../projects/domain/models/project_category.dart';
import '../../../projects/presentation/providers/project_provider.dart';
import '../../../professionals/presentation/providers/recommended_professionals_provider.dart';
import '../../../professionals/domain/models/professional_listing.dart';
import '../widgets/recommendation_card.dart';

class ProfessionalResultsScreen extends ConsumerStatefulWidget {
  const ProfessionalResultsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<ProfessionalResultsScreen> createState() => _ProfessionalResultsScreenState();
}

class _ProfessionalResultsScreenState extends ConsumerState<ProfessionalResultsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  
  // List Search
  late final TextEditingController _listSearchController;

  // Map state
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(48.8566, 2.3522); // Default Paris
  bool _locationLoading = true;
  
  // Map Search bar
  final _mapSearchController = TextEditingController();
  final _mapSearchFocus = FocusNode();
  List<PlaceAutocompleteSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  late final GooglePlacesService _places;

  // Custom marker
  BitmapDescriptor? _customMarker;
  late final BitmapDescriptor _fallbackMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

  List<ProjectCategory> _categories = [];
  bool _loadingCategories = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    
    final filters = ref.read(professionalSearchFiltersProvider);
    _listSearchController = TextEditingController(text: filters.query);

    _places = GooglePlacesService(sessionToken: DateTime.now().millisecondsSinceEpoch.toString());
    _determinePosition();
    _mapSearchController.addListener(_onMapSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMarkerBitmap());
    _loadCategories();
  }

  @override
  void dispose() {
    _listSearchController.dispose();
    _mapSearchController.removeListener(_onMapSearchChanged);
    _mapSearchController.dispose();
    _mapSearchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _submitListSearch() {
    final next = ref.read(professionalSearchFiltersProvider).copyWith(query: _listSearchController.text.trim());
    ref.read(professionalSearchFiltersProvider.notifier).set(next);
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _determinePosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low, timeLimit: const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
      final pros = ref.read(recommendedProfessionalsProvider).asData?.value;
      if (pros == null || pros.isEmpty) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
      }
    } catch (_) {
      // keep Paris default
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // ── Autocomplete ─────────────────────────────────────────────────────────────

  void _onMapSearchChanged() {
    final q = _mapSearchController.text.trim();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _fetchSuggestions(q);
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _loadingSuggestions = true);
    try {
      final results = await _places.autocomplete(q);
      if (mounted) setState(() => _suggestions = results);
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _selectSuggestion(PlaceAutocompleteSuggestion s) async {
    _mapSearchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _mapSearchController.text = s.description;
    });
    await _searchByLocation(s.description, placeId: s.placeId);
  }

  Future<void> _searchByLocation(String location, {String? placeId}) async {
    ServiceAreaLocation? geo;
    if (placeId != null) {
      geo = await _places.placeDetails(placeId);
    }
    geo ??= await _places.geocodeAddress(location);
    if (geo != null && mounted) {
      final target = LatLng(geo.latitude ?? 48.8566, geo.longitude ?? 2.3522);
      setState(() => _currentPosition = target);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 12));
    }

    ref.read(professionalSearchFiltersProvider.notifier).set(ref.read(professionalSearchFiltersProvider).copyWith(location: location, maxDistanceKm: 100));
    ref.invalidate(recommendedProfessionalsProvider);
  }

  void _recenterOnGps() {
    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  // ── Markers ──────────────────────────────────────────────────────────────────

  Future<void> _fitToVisibleProfessionals(List<ProfessionalListing> pros) async {
    final ctrl = _mapController;
    if (ctrl == null || pros.isEmpty) return;

    final points = <LatLng>[];
    for (final p in pros) {
      if (p.latitude != null && p.longitude != null) {
        points.add(LatLng(p.latitude!, p.longitude!));
      }
    }
    if (points.isEmpty) return;

    try {
      if (points.length == 1) {
        await ctrl.animateCamera(CameraUpdate.newLatLngZoom(points.first, 12));
        return;
      }
      var minLat = points.first.latitude;
      var maxLat = minLat;
      var minLng = points.first.longitude;
      var maxLng = minLng;
      for (final ll in points.skip(1)) {
        minLat = math.min(minLat, ll.latitude);
        maxLat = math.max(maxLat, ll.latitude);
        minLng = math.min(minLng, ll.longitude);
        maxLng = math.max(maxLng, ll.longitude);
      }
      final pad = 0.01;
      await ctrl.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat - pad, minLng - pad), northeast: LatLng(maxLat + pad, maxLng + pad)), 56));
    } catch (_) {
      await ctrl.animateCamera(CameraUpdate.newLatLngZoom(points.first, 11));
    }
  }

  Future<void> _loadMarkerBitmap() async {
    try {
      final m = await BitmapDescriptor.asset(createLocalImageConfiguration(context), AppAssets.mapProjectMarker, width: 32, bitmapScaling: MapBitmapScaling.auto);
      if (mounted) {
        setState(() => _customMarker = m);
      }
    } catch (_) {}
  }

  Set<Marker> _buildMarkers(List<ProfessionalListing> pros) {
    final markers = <Marker>{};
    for (final p in pros) {
      if (p.latitude == null || p.longitude == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.latitude!, p.longitude!),
          icon: _customMarker ?? _fallbackMarker,
          infoWindow: InfoWindow(
            title: p.displayName,
            snippet: '${p.roleLabel} · ${p.location}',
            onTap: () => context.push('/professional-detail', extra: p),
          ),
        ),
      );
    }
    return markers;
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final list = await ref.read(projectRepositoryProvider).getCategories();
      if (!mounted) return;
      setState(() {
        _categories = list;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  void _openFilters() {
    final currentFilters = ref.read(professionalSearchFiltersProvider);
    var tempCategoryId = currentFilters.categoryId;
    var tempCity = currentFilters.location;
    var r = currentFilters.maxDistanceKm;
    
    String cityQuery = '';
    List<PlaceAutocompleteSuggestion> citySuggestions = [];
    Timer? cityDebounce;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              ),
              child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.paddingOf(ctx).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: AppColors.primaryRed),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        Expanded(
                          child: Text(
                            'provider.projects.filter_title'.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'provider.projects.filter_category'.tr(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingCategories)
                      const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                    else if (_categories.isEmpty)
                      Text('No categories available', style: GoogleFonts.outfit(color: AppColors.textSecondary))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _categories.map((cat) {
                          final isSelected = tempCategoryId == cat.id;
                          return FilterChip(
                            selected: isSelected,
                            label: Text(cat.name, style: GoogleFonts.outfit(fontSize: 12)),
                            onSelected: (selected) {
                              setModal(() {
                                if (selected) {
                                  tempCategoryId = cat.id;
                                } else {
                                  tempCategoryId = null;
                                }
                              });
                            },
                            selectedColor: AppColors.primaryRed.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.primaryRed,
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'provider.projects.filter_cities'.tr(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (tempCity.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(tempCity, style: GoogleFonts.outfit(fontSize: 12)),
                            onDeleted: () {
                              setModal(() {
                                tempCity = '';
                              });
                            },
                            deleteIcon: const Icon(LucideIcons.x, size: 14),
                            backgroundColor: AppColors.primaryRed.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.2)),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'provider.projects.search_city_hint'.tr(),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) {
                        cityQuery = val.trim();
                        cityDebounce?.cancel();
                        if (cityQuery.length < 2) {
                          setModal(() {
                            citySuggestions = [];
                          });
                          return;
                        }
                        cityDebounce = Timer(const Duration(milliseconds: 350), () async {
                          try {
                            final suggestions = await _places.autocomplete(cityQuery, types: '(cities)');
                            setModal(() {
                              citySuggestions = suggestions;
                            });
                          } catch (_) {}
                        });
                      },
                    ),
                    if (citySuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: citySuggestions.length > 5 ? 5 : citySuggestions.length,
                          itemBuilder: (context, index) {
                            final s = citySuggestions[index];
                            final cityName = s.description.split(',').first.trim();
                            return ListTile(
                              dense: true,
                              leading: const Icon(LucideIcons.mapPin, size: 14, color: AppColors.primaryRed),
                              title: Text(s.description, style: GoogleFonts.outfit(fontSize: 13)),
                              onTap: () {
                                setModal(() {
                                  tempCity = cityName;
                                  citySuggestions = [];
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'provider.projects.radius_km'.tr(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: r.clamp(1, 500),
                      min: 1,
                      max: 500,
                      divisions: 499,
                      activeColor: AppColors.primaryRed,
                      label: '${r.round()} km',
                      onChanged: (v) => setModal(() => r = v),
                    ),
                    Text(
                      'provider.projects.max_radius_label'
                          .tr(namedArgs: {'km': '${r.round()}'}),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final next = currentFilters.copyWith(
                          categoryId: tempCategoryId,
                          clearCategory: tempCategoryId == null,
                          location: tempCity,
                          maxDistanceKm: r,
                        );
                        ref.read(professionalSearchFiltersProvider.notifier).set(next);
                        ref.invalidate(recommendedProfessionalsProvider);
                        Navigator.pop(ctx);
                        if (_tabController.index != 1) {
                          _tabController.animateTo(1);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'filter.see_results'.tr(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final next = currentFilters.copyWith(
                          clearCategory: true,
                          location: '',
                          maxDistanceKm: 500,
                        );
                        ref.read(professionalSearchFiltersProvider.notifier).set(next);
                        ref.invalidate(recommendedProfessionalsProvider);
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        'provider.projects.clear_filters'.tr(),
                        style: GoogleFonts.outfit(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<ProfessionalListing>>>(recommendedProfessionalsProvider, (previous, next) {
      next.whenData((list) {
        if (list.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitToVisibleProfessionals(list);
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          tr('professionals.title'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal, color: AppColors.primaryRed),
            onPressed: _openFilters,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryRed,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryRed,
          tabs: [
            Tab(text: 'provider.projects.tab_list'.tr()),
            Tab(text: 'provider.projects.tab_map'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Prevent conflict with map pan
        children: [
          _buildListTab(),
          _buildMapTab(),
        ],
      ),
    );
  }

  // ── List Tab ──────────────────────────────────────────────────────────────────
  Widget _buildListTab() {
    final asyncPros = ref.watch(recommendedProfessionalsProvider);
    
    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFF0E6E6)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 55,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _listSearchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submitListSearch(),
                        decoration: InputDecoration(
                          hintText: 'common.search_professionals'.tr(),
                          hintStyle: const TextStyle(fontFamily: 'Outfit', color: Color(0xFFBDBDBD)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _submitListSearch,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.search, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              asyncPros.when(
                loading: () => AppShimmer(
                  child: Row(
                    children: [
                      ShimmerBox(width: 160, height: 14, radius: 6),
                      const Spacer(),
                      ShimmerBox(width: 60, height: 14, radius: 6),
                    ],
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(
                      tr('professionals.found_count', namedArgs: const {'count': '0'}),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        tr('professionals.found_count', namedArgs: {'count': '${list.length}'}),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: asyncPros.when(
            loading: () => const _ProfessionalsLoadingShimmer(),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      _friendlyErrorMessage(e),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(recommendedProfessionalsProvider),
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      label: Text('common.retry'.tr()),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
                    ),
                  ],
                ),
              ),
            ),
            data: (list) => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: list.isEmpty ? 1 : list.length,
              itemBuilder: (context, index) {
                if (list.isEmpty) {
                  final query = ref.read(professionalSearchFiltersProvider).query.trim();
                  return Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: Column(
                      children: [
                        Icon(LucideIcons.searchX, size: 42, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                        const SizedBox(height: 14),
                        Text(
                          query.isEmpty ? 'No professionals found yet.' : 'No professionals found for "$query".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try changing category, distance, or availability filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                final p = list[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: RecommendationCard(
                    category: p.specialty,
                    location: p.location,
                    cost: p.costDisplay,
                    date: p.dateDisplay,
                    role: p.roleLabel,
                    name: p.displayName,
                    backgroundAsset: p.backgroundAssetFallback,
                    profileAsset: p.profileAssetFallback,
                    backgroundImageUrl: p.coverPhotoUrl,
                    profileImageUrl: p.profilePhotoUrl,
                    professionalId: p.id,
                    rating: p.rating,
                    onTap: () => context.push('/professional-detail', extra: p),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Map Tab ──────────────────────────────────────────────────────────────────
  Widget _buildMapTab() {
    final prosAsync = ref.watch(recommendedProfessionalsProvider);
    final markers = prosAsync.maybeWhen(data: _buildMarkers, orElse: () => <Marker>{});
    final bool isLoading = prosAsync.isLoading || _locationLoading;
    final bool hasError = prosAsync.hasError;
    final int totalFound = prosAsync.when(data: (l) => l.length, loading: () => 0, error: (_, __) => 0);
    final int onMap = markers.length;
    final bool searched = _mapSearchController.text.trim().isNotEmpty;
    final bool noResults = !isLoading && searched && totalFound == 0 && !hasError;

    return GestureDetector(
      onTap: () {
        _mapSearchFocus.unfocus();
        if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      },
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 12),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
            onMapCreated: (c) {
              _mapController = c;
              final pros = ref.read(recommendedProfessionalsProvider).asData?.value;
              if (pros != null && pros.isNotEmpty) {
                _fitToVisibleProfessionals(pros);
              }
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          // Header Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapSearchBar(),
                  if (!isLoading && onMap > 0) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                        ),
                        child: Text(
                          'map.professionals_found'.tr(namedArgs: {'count': '$onMap'}),
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length.clamp(0, 5),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primaryRed),
                            title: Text(s.description, style: GoogleFonts.outfit(fontSize: 13)),
                            onTap: () => _selectSuggestion(s),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (isLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)),
                      const SizedBox(width: 10),
                      Text('map.searching'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                    ],
                  ),
                ),
              ),
            ),

          if (noResults) _buildNoResultsOverlay(),

          if (hasError && !isLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: Text(
                    prosAsync.error.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', ''),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.redAccent),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 30,
            right: 16,
            child: GestureDetector(
              onTap: _recenterOnGps,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: const Icon(LucideIcons.locate, size: 20, color: AppColors.primaryRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _loadingSuggestions
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))
              : const Icon(LucideIcons.search, color: Colors.black26, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _mapSearchController,
              focusNode: _mapSearchFocus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'map.search_hint'.tr(),
                hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  setState(() => _suggestions = []);
                  _searchByLocation(v.trim());
                }
              },
            ),
          ),
          if (_mapSearchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _mapSearchController.clear();
                setState(() => _suggestions = []);
              },
              child: const Icon(LucideIcons.x, size: 16, color: Colors.black38),
            )
          else
            GestureDetector(
              onTap: () {
                final q = _mapSearchController.text.trim();
                if (q.isNotEmpty) {
                  setState(() => _suggestions = []);
                  _searchByLocation(q);
                }
              },
              child: const Icon(LucideIcons.mapPin, color: AppColors.primaryRed, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildNoResultsOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.mapPinOff, size: 32, color: Colors.black26),
              const SizedBox(height: 8),
              Text(
                'map.no_professionals'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _searchByLocation(_mapSearchController.text.trim()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'map.try_again'.tr(),
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('availability must be')) {
      return 'Availability filter is invalid. Please open filters and select one of: today, this week, or this month.';
    }
    if (lower.contains('location permission')) {
      return 'Location permission is required to find nearby professionals.';
    }
    if (lower.contains('enable location services')) {
      return 'Please enable location services and try again.';
    }
    if (lower.contains('timed out')) {
      return 'Request timed out. Please check your internet and retry.';
    }
    if (lower.contains('socket') || lower.contains('network') || lower.contains('connection')) {
      return 'No internet connection. Please check your network and retry.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class _ProfessionalsLoadingShimmer extends StatefulWidget {
  const _ProfessionalsLoadingShimmer();

  @override
  State<_ProfessionalsLoadingShimmer> createState() => _ProfessionalsLoadingShimmerState();
}

class _ProfessionalsLoadingShimmerState extends State<_ProfessionalsLoadingShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _shimmerCard(t + (index * 0.08)),
          ),
        );
      },
    );
  }

  Widget _shimmerCard(double phase) {
    final p = phase % 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-1.0 + (2.0 * p), -0.2),
          end: Alignment(-0.2 + (2.0 * p), 0.2),
          colors: const [Color(0xFFE8E8E8), Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
          stops: const [0.1, 0.35, 0.6],
        ).createShader(rect),
        blendMode: BlendMode.srcATop,
        child: Container(
          height: 160,
          color: const Color(0xFFEDEDED),
          child: Row(
            children: [
              Expanded(flex: 2, child: Container(color: const Color(0xFFE3E3E3))),
              Expanded(child: Container(color: const Color(0xFFDCDCDC))),
            ],
          ),
        ),
      ),
    );
  }
}
