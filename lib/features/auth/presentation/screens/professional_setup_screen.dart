import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../domain/models/provider_profile.dart';
import '../providers/auth_provider.dart';

class ProfessionalSetupScreen extends ConsumerStatefulWidget {
  const ProfessionalSetupScreen({super.key});

  @override
  ConsumerState<ProfessionalSetupScreen> createState() => _ProfessionalSetupScreenState();
}

class _ProfessionalSetupScreenState extends ConsumerState<ProfessionalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactMailController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _siretController = TextEditingController();
  final _websiteController = TextEditingController();
  final _searchLocationController = TextEditingController();
  final _socialInstagramController = TextEditingController();
  final _socialFacebookController = TextEditingController();
  final _socialTwitterController = TextEditingController();
  final _socialLinkedinController = TextEditingController();
  bool _dataLoaded = false;
  bool _saving = false;
  String? _selectedSpecialty;
  List<String> _serviceAreas = [];
  List<String> _kbisFiles = [];
  List<String> _projectFiles = [];
  List<String> _certificateFiles = [];

  final List<Map<String, dynamic>> _specialties = [
    {'name': 'Carpenters', 'icon': LucideIcons.hammer},
    {'name': 'Painters', 'icon': LucideIcons.palette},
    {'name': 'Tiler', 'icon': LucideIcons.layoutGrid},
    {'name': 'Kitchen\'s specialist', 'icon': LucideIcons.utensilsCrossed},
    {'name': 'Piscinist ( pool maintenance )', 'icon': LucideIcons.waves},
    {'name': 'Exterior architect', 'icon': LucideIcons.home},
  ];

  @override
  void dispose() {
    _userNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _contactMailController.dispose();
    _companyNameController.dispose();
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
        _kbisFiles = List.from(p.kbisExtractUrl == null || p.kbisExtractUrl!.isEmpty ? const [] : [p.kbisExtractUrl!]);
        _projectFiles = List.from(p.projectUploads);
        _certificateFiles = List.from(p.certificateUploads);
      }
    }
  }

  Future<void> _submitProfile() async {
    final displayName = _userNameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your name'), backgroundColor: AppColors.primaryRed));
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
      kbisExtractUrl: _kbisFiles.isEmpty ? null : _kbisFiles.first,
      projectUploads: _projectFiles,
      certificateUploads: _certificateFiles,
    );
    final result = await ref.read(authRepositoryProvider).updateProviderProfile(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.errorMessage != null) {
      _showSystematicError(result.errorMessage!);
      return;
    }
    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    context.go('/provider-home');
  }

  void _showSystematicError(String message) {
    final lines = message.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Please fix the following'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: lines.map((l) => Text('- $l')).toList()),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _pickFiles({required bool allowMultiple, required ValueChanged<List<String>> onPicked}) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: allowMultiple);
    if (result == null) return;
    final names = result.files.map((f) => f.name).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return;
    onPicked(names);
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Setup Profile', showNotification: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Personal Info.*'),
              _buildTextField(controller: _userNameController, hint: 'User name', icon: LucideIcons.user),
              const SizedBox(height: 12),
              _buildTextField(controller: _phoneController, hint: 'Phone No.', icon: LucideIcons.phone),
              const SizedBox(height: 12),
              _buildTextField(controller: _addressController, hint: 'Address', icon: LucideIcons.mapPin),
              const SizedBox(height: 12),
              _buildDescriptionField(),

              const SizedBox(height: 32),
              _buildSectionTitle('Choose your specialty*'),
              _buildSpecialtyDropdown(),

              const SizedBox(height: 32),
              _buildSectionTitle('Company Info.'),
              _buildLabel('Company name*'),
              _buildTextField(controller: _companyNameController, hint: 'Company name'),
              const SizedBox(height: 12),
              _buildLabel('Contact Mail*'),
              _buildTextField(controller: _contactMailController, hint: 'Contact email'),
              const SizedBox(height: 12),
              _buildLabel('Address*'),
              _buildTextField(controller: _companyAddressController, hint: 'Address', icon: LucideIcons.mapPin),
              const SizedBox(height: 12),
              _buildLabel('Postal Code'),
              _buildTextField(controller: _postalCodeController, hint: 'Postal code'),
              const SizedBox(height: 12),
              _buildLabel('SIRET number *'),
              _buildTextField(controller: _siretController, hint: 'SIRET number'),
              const SizedBox(height: 24),
              ..._kbisFiles.map((f) => _buildFileItem(f, onDelete: () => setState(() => _kbisFiles.remove(f)))),
              _buildUploadButton('Upload KBIS (Optional)', onTap: () => _pickFiles(allowMultiple: false, onPicked: (files) => setState(() => _kbisFiles = files.take(1).toList()))),

              const SizedBox(height: 32),
              _buildSectionTitle('Projects and Certification'),
              _buildLabel('Upload Projects'),
              ..._projectFiles.map((f) => _buildFileItem(f, onDelete: () => setState(() => _projectFiles.remove(f)))),
              _buildUploadButton(
                'Upload',
                hint: 'Add at least 3 file maximum 20 file',
                onTap: () => _pickFiles(allowMultiple: true, onPicked: (files) => setState(() => _projectFiles = [..._projectFiles, ...files].take(20).toList())),
              ),
              const SizedBox(height: 24),
              _buildLabel('Upload Certificate'),
              ..._certificateFiles.map((f) => _buildFileItem(f, onDelete: () => setState(() => _certificateFiles.remove(f)))),
              _buildUploadButton(
                'Upload',
                hint: 'Add at least 2 file',
                onTap: () => _pickFiles(allowMultiple: true, onPicked: (files) => setState(() => _certificateFiles = [..._certificateFiles, ...files])),
              ),

              const SizedBox(height: 32),
              _buildSectionTitle('Services Area and Social'),
              _buildLabel('Services Area'),
              _buildServiceAreaTags(),
              const SizedBox(height: 12),
              _buildLocationSearch(),
              const SizedBox(height: 12),
              _buildAddButton('Add Area'),
              const SizedBox(height: 24),
              _buildLabel('Website or Pages URL'),
              _buildTextField(controller: _websiteController, hint: 'https://yourpageurl.com'),
              const SizedBox(height: 24),
              _buildLabel('Add social links'),
              _buildSocialLinks(),

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
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
      ),
    );
  }

  Widget _buildTextField({String? hint, IconData? icon, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint ?? '',
          hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
          prefixIcon: icon != null ? Icon(icon, color: AppColors.primaryRed, size: 20) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryRed.withOpacity(0.1)),
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
        Text('Write short description about you.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54)),
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
              borderSide: BorderSide(color: AppColors.primaryRed.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 1),
            ),
            filled: true,
            fillColor: const Color(0xFFFCFCFC),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialtyDropdown() {
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
          hint: Text('Select...', style: GoogleFonts.outfit(color: Colors.black26, fontSize: 14)),
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 20, color: Colors.black45),
          items: _specialties.map((specialty) {
            return DropdownMenuItem<String>(
              value: specialty['name'],
              child: Row(
                children: [
                  Icon(specialty['icon'], color: AppColors.primaryRed, size: 20),
                  const SizedBox(width: 12),
                  Text(specialty['name'], style: GoogleFonts.outfit(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedSpecialty = value),
        ),
      ),
    );
  }

  Widget _buildUploadButton(String label, {String? hint, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFF2E7E7), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.upload, color: AppColors.primaryRed, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(hint, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.primaryRed)),
          ),
      ],
    );
  }

  Widget _buildFileItem(String fileName, {VoidCallback? onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(fileName, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4A698C))),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(LucideIcons.trash2, color: AppColors.primaryRed, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceAreaTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _serviceAreas.map((area) {
        return GestureDetector(
          onTap: () => setState(() => _serviceAreas.remove(area)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF2E7E7), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(area, style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                const SizedBox(width: 4),
                const Icon(LucideIcons.x, size: 12, color: Colors.black26),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationSearch() {
    return TextFormField(
      controller: _searchLocationController,
      decoration: InputDecoration(
        hintText: 'Search location',
        hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
        prefixIcon: const Icon(LucideIcons.search, color: Colors.black26, size: 20),
        suffixIcon: const Icon(LucideIcons.mapPin, color: AppColors.primaryRed, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryRed.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1),
        ),
        filled: true,
        fillColor: const Color(0xFFFCFCFC),
      ),
    );
  }

  Widget _buildAddButton(String text) {
    return GestureDetector(
      onTap: () {
        final loc = _searchLocationController.text.trim();
        if (loc.isNotEmpty && !_serviceAreas.contains(loc)) {
          setState(() {
            _serviceAreas = [..._serviceAreas, loc];
            _searchLocationController.clear();
          });
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF7A0000), borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Column(
      children: [
        _buildSocialInput(LucideIcons.instagram, _socialInstagramController),
        const SizedBox(height: 12),
        _buildSocialInput(LucideIcons.facebook, _socialFacebookController),
        const SizedBox(height: 12),
        _buildSocialInput(LucideIcons.twitter, _socialTwitterController),
        const SizedBox(height: 12),
        _buildSocialInput(LucideIcons.linkedin, _socialLinkedinController),
      ],
    );
  }

  Widget _buildSocialInput(IconData icon, TextEditingController controller) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFCFCFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryRed.withOpacity(0.1)),
          ),
          child: Icon(icon, color: Colors.black87, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'https://your social medialinks.com',
              hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryRed.withOpacity(0.1)),
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
      ],
    );
  }
}
