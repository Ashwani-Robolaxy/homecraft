import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  bool _dataLoaded = false;
  bool _saving = false;
  bool _detectingCity = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    if (_dataLoaded) return;
    _dataLoaded = true;
    final user = ref.read(authStateNotifierProvider).currentUser;
    if (user != null) {
      _nameController.text = user.displayName;
      _phoneController.text = user.phone ?? '';
      _cityController.text = user.city ?? '';
    }
  }

  Future<void> _detectCity() async {
    setState(() => _detectingCity = true);
    try {
      // Check / request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) AppToast.error('Location permission is required to detect your city.');
        return;
      }

      // Get position — try last known first for speed
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 10));

      // Reverse geocode
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;

      final place = placemarks.firstOrNull;
      final city = place?.locality?.isNotEmpty == true
          ? place!.locality!
          : place?.subAdministrativeArea?.isNotEmpty == true
              ? place!.subAdministrativeArea!
              : place?.administrativeArea ?? '';

      if (city.isNotEmpty) {
        _cityController.text = city;
        AppToast.success('City detected: $city');
      } else {
        AppToast.error('Could not determine city from your location.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error('Could not detect location. Please enter your city manually.');
    } finally {
      if (mounted) setState(() => _detectingCity = false);
    }
  }

  Future<void> _updateProfile() async {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      AppToast.error('auth.validation.username_required'.tr());
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(authRepositoryProvider).updateProfile(
          displayName: displayName,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.errorMessage != null) {
      AppToast.error(result.errorMessage!.tr());
      return;
    }
    await ref.read(authStateNotifierProvider).refresh();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData();
    final user = ref.watch(authStateNotifierProvider).currentUser;
    final displayName = user?.displayName ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Personal Info', showNotification: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileImage(),
            const SizedBox(height: 12),
            Text(
              displayName.isEmpty ? '—' : displayName,
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black12),
            ),
            const SizedBox(height: 32),
            _buildTextField(label: 'Your Name', controller: _nameController),
            const SizedBox(height: 20),
            _buildTextField(label: 'Phone No.', controller: _phoneController),
            const SizedBox(height: 20),
            _buildCityField(),
            const SizedBox(height: 100),
            PrimaryGradientButton(
              text: 'Update Profile',
              onPressed: _updateProfile,
              isLoading: _saving,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
          ),
          child: const CircleAvatar(radius: 70, backgroundImage: AssetImage('assets/images/cleaner_profile_1.png')),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Icon(LucideIcons.pencil, size: 20, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF9DADA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF9DADA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'City',
          style: GoogleFonts.outfit(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cityController,
          decoration: InputDecoration(
            hintText: 'Enter city or detect automatically',
            hintStyle: GoogleFonts.outfit(fontSize: 14, color: Colors.black38),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF9DADA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF9DADA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed),
            ),
            suffixIcon: _detectingCity
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                    ),
                  )
                : IconButton(
                    tooltip: 'Detect my city',
                    onPressed: _detectingCity ? null : _detectCity,
                    icon: const Icon(LucideIcons.locateFixed, color: AppColors.primaryRed, size: 22),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(LucideIcons.info, size: 12, color: Colors.black38),
            const SizedBox(width: 4),
            Text(
              'Tap the location icon to auto-detect your city',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.black38),
            ),
          ],
        ),
      ],
    );
  }
}
