import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../auth/domain/models/provider_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../projects/domain/models/project_category.dart';
import '../../../projects/presentation/providers/project_provider.dart';

class EditPersonalInfoScreen extends ConsumerStatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  ConsumerState<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends ConsumerState<EditPersonalInfoScreen> {
  final _userNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _contactMailController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _siretController = TextEditingController();
  final _websiteController = TextEditingController();
  final _searchLocationController = TextEditingController();
  final _socialInstagramController = TextEditingController();
  final _socialFacebookController = TextEditingController();
  final _socialTwitterController = TextEditingController();
  final _socialLinkedinController = TextEditingController();
  List<String> _serviceAreas = [];
  final List<String> _uploadedProjects = ['Projects.jpg'];
  final List<String> _uploadedCerts = ['Certificate.jpg'];
  String? _selectedSpecialty;
  List<ProjectCategory> _specialties = const [];
  bool _loadingSpecialties = true;
  bool _dataLoaded = false;
  bool _saving = false;
  bool _detectingCity = false;
  String? _kbisFile;

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  Future<void> _loadSpecialties() async {
    try {
      final categories = await ref.read(projectRepositoryProvider).getCategories();
      if (!mounted) return;
      setState(() => _specialties = categories);
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
    _addressController.dispose();
    _descriptionController.dispose();
    _companyNameController.dispose();
    _contactMailController.dispose();
    _companyAddressController.dispose();
    _postalCodeController.dispose();
    _siretController.dispose();
    _websiteController.dispose();
    _searchLocationController.dispose();
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
      _addressController.text = user.city ?? '';
      _contactMailController.text = user.email;
      final p = user.providerProfile;
      if (p != null) {
        _descriptionController.text = p.description ?? '';
        _selectedSpecialty = p.specialty;
        _companyNameController.text = p.companyName ?? '';
        _contactMailController.text = p.contactMail?.isNotEmpty == true ? p.contactMail! : user.email;
        _companyAddressController.text = p.companyAddress ?? '';
        _postalCodeController.text = p.postalCode ?? '';
        _siretController.text = p.siret ?? '';
        _serviceAreas = List.from(p.serviceAreas);
        _websiteController.text = p.website ?? '';
        _socialInstagramController.text = p.socialInstagram ?? '';
        _socialFacebookController.text = p.socialFacebook ?? '';
        _socialTwitterController.text = p.socialTwitter ?? '';
        _socialLinkedinController.text = p.socialLinkedin ?? '';
        _uploadedProjects
          ..clear()
          ..addAll(p.projectUploads);
        _uploadedCerts
          ..clear()
          ..addAll(p.certificateUploads);
        _kbisFile = p.kbisExtractUrl;
      }
    }
  }

  Future<void> _detectCity() async {
    setState(() => _detectingCity = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) AppToast.error('Location permission is required to detect your city.');
        return;
      }
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 10));
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      final place = placemarks.firstOrNull;
      final city = place?.locality?.isNotEmpty == true
          ? place!.locality!
          : place?.subAdministrativeArea?.isNotEmpty == true
              ? place!.subAdministrativeArea!
              : place?.administrativeArea ?? '';
      if (city.isNotEmpty) {
        _addressController.text = city;
        AppToast.success('City detected: $city');
      } else {
        AppToast.error('Could not determine city from your location.');
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.error('Could not detect location. Please enter your city manually.');
    } finally {
      if (mounted) setState(() => _detectingCity = false);
    }
  }

  Future<void> _saveProfile() async {
    final displayName = _userNameController.text.trim();
    if (displayName.isEmpty) {
      if (mounted) {
        AppToast.error('auth.validation.username_required'.tr());
      }
      return;
    }
    setState(() => _saving = true);
    final profile = ProviderProfile(
      displayName: displayName,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      specialty: _selectedSpecialty,
      companyName: _companyNameController.text.trim().isEmpty ? null : _companyNameController.text.trim(),
      contactMail: _contactMailController.text.trim().isEmpty ? null : _contactMailController.text.trim(),
      companyAddress: _companyAddressController.text.trim().isEmpty ? null : _companyAddressController.text.trim(),
      postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
      siret: _siretController.text.trim().isEmpty ? null : _siretController.text.trim(),
      serviceAreas: _serviceAreas,
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      socialInstagram: _socialInstagramController.text.trim().isEmpty ? null : _socialInstagramController.text.trim(),
      socialFacebook: _socialFacebookController.text.trim().isEmpty ? null : _socialFacebookController.text.trim(),
      socialTwitter: _socialTwitterController.text.trim().isEmpty ? null : _socialTwitterController.text.trim(),
      socialLinkedin: _socialLinkedinController.text.trim().isEmpty ? null : _socialLinkedinController.text.trim(),
      kbisExtractUrl: _kbisFile,
      projectUploads: _uploadedProjects,
      certificateUploads: _uploadedCerts,
    );
    final result = await ref.read(authRepositoryProvider).updateProviderProfile(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.errorMessage != null) {
      final msg = result.errorMessage!;
      _showSystematicError(msg.startsWith('auth.') ? msg.tr() : msg);
      return;
    }
    await ref.read(authStateNotifierProvider).refresh();
    if (mounted) context.pop();
  }

  void _showSystematicError(String message) {
    final lines = message
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length <= 1) {
      AppToast.error(message);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.alertTriangle, color: AppColors.primaryRed, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please fix the following',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.textMain),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Column(
                    children: lines
                        .map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('- ', style: TextStyle(color: AppColors.textMain, fontSize: 17)),
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    textStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CommonAppBar(title: 'provider.profile.edit_personal_info'.tr(), showNotification: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Personal Info.*'),
            const SizedBox(height: 12),
            _input(controller: _userNameController, hint: 'User name.', icon: LucideIcons.user),
            const SizedBox(height: 12),
            _input(controller: _phoneController, hint: 'Phone No.', icon: LucideIcons.phone),
            const SizedBox(height: 12),
            _input(controller: _addressController, hint: 'Address.', icon: LucideIcons.mapPin),
            const SizedBox(height: 12),
            Text('Write short description about you.', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write about you.........',
                hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Choose your specialty'),
            const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final items = [..._specialties];
                if (_selectedSpecialty != null &&
                    _selectedSpecialty!.isNotEmpty &&
                    !items.any((e) => e.name == _selectedSpecialty)) {
                  items.insert(
                    0,
                    ProjectCategory(
                      id: -1,
                      name: _selectedSpecialty!,
                      slug: _selectedSpecialty!.toLowerCase().replaceAll(' ', '-'),
                    ),
                  );
                }
                return DropdownButtonFormField<String>(
                  value: _selectedSpecialty,
                  hint: Text(
                    _loadingSpecialties ? 'Loading categories...' : 'Select...',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.black38),
                  ),
                  items: items
                      .map((s) => DropdownMenuItem<String>(
                            value: s.name,
                            child: Text(s.name, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                          ))
                      .toList(),
                  onChanged: _loadingSpecialties ? null : (v) => setState(() => _selectedSpecialty = v),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  icon: const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.textSecondary),
                );
              },
            ),
            const SizedBox(height: 24),
            _sectionTitle('Company Info.'),
            const SizedBox(height: 12),
            _labeledInput(label: 'Company name*', controller: _companyNameController),
            const SizedBox(height: 12),
            _labeledInput(label: 'Contact Mail*', controller: _contactMailController),
            const SizedBox(height: 12),
            _input(controller: _companyAddressController, hint: 'Address', icon: LucideIcons.mapPin),
            const SizedBox(height: 12),
            _labeledInput(label: 'Postal Code', controller: _postalCodeController),
            const SizedBox(height: 12),
            _labeledInput(label: 'SIRET number *', controller: _siretController),
            const SizedBox(height: 12),
            Text('Upload KBIS (Optional)', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            if (_kbisFile != null && _kbisFile!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_kbisFile!, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: AppColors.primaryRed, size: 20),
                      onPressed: () => setState(() => _kbisFile = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(allowMultiple: false);
                if (result == null || result.files.isEmpty) return;
                final fileName = result.files.first.name;
                if (fileName.isEmpty) return;
                setState(() => _kbisFile = fileName);
              },
              icon: const Icon(LucideIcons.upload, size: 18, color: AppColors.primaryRed),
              label: Text('Upload', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryRed),
                backgroundColor: AppColors.primaryRed.withValues(alpha: 0.08),
                foregroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Projects and Certification'),
            const SizedBox(height: 8),
            Text('Upload Projects', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            ..._uploadedProjects.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text(f, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                      const Spacer(),
                      IconButton(icon: const Icon(LucideIcons.trash2, color: AppColors.primaryRed, size: 20), onPressed: () => setState(() => _uploadedProjects.remove(f))),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            _uploadButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                if (result == null || result.files.isEmpty) return;
                final names = result.files.map((e) => e.name).where((e) => e.isNotEmpty).toList();
                if (names.isEmpty) return;
                setState(() {
                  _uploadedProjects.addAll(names);
                  if (_uploadedProjects.length > 20) {
                    _uploadedProjects.removeRange(20, _uploadedProjects.length);
                  }
                });
              },
            ),
            const SizedBox(height: 4),
            Text('Add at least 3 file & maximum 20 file', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.primaryRed)),
            const SizedBox(height: 16),
            Text('Upload Certificate', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            ..._uploadedCerts.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text(f, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
                      const Spacer(),
                      IconButton(icon: const Icon(LucideIcons.trash2, color: AppColors.primaryRed, size: 20), onPressed: () => setState(() => _uploadedCerts.remove(f))),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            _uploadButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                if (result == null || result.files.isEmpty) return;
                final names = result.files.map((e) => e.name).where((e) => e.isNotEmpty).toList();
                if (names.isEmpty) return;
                setState(() => _uploadedCerts.addAll(names));
              },
            ),
            const SizedBox(height: 4),
            Text('Add at least 2 file', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.primaryRed)),
            const SizedBox(height: 24),
            _sectionTitle('Services Area and Social'),
            const SizedBox(height: 8),
            Text('Services Area', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _serviceAreas.map((area) => Chip(
                    label: Text(area, style: GoogleFonts.outfit(fontSize: 12)),
                    deleteIcon: const Icon(LucideIcons.x, size: 14),
                    onDeleted: () => setState(() => _serviceAreas.remove(area)),
                    backgroundColor: Colors.grey[200],
                  )).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchLocationController,
              decoration: InputDecoration(
                hintText: 'Search location',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: const Icon(LucideIcons.mapPin, size: 20, color: AppColors.primaryRed),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  final loc = _searchLocationController.text.trim();
                  if (loc.isNotEmpty && !_serviceAreas.contains(loc)) {
                    setState(() {
                      _serviceAreas = [..._serviceAreas, loc];
                      _searchLocationController.clear();
                    });
                  }
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryRed, side: const BorderSide(color: AppColors.primaryRed), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Add Area', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Website or Pages URL', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            const SizedBox(height: 8),
            TextField(controller: _websiteController, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
            const SizedBox(height: 16),
            Text('Add social links', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            const SizedBox(height: 8),
            _socialField('Instagram', LucideIcons.instagram, _socialInstagramController),
            const SizedBox(height: 8),
            _socialField('Facebook', LucideIcons.facebook, _socialFacebookController),
            const SizedBox(height: 8),
            _socialField('X', LucideIcons.twitter, _socialTwitterController),
            const SizedBox(height: 8),
            _socialField('LinkedIn', LucideIcons.linkedin, _socialLinkedinController),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: _saving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Text('provider.profile.save_change'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityInput() {
    return TextField(
      controller: _addressController,
      decoration: InputDecoration(
        hintText: 'City / Address',
        hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
        prefixIcon: const Icon(LucideIcons.mapPin, size: 20, color: AppColors.primaryRed),
        suffixIcon: _detectingCity
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)),
              )
            : IconButton(
                tooltip: 'Detect my city',
                onPressed: _detectCity,
                icon: const Icon(LucideIcons.locateFixed, color: AppColors.primaryRed, size: 20),
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain));
  }

  Widget _input({required TextEditingController controller, required String hint, required IconData icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryRed),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _labeledInput({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _uploadButton({required VoidCallback onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.upload, size: 18, color: AppColors.primaryRed),
      label: Text('Upload', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primaryRed), backgroundColor: AppColors.primaryRed.withValues(alpha: 0.08), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  Widget _socialField(String label, IconData icon, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'https://your social medialinks.com',
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryRed),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
