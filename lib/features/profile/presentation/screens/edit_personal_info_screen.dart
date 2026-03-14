import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
  final _companyNameController = TextEditingController(text: 'ABCD');
  final _contactMailController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _postalCodeController = TextEditingController(text: '655545');
  final _siretController = TextEditingController(text: '123456');
  final _websiteController = TextEditingController(text: 'https://yourpageurl.com');
  final _searchLocationController = TextEditingController();
  final List<String> _serviceAreas = ['New York', 'Paris', 'Pune', 'New Delhi', 'New York'];
  final List<String> _uploadedProjects = ['Projects.jpg'];
  final List<String> _uploadedCerts = ['Certificate.jpg'];
  String? _selectedSpecialty;
  bool _dataLoaded = false;
  bool _saving = false;

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
    super.dispose();
  }

  void _loadUserData() {
    if (_dataLoaded) return;
    _dataLoaded = true;
    final user = ref.read(authStateNotifierProvider).currentUser;
    if (user != null) {
      _userNameController.text = user.displayName;
      _contactMailController.text = user.email;
    }
  }

  Future<void> _saveProfile() async {
    final displayName = _userNameController.text.trim();
    if (displayName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.validation.username_required'.tr()), backgroundColor: AppColors.primaryRed),
        );
      }
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.updateProfile(displayName: displayName);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!.tr()), backgroundColor: AppColors.primaryRed),
      );
      return;
    }
    await ref.read(authStateNotifierProvider).refresh();
    if (mounted) context.pop();
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_selectedSpecialty ?? 'Select...', style: GoogleFonts.outfit(fontSize: 14, color: _selectedSpecialty != null ? AppColors.textMain : Colors.black38)),
                  const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.textSecondary),
                ],
              ),
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {},
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
            _uploadButton(onPressed: () {}),
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
            _uploadButton(onPressed: () {}),
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
                onPressed: () {},
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
            _socialField('Instagram', LucideIcons.instagram),
            const SizedBox(height: 8),
            _socialField('Facebook', LucideIcons.facebook),
            const SizedBox(height: 8),
            _socialField('X', LucideIcons.twitter),
            const SizedBox(height: 8),
            _socialField('LinkedIn', LucideIcons.linkedin),
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

  Widget _socialField(String label, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'https://your social medialinks.com',
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryRed),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
