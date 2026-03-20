import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/project_filter_overlay.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(48.8566, 2.3522); // Default Paris
  bool _loading = true;
  bool _isSearching = false;
  bool _showNoResults = true;
  bool _showFilter = false;

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('prof1'),
      position: LatLng(48.8656, 2.3522),
    ),
    const Marker(
      markerId: MarkerId('prof2'),
      position: LatLng(48.8566, 2.3622),
    ),
    const Marker(
      markerId: MarkerId('prof3'),
      position: LatLng(48.8466, 2.3522),
    ),
    const Marker(
      markerId: MarkerId('prof4'),
      position: LatLng(48.8566, 2.3422),
    ),
  };

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _loading = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
    }
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _showNoResults = false;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _showNoResults = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 14),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            circles: {
              Circle(
                circleId: const CircleId('radius'),
                center: _currentPosition,
                radius: 1000,
                fillColor: Colors.black.withValues(alpha: 0.1),
                strokeColor: Colors.black26,
                strokeWidth: 1,
              ),
            },
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderIcon(LucideIcons.chevronLeft, () => Navigator.pop(context)),
                      Text(
                        'Filter by location',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      _buildHeaderIcon(LucideIcons.sliders, () => setState(() => _showFilter = true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                ],
              ),
            ),
          ),

          // Center Marker (User Location)
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Bottom States
          if (_showNoResults && !_isSearching) _buildNoResultsOverlay(),
          if (_isSearching) _buildSearchingOverlay(),

          // Filter Overlay
          if (_showFilter)
            ProjectFilterOverlay(
              onClose: () => setState(() => _showFilter = false),
              onViewMap: () {
                setState(() => _showFilter = false);
                _startSearch();
              },
            ),

          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, color: Colors.black26),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search location',
                hintStyle: GoogleFonts.outfit(color: Colors.black26),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const Icon(LucideIcons.mapPin, color: AppColors.primaryRed),
        ],
      ),
    );
  }

  Widget _buildNoResultsOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not find any one.',
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: ElevatedButton(
                onPressed: _startSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.2),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2), width: 8),
                    ),
                    child: Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryRed, width: 4),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              onEnd: () {}, // Not needed for loop here, but can use state to toggle
            ),
            const SizedBox(height: 12),
            Text(
              'Searching',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
