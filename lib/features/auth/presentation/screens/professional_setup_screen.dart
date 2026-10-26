import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/services/google_places_service.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/service_area_search_field.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../projects/domain/models/project_category.dart';
import '../../../projects/presentation/providers/project_provider.dart';
import '../../domain/models/provider_profile.dart';
import '../../domain/models/service_area_location.dart';
import '../providers/auth_provider.dart';

class ProfessionalSetupScreen extends ConsumerStatefulWidget {
  const ProfessionalSetupScreen({super.key});

  @override
  ConsumerState<ProfessionalSetupScreen> createState() =>
      _ProfessionalSetupScreenState();
}

class _ProfessionalSetupScreenState
    extends ConsumerState<ProfessionalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactMailController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _siretController = TextEditingController();
  final _websiteController = TextEditingController();
  final _socialInstagramController = TextEditingController();
  final _socialFacebookController = TextEditingController();
  final _socialTwitterController = TextEditingController();
  final _socialLinkedinController = TextEditingController();
  bool _dataLoaded = false;
  bool _saving = false;
  bool _pickingKbis = false;
  String? _selectedSpecialty;
  int? _selectedSpecialtyId;
  bool _loadingSpecialties = true;
  List<ServiceAreaLocation> _serviceAreas = [];
  List<String> _kbisFiles = [];
  List<String> _projectFiles = [];
  List<String> _certificateFiles = [];
  List<ProjectCategory> _specialties = const [];

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  Future<void> _loadSpecialties() async {
    try {
      final categories = await ref
          .read(projectRepositoryProvider)
          .getCategories();
      if (!mounted) return;
      setState(() {
        _specialties = categories;
        if ((_selectedSpecialty == null || _selectedSpecialty!.isEmpty) &&
            _selectedSpecialtyId != null &&
            _selectedSpecialtyId! > 0) {
          final matchedById = categories.cast<ProjectCategory?>().firstWhere(
            (c) => c?.id == _selectedSpecialtyId,
            orElse: () => null,
          );
          _selectedSpecialty = matchedById?.name;
        }
        if ((_selectedSpecialtyId == null || _selectedSpecialtyId! <= 0) &&
            _selectedSpecialty != null &&
            _selectedSpecialty!.isNotEmpty) {
          final matched = categories.cast<ProjectCategory?>().firstWhere(
            (c) => c?.name == _selectedSpecialty,
            orElse: () => null,
          );
          _selectedSpecialtyId = matched?.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      AppToast.error('Unable to load categories. Please try again.');
    } finally {
      if (!mounted) return;
      setState(() => _loadingSpecialties = false);
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _contactMailController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _postalCodeController.dispose();
    _siretController.dispose();
    _websiteController.dispose();
    _socialInstagramController.dispose();
    _socialFacebookController.dispose();
    _socialTwitterController.dispose();
    _socialLinkedinController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    if (_dataLoaded) return;
    _dataLoaded = true;
    final user = ref.read(authStateNotifierProvider).currentUser;
    if (user != null) {
      _userNameController.text = user.displayName;
      _phoneController.text = user.phone ?? '';
      _contactMailController.text = user.email;
      final p = user.providerProfile;
      if (p != null) {
        _descriptionController.text = p.description ?? '';
        _selectedSpecialty = p.specialty;
        _selectedSpecialtyId = p.categoryId;
        _companyNameController.text = p.companyName ?? '';
        _contactMailController.text = p.contactMail?.isNotEmpty == true
            ? p.contactMail!
            : user.email;
        _companyAddressController.text = p.companyAddress ?? '';
        _postalCodeController.text = p.postalCode ?? '';
        _siretController.text = p.siret ?? '';
        _serviceAreas = List.from(p.serviceAreas);
        _websiteController.text = p.website ?? '';
        _socialInstagramController.text = p.socialInstagram ?? '';
        _socialFacebookController.text = p.socialFacebook ?? '';
        _socialTwitterController.text = p.socialTwitter ?? '';
        _socialLinkedinController.text = p.socialLinkedin ?? '';
        _kbisFiles = List.from(
          p.kbisExtractUrl == null || p.kbisExtractUrl!.isEmpty
              ? const []
              : [p.kbisExtractUrl!],
        );
        _projectFiles = List.from(p.projectUploads);
        _certificateFiles = List.from(p.certificateUploads);
      }
    }
  }

  Future<void> _submitProfile() async {
    final displayName = _userNameController.text.trim();
    if (displayName.isEmpty) {
      AppToast.error('Please enter your name');
      return;
    }
    if (!_serviceAreas.any((e) => e.isValidForApi)) {
      AppToast.error(
        'Add at least one service area: please pick a suggestion from the search results.',
      );
      return;
    }
    setState(() => _saving = true);
    final profile = ProviderProfile(
      displayName: displayName,
      phone: _phoneController.text.trim(),
      address: _companyAddressController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      specialty: _selectedSpecialty,
      categoryId: _selectedSpecialtyId,
      companyName: _companyNameController.text.trim().isEmpty
          ? null
          : _companyNameController.text.trim(),
      contactMail: _contactMailController.text.trim().isEmpty
          ? null
          : _contactMailController.text.trim(),
      companyAddress: _companyAddressController.text.trim().isEmpty
          ? null
          : _companyAddressController.text.trim(),
      postalCode: _postalCodeController.text.trim().isEmpty
          ? null
          : _postalCodeController.text.trim(),
      siret: _siretController.text.trim().isEmpty
          ? null
          : _siretController.text.trim(),
      serviceAreas: _serviceAreas,
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      socialInstagram: _socialInstagramController.text.trim().isEmpty
          ? null
          : _socialInstagramController.text.trim(),
      socialFacebook: _socialFacebookController.text.trim().isEmpty
          ? null
          : _socialFacebookController.text.trim(),
      socialTwitter: _socialTwitterController.text.trim().isEmpty
          ? null
          : _socialTwitterController.text.trim(),
      socialLinkedin: _socialLinkedinController.text.trim().isEmpty
          ? null
          : _socialLinkedinController.text.trim(),
      kbisExtractUrl: _kbisFiles.isEmpty ? null : _kbisFiles.first,
      projectUploads: _projectFiles,
      certificateUploads: _certificateFiles,
    );
    final result = await ref
        .read(authRepositoryProvider)
        .updateProviderProfile(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.errorMessage != null) {
      _showSystematicError(result.errorMessage!);
      return;
    }

    // Geocode and update primary map pin with professional company address
    final companyAddr = _companyAddressController.text.trim();
    if (companyAddr.isNotEmpty) {
      try {
        final resolved = await GooglePlacesService.geocodeWithGoogleGeocodingApi(companyAddr);
        if (resolved != null && resolved.isValidForApi) {
          final token = await SessionStorage().getToken();
          if (token != null && token.isNotEmpty) {
            await ApiClient().put(
              '/professionals/location',
              body: {
                'latitude': resolved.latitude,
                'longitude': resolved.longitude,
              },
              token: token,
            );
          }
        }
      } catch (e) {
        debugPrint('[ProfessionalSetup] Failed to update map pin location: $e');
      }
    }

    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    context.go('/provider-home');
  }

  void _showSystematicError(String message) {
    final rawLines = message
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final lines = <String>[];
    for (var l in rawLines) {
      var clean = l;
      if (clean.startsWith('- ') || clean.startsWith('* ')) {
        clean = clean.substring(2).trim();
      }
      final lower = clean.toLowerCase();
      if (lower == 'validation failed' ||
          lower == 'validation failed.' ||
          lower == 'validation failed:' ||
          lower == 'validation error' ||
          lower == 'validation error:' ||
          lower == 'error: validation failed') {
        continue;
      }
      if (clean.isNotEmpty) {
        lines.add(AppToast.localizeBackendMessage(clean, context));
      }
    }

    if (lines.isEmpty) return;
    if (lines.length == 1) {
      AppToast.error(lines.first);
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertTriangle,
                color: AppColors.primaryRed,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'provider.profile.systematic_error_title'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: lines
                  .map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '- ',
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontSize: 17,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              l,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                height: 1.3,
                                color: AppColors.textMain,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles({
    required bool allowMultiple,
    required ValueChanged<List<String>> onPicked,
    required void Function(bool) setLoading,
  }) async {
    setState(() => setLoading(true));
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
      );
      if (!mounted) return;
      if (result == null) return;
      final fileRefs = result.files
          .map((f) => (f.path ?? '').trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (fileRefs.isEmpty) {
        AppToast.error(
          'Could not access selected file path. Please pick files from local storage.',
        );
        return;
      }
      onPicked(fileRefs);
    } finally {
      if (mounted) setState(() => setLoading(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(
        title: 'Setup Profile',
        showNotification: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Personal Info.*'),
              _buildTextField(
                controller: _userNameController,
                hint: 'User name',
                icon: LucideIcons.user,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _phoneController,
                hint: 'Phone No.',
                icon: LucideIcons.phone,
              ),
              const SizedBox(height: 12),
              _buildDescriptionField(),

              const SizedBox(height: 32),
              _buildSectionTitle('Choose your specialty*'),
              _buildSpecialtyDropdown(),

              const SizedBox(height: 32),
              _buildSectionTitle('Company Info.'),
              _buildLabel('Company name*'),
              _buildTextField(
                controller: _companyNameController,
                hint: 'Company name',
              ),
              const SizedBox(height: 12),
              _buildLabel('Contact Mail*'),
              _buildTextField(
                controller: _contactMailController,
                hint: 'Contact email',
              ),
              const SizedBox(height: 12),
              _buildLabel('Address*'),
              _GooglePlacesField(
                controller: _companyAddressController,
                hint: 'Address',
              ),
              const SizedBox(height: 12),
              _buildLabel('Postal Code'),
              _buildTextField(
                controller: _postalCodeController,
                hint: 'Postal code',
              ),
              const SizedBox(height: 12),
              _buildLabel('SIRET number *'),
              _buildTextField(
                controller: _siretController,
                hint: 'SIRET number',
              ),
              const SizedBox(height: 24),
              ..._kbisFiles.map(
                (f) => _buildFileItem(
                  f,
                  onDelete: () => setState(() => _kbisFiles.remove(f)),
                ),
              ),
              _buildUploadButton(
                'Upload KBIS (Optional)',
                isLoading: _pickingKbis,
                onTap: _pickingKbis ? null : () => _pickFiles(
                  allowMultiple: false,
                  setLoading: (v) => _pickingKbis = v,
                  onPicked: (files) =>
                      setState(() => _kbisFiles = files.take(1).toList()),
                ),
              ),              const SizedBox(height: 32),
              _buildSectionTitle('Services Area'),
              _buildLabel('Services Area'),
              _buildServiceAreaTags(),
              const SizedBox(height: 12),
              ServiceAreaSearchBlock(onAreaAdded: _onServiceAreaAdded),
              const SizedBox(height: 24),
              _buildLabel('Website or Pages URL'),
              _buildTextField(
                controller: _websiteController,
                hint: 'https://yourpageurl.com',
              ),
              const SizedBox(height: 48),
              PrimaryGradientButton(
                text: 'Submit',
                isLoading: _saving,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _submitProfile();
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildTextField({
    String? hint,
    IconData? icon,
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint ?? '',
          hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
          prefixIcon: icon != null
              ? Icon(icon, color: AppColors.primaryRed, size: 20)
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryRed.withOpacity(0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 1),
          ),
          filled: true,
          fillColor: const Color(0xFFFCFCFC),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Write short description about you.',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Write about you................',
            hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primaryRed.withOpacity(0.1),
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
      ],
    );
  }

  Widget _buildSpecialtyDropdown() {
    final items = [..._specialties];
    if (_selectedSpecialty != null &&
        _selectedSpecialty!.isNotEmpty &&
        !items.any((e) => e.name == _selectedSpecialty)) {
      items.insert(
        0,
        ProjectCategory(
          id: _selectedSpecialtyId ?? -1,
          name: _selectedSpecialty!,
          slug: _selectedSpecialty!.toLowerCase().replaceAll(' ', '-'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSpecialty,
          hint: Text(
            _loadingSpecialties ? 'Loading categories...' : 'Select...',
            style: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
          ),
          isExpanded: true,
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 20,
            color: Colors.black45,
          ),
          items: items.map((specialty) {
            return DropdownMenuItem<String>(
              value: specialty.name,
              child: Row(
                children: [
                  _buildCategoryVisual(specialty, size: 20),
                  const SizedBox(width: 12),
                  Text(specialty.name, style: GoogleFonts.outfit(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: _loadingSpecialties
              ? null
              : (value) => setState(() {
                  _selectedSpecialty = value;
                  final selected = _specialties.cast<ProjectCategory?>().firstWhere(
                    (c) => c?.name == value,
                    orElse: () => null,
                  );
                  _selectedSpecialtyId = selected?.id;
                }),
        ),
      ),
    );
  }

  Widget _buildCategoryVisual(ProjectCategory category, {double size = 20}) {
    final imageUrl = category.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            _categoryIcon(category),
            color: AppColors.primaryRed,
            size: size,
          ),
        ),
      );
    }
    return Icon(
      _categoryIcon(category),
      color: AppColors.primaryRed,
      size: size,
    );
  }

  IconData _categoryIcon(ProjectCategory category) {
    final key = '${category.slug} ${category.name}'.toLowerCase();
    if (key.contains('plumb')) return LucideIcons.wrench;
    if (key.contains('paint')) return LucideIcons.palette;
    if (key.contains('tile')) return LucideIcons.layoutGrid;
    if (key.contains('kitchen')) return LucideIcons.utensilsCrossed;
    if (key.contains('pool') || key.contains('pisc')) return LucideIcons.waves;
    if (key.contains('exterior') || key.contains('architect'))
      return LucideIcons.home;
    if (key.contains('carpent') || key.contains('wood'))
      return LucideIcons.hammer;
    if (key.contains('clean')) return LucideIcons.sparkles;
    if (key.contains('electric')) return LucideIcons.zap;
    return LucideIcons.briefcase;
  }

  Widget _buildUploadButton(String label, {String? hint, VoidCallback? onTap, bool isLoading = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: isLoading ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2E7E7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading...',
                    style: GoogleFonts.outfit(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    LucideIcons.upload,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hint,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppColors.primaryRed,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileItem(String fileName, {VoidCallback? onDelete}) {
    final label = _displayFileName(fileName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF4A698C),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              LucideIcons.trash2,
              color: AppColors.primaryRed,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _displayFileName(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return raw;
    final uri = Uri.tryParse(t);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final fromUrl = uri.pathSegments.last.trim();
      if (fromUrl.isNotEmpty) return fromUrl;
    }
    final normalized = t.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx >= 0 && idx + 1 < normalized.length) {
      return normalized.substring(idx + 1);
    }
    return t;
  }

  void _onServiceAreaAdded(ServiceAreaLocation loc) {
    if (!loc.isValidForApi) return;
    if (_serviceAreas.any((e) => e.isValidForApi && e.isSameLocation(loc))) {
      AppToast.info('This area is already added.');
      return;
    }
    setState(() => _serviceAreas = [..._serviceAreas, loc]);
  }

  Widget _buildServiceAreaTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _serviceAreas.map((area) {
        return GestureDetector(
          onTap: () => setState(() {
            _serviceAreas.removeWhere((x) => identical(x, area));
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2E7E7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  area.displayLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.x, size: 12, color: Colors.black26),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Reusable Google Places autocomplete field ─────────────────────────────────

class _GooglePlacesField extends StatefulWidget {
  const _GooglePlacesField({required this.controller, this.hint = 'Address'});

  final TextEditingController controller;
  final String hint;

  @override
  State<_GooglePlacesField> createState() => _GooglePlacesFieldState();
}

class _GooglePlacesFieldState extends State<_GooglePlacesField> {
  final _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final String _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  Timer? _debounce;
  OverlayEntry? _overlay;
  List<String> _suggestions = const [];
  bool _loading = false;
  bool _suppress = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_suppress) return;
    _debounce?.cancel();
    final text = widget.controller.text.trim();
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
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'types': 'geocode',
          'language': 'fr',
          'components': 'country:fr',
          'sessiontoken': _sessionToken,
          'key': kGoogleMapsPlacesApiKey,
        },
      );
      final res = await http.get(uri);
      if (!mounted) return;
      final map = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
      final status = (map['status'] ?? '').toString();
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _clearSuggestions();
        return;
      }
      final predictions = map['predictions'];
      if (predictions is! List) {
        _clearSuggestions();
        return;
      }
      final results = predictions
          .whereType<Map>()
          .map((e) => (e['description'] ?? '').toString())
          .where((d) => d.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _suggestions = results;
      });
      _showOverlay();
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

  void _select(String place) {
    _suppress = true;
    widget.controller.text = place;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: place.length),
    );
    _clearSuggestions();
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _suppress = false);
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
                            color: AppColors.primaryRed.withOpacity(0.09),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        title: Text(
                          s,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _select(s),
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
    final theme = Theme.of(context);
    final localTheme = theme.copyWith(
      brightness: Brightness.light,
      colorScheme: theme.colorScheme.copyWith(
        brightness: Brightness.light,
        onSurface: AppColors.textMain,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primaryRed,
        selectionColor: AppColors.primaryRed.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primaryRed,
      ),
    );
    return CompositedTransformTarget(
      link: _layerLink,
      child: Theme(
        data: localTheme,
        child: TextFormField(
          key: _fieldKey,
          controller: widget.controller,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textMain,
          ),
          cursorColor: AppColors.primaryRed,
          decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
          prefixIcon: const Icon(
            LucideIcons.mapPin,
            color: AppColors.primaryRed,
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
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryRed.withOpacity(0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 1),
          ),
          filled: true,
          fillColor: const Color(0xFFFCFCFC),
        ),
        ),
      ),
    );
  }
}
