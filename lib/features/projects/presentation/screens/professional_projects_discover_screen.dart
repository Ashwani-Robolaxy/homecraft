import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/google_places_service.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/project_image_placeholder.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_category.dart';
import '../providers/project_provider.dart';
import '../widgets/project_favorite_button.dart';

/// Open projects for verified professionals: list + map (geocoded pins, radius filter).
class ProfessionalProjectsDiscoverScreen extends ConsumerStatefulWidget {
  const ProfessionalProjectsDiscoverScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<ProfessionalProjectsDiscoverScreen> createState() =>
      _ProfessionalProjectsDiscoverScreenState();
}

class _ProfessionalProjectsDiscoverScreenState
    extends ConsumerState<ProfessionalProjectsDiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Timer? _searchDebounce;

  List<Project> _projects = [];
  final Map<String, LatLng> _geoCache = {};
  bool _loading = true;
  String? _error;
  LatLng? _userLatLng;
  double _radiusKm = 50;
  double? _minBudgetEuros;
  List<ProjectCategory> _categories = [];
  bool _loadingCategories = false;
  List<int> _selectedCategoryIds = [];
  List<String> _selectedCities = [];
  bool _filtersApplied = false;
  late final GooglePlacesService _places;

  BitmapDescriptor? _customProjectMarker;
  BitmapDescriptor? _userLocationPuck;
  late final BitmapDescriptor _markerHueFallback = BitmapDescriptor.defaultMarkerWithHue(
    HSVColor.fromColor(AppColors.primaryRed).hue,
  );

  @override
  void initState() {
    super.initState();
    _places = GooglePlacesService(
      sessionToken: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
    }
    _searchController.addListener(_onSearchChanged);
    _tabController.addListener(_onTabChanged);
    _load();
    _loadUserLocation();
    _loadCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadMapBitmaps());
    });
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

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1 && _userLatLng != null) {
      _scheduleFitMapCamera();
    }
  }

  /// Blue dot + white ring (mockup-style), plus project pin asset.
  Future<void> _loadMapBitmaps() async {
    BitmapDescriptor? project;
    BitmapDescriptor? puck;
    if (_customProjectMarker == null) {
      try {
        project = await BitmapDescriptor.asset(
          createLocalImageConfiguration(context),
          AppAssets.mapProjectMarker,
          width: 32,
          bitmapScaling: MapBitmapScaling.auto,
        );
      } catch (_) {}
    }
    if (_userLocationPuck == null) {
      try {
        puck = await _createUserLocationPuck();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      if (project != null) _customProjectMarker = project;
      if (puck != null) _userLocationPuck = puck;
    });
  }

  Future<BitmapDescriptor> _createUserLocationPuck() async {
    const size = 56.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);
    canvas.drawCircle(c, 18, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      19.5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(c, 9.5, Paint()..color = const Color(0xFF1A73E8));
    canvas.drawCircle(
      c,
      9.5,
      Paint()
        ..color = const Color(0xFF8AB4F8).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final pic = recorder.endRecording();
    final image = await pic.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) {
      throw StateError('user location puck encode failed');
    }
    return BitmapDescriptor.bytes(
      bd.buffer.asUint8List(),
      width: size,
      height: size,
      bitmapScaling: MapBitmapScaling.auto,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _tabController.removeListener(_onTabChanged);
    _searchController.dispose();
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {});
      if (_tabController.index == 1 && _userLatLng != null) {
        _scheduleFitMapCamera();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _geoCache.clear();
    });
    try {
      final repo = ref.read(projectRepositoryProvider);
      final q = _searchController.text.trim();
      final list = await repo.getProfessionalProjects(
        limit: 50,
        search: q.isEmpty ? null : q,
      );
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loading = false;
      });
      unawaited(_geocodeProjects());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLatLng = LatLng(pos.latitude, pos.longitude);
      });
      _scheduleFitMapCamera();
    } catch (_) {}
  }

  Future<void> _geocodeProjects() async {
    final keys = <String>{};
    for (final p in _projects) {
      final addr = p.location.trim();
      if (addr.isEmpty) continue;
      if (p.latitude != null && p.longitude != null) {
        _geoCache[addr] = LatLng(p.latitude!, p.longitude!);
        continue;
      }
      keys.add(addr);
    }
    for (final addr in keys) {
      if (_geoCache.containsKey(addr)) continue;
      LatLng? ll;
      try {
        final g = await GooglePlacesService.geocodeWithGoogleGeocodingApi(addr);
        final glat = g?.latitude;
        final glng = g?.longitude;
        if (glat != null && glng != null) ll = LatLng(glat, glng);
      } catch (_) {}
      if (ll == null) {
        try {
          final loc = await locationFromAddress(addr);
          if (loc.isNotEmpty) {
            ll = LatLng(loc.first.latitude, loc.first.longitude);
          }
        } catch (_) {}
      }
      if (ll != null) _geoCache[addr] = ll;
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    setState(() {});
    _scheduleFitMapCamera();
  }

  /// Prefer fitting the km-radius circle when we have a user position; otherwise fit project pins.
  void _scheduleFitMapCamera() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_userLatLng != null) {
        unawaited(_fitMapToRadiusCircle());
      } else {
        unawaited(_fitMapToProjects());
      }
    });
  }

  /// Axis-aligned bounds that fully contains a circle of [radiusMeters] around [center].
  LatLngBounds _boundsForCircle(LatLng center, double radiusMeters) {
    final r = radiusMeters.clamp(100.0, 1e6);
    final dLat = r / 111320.0;
    final cosLat = math.cos(center.latitude * math.pi / 180.0).clamp(0.02, 1.0);
    final dLng = r / (111320.0 * cosLat);
    return LatLngBounds(
      southwest: LatLng(center.latitude - dLat, center.longitude - dLng),
      northeast: LatLng(center.latitude + dLat, center.longitude + dLng),
    );
  }

  Future<void> _fitMapToRadiusCircle() async {
    final ctrl = _mapController;
    final center = _userLatLng;
    if (ctrl == null || center == null) return;
    final bounds = _boundsForCircle(center, _radiusKm * 1000.0);
    try {
      await ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 8));
    } catch (_) {
      await ctrl.animateCamera(CameraUpdate.newLatLngZoom(center, 11));
    }
  }

  Future<void> _fitMapToProjects() async {
    final ctrl = _mapController;
    if (ctrl == null) return;
    final visible = _visibleProjects;
    final points = <LatLng>[];
    for (final p in visible) {
      final pos = _coordsFor(p);
      if (pos != null) points.add(pos);
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
      // Fit project pins only — including the user's position here often spans
      // continents and zooms the map to a useless world view.
      final pad = 0.01;
      await ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - pad, minLng - pad),
            northeast: LatLng(maxLat + pad, maxLng + pad),
          ),
          56,
        ),
      );
    } catch (_) {
      await ctrl.animateCamera(CameraUpdate.newLatLngZoom(points.first, 11));
    }
  }

  LatLng? _coordsFor(Project p) {
    if (p.latitude != null && p.longitude != null) {
      return LatLng(p.latitude!, p.longitude!);
    }
    final addr = p.location.trim();
    if (addr.isEmpty) return null;
    return _geoCache[addr];
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  List<Project> get _visibleProjects {
    final q = _searchController.text.trim().toLowerCase();
    final applyRadius = _filtersApplied && _userLatLng != null;
    final applyBudget = _filtersApplied && _minBudgetEuros != null;
    final applyCategory = _filtersApplied && _selectedCategoryIds.isNotEmpty;
    final applyCities = _filtersApplied && _selectedCities.isNotEmpty;

    return _projects.where((p) {
      if (q.isNotEmpty) {
        final hit = p.title.toLowerCase().contains(q) ||
            p.location.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
        if (!hit) return false;
      }
      if (applyBudget) {
        if (p.budgetAmount != null && p.budgetAmount! < _minBudgetEuros!) {
          return false;
        }
      }
      if (applyRadius) {
        final c = _coordsFor(p);
        if (c == null) return false;
        if (_haversineKm(_userLatLng!, c) > _radiusKm) return false;
      }
      if (applyCategory) {
        if (p.categoryId != null) {
          if (!_selectedCategoryIds.contains(p.categoryId)) return false;
        } else {
          final List<String> projectCategoryNames = _categories
              .where((c) => _selectedCategoryIds.contains(c.id))
              .map((c) => c.name.toLowerCase())
              .toList();
          final matchesName = p.serviceType != null &&
              projectCategoryNames.any((name) => p.serviceType!.toLowerCase().contains(name));
          if (!matchesName) return false;
        }
      }
      if (applyCities) {
        final locLower = p.location.toLowerCase();
        final hasMatchingCity = _selectedCities.any((city) => locLower.contains(city.toLowerCase()));
        if (!hasMatchingCity) return false;
      }
      return true;
    }).toList();
  }

  Set<Marker> _markersFor(List<Project> visible) {
    final out = <Marker>{};
    for (final p in visible) {
      final pos = _coordsFor(p);
      if (pos == null) continue;
      out.add(
        Marker(
          markerId: MarkerId('p_${p.id}'),
          position: pos,
          anchor: const Offset(0.5, 1),
          icon: _customProjectMarker ?? _markerHueFallback,
          infoWindow: InfoWindow(
            title: p.title.isNotEmpty ? p.title : p.serviceType ?? 'Project',
            snippet: p.location,
          ),
          onTap: () => context.push('/project-details', extra: p),
        ),
      );
    }
    return out;
  }

  Set<Marker> _allMarkers(List<Project> visible) {
    final projectMarkers = _markersFor(visible);
    final me = _userLatLng;
    final puck = _userLocationPuck;
    if (me == null || puck == null) return projectMarkers;
    return {
      ...projectMarkers,
      Marker(
        markerId: const MarkerId('current_location'),
        position: me,
        icon: puck,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 10,
      ),
    };
  }

  /// Kilometre radius around [ _userLatLng ] (mockup-style: lighter outer disc, darker inner).
  /// Shown whenever we have a position so pros see their search radius on the map.
  Set<Circle> _radiusCircles() {
    final center = _userLatLng;
    if (center == null) return {};
    final outerM = _radiusKm * 1000;
    if (outerM <= 0) return {};
    final innerM = outerM * 0.42;
    return {
      Circle(
        circleId: const CircleId('radius_outer'),
        center: center,
        radius: outerM,
        fillColor: const Color(0xFF6B5E5E).withValues(alpha: 0.16),
        strokeColor: const Color(0xFF5C4F4F).withValues(alpha: 0.4),
        strokeWidth: 1,
        zIndex: 0,
      ),
      Circle(
        circleId: const CircleId('radius_inner'),
        center: center,
        radius: innerM,
        fillColor: const Color(0xFF4A3C3C).withValues(alpha: 0.26),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
        zIndex: 1,
      ),
    };
  }

  void _openFilters() {
    var r = _radiusKm;
    var b = _minBudgetEuros ?? 2000.0;
    var useBudget = _minBudgetEuros != null;
    var tempSelectedCategoryIds = List<int>.from(_selectedCategoryIds);
    var tempSelectedCities = List<String>.from(_selectedCities);
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
                          final isSelected = tempSelectedCategoryIds.contains(cat.id);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(cat.name, style: GoogleFonts.outfit(fontSize: 12)),
                            onSelected: (selected) {
                              setModal(() {
                                if (selected) {
                                  tempSelectedCategoryIds.add(cat.id);
                                } else {
                                  tempSelectedCategoryIds.remove(cat.id);
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
                    if (tempSelectedCities.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tempSelectedCities.map((city) {
                          return Chip(
                            label: Text(city, style: GoogleFonts.outfit(fontSize: 12)),
                            onDeleted: () {
                              setModal(() {
                                tempSelectedCities.remove(city);
                              });
                            },
                            deleteIcon: const Icon(LucideIcons.x, size: 14),
                            backgroundColor: AppColors.primaryRed.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.2)),
                            ),
                          );
                        }).toList(),
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
                                  if (!tempSelectedCities.contains(cityName)) {
                                    tempSelectedCities.add(cityName);
                                  }
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
                      value: r.clamp(1, 100),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      activeColor: AppColors.primaryRed,
                      label: '${r.round()} km',
                      onChanged: _userLatLng == null
                          ? null
                          : (v) => setModal(() => r = v),
                    ),
                    Text(
                      'provider.projects.max_radius_label'
                          .tr(namedArgs: {'km': '${r.round()}'}),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_userLatLng == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'provider.projects.enable_location_radius'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'provider.projects.min_budget'.tr(),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: useBudget,
                          activeThumbColor: AppColors.primaryRed,
                          onChanged: (v) => setModal(() => useBudget = v),
                        ),
                      ],
                    ),
                    if (useBudget)
                      Slider(
                        value: b.clamp(0, 20000),
                        min: 0,
                        max: 20000,
                        divisions: 40,
                        activeColor: AppColors.primaryRed,
                        label: '€${b.round()}',
                        onChanged: (v) => setModal(() => b = v),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filtersApplied = true;
                          _radiusKm = r;
                          _minBudgetEuros = useBudget ? b : null;
                          _selectedCategoryIds = tempSelectedCategoryIds;
                          _selectedCities = tempSelectedCities;
                        });
                        Navigator.pop(ctx);
                        if (_tabController.index != 1) {
                          _tabController.animateTo(1);
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) unawaited(_fitMapToRadiusCircle());
                        });
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
                        'provider.projects.view_map'.tr(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filtersApplied = false;
                          _minBudgetEuros = null;
                          _selectedCategoryIds = [];
                          _selectedCities = [];
                        });
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

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProjects;
    final center = _userLatLng ?? const LatLng(48.8566, 2.3522);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: 'provider.projects.discover_title'.tr(),
        showNotification: false,
        trailingActions: [
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal, color: AppColors.primaryRed),
            onPressed: _loading ? null : _openFilters,
          ),
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
      body: _loading
          ? Center(
              child: AppShimmer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ShimmerBox(width: double.infinity, height: 120, radius: 12),
                    SizedBox(height: 16),
                    ShimmerBox(width: double.infinity, height: 200, radius: 12),
                  ],
                ),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _load,
                          child: Text(
                            'provider.projects.try_again'.tr(),
                            style: GoogleFonts.outfit(color: AppColors.primaryRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListTab(visible),
                    _buildMapTab(center, visible),
                  ],
                ),
    );
  }

  Widget _buildListTab(List<Project> visible) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'provider.projects.search_projects'.tr(),
              prefixIcon: const Icon(LucideIcons.search, color: Colors.black38),
              suffixIcon: IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 20),
                onPressed: _load,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryRed),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'provider.projects.empty_list'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primaryRed,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final p = visible[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 2,
                          shadowColor: Colors.black26,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/project-details', extra: p),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 190,
                                        child: ProjectImagePlaceholder.hasDisplayableUrl(p.imageUrl)
                                            ? Image.network(
                                                p.imageUrl!,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, progress) {
                                                  if (progress == null) return child;
                                                  return AppShimmer(
                                                    child: const ShimmerBox(
                                                      width: double.infinity,
                                                      height: 190,
                                                      radius: 0,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (_, __, ___) => const ProjectImagePlaceholder(height: 190),
                                              )
                                            : const ProjectImagePlaceholder(height: 190),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: ProjectFavoriteButton(project: p),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p.title.isNotEmpty ? p.title : (p.serviceType ?? '—'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        p.description.isEmpty ? 'No description available.' : p.description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: AppColors.textMain,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.mapPin, size: 17, color: AppColors.primaryRed),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              p.location.isEmpty ? 'N/A' : p.location,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            p.date.isEmpty ? 'N/A' : p.date,
                                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(LucideIcons.calendar, size: 17, color: AppColors.textSecondary),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Divider(height: 1, color: Colors.grey.shade300),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.wallet, size: 18, color: AppColors.primaryRed),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Budget (€)',
                                            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain),
                                          ),
                                          const Spacer(),
                                          Text(
                                            p.budget ?? 'N/A',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryRed,
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
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMapTab(LatLng center, List<Project> visible) {
    final markers = _allMarkers(visible);
    final hasPins = _markersFor(visible).isNotEmpty;
    final mq = MediaQuery.of(context);
    final mapPad = EdgeInsets.only(
      top: mq.padding.top + 128,
      bottom: mq.padding.bottom + (hasPins ? 32 : 120),
      left: 12,
      right: 12,
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 11),
          padding: mapPad,
          // Let the map win gestures over the surrounding TabBarView / PageView.
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          // Custom [_userLocationPuck] matches mockup (white ring + blue dot).
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          markers: markers,
          circles: _radiusCircles(),
          onMapCreated: (c) {
            _mapController = c;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _scheduleFitMapCamera();
            });
          },
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'provider.projects.search_projects'.tr(),
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.mapPin, color: AppColors.primaryRed),
                  onPressed: _loadUserLocation,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _load(),
            ),
          ),
        ),
        if (!hasPins && !_loading)
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'provider.projects.map_no_pins'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _load,
                      child: Text(
                        'provider.projects.try_again'.tr(),
                        style: GoogleFonts.outfit(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
