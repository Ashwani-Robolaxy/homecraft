import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class ProfessionalSetupScreen extends StatefulWidget {
  const ProfessionalSetupScreen({super.key});

  @override
  State<ProfessionalSetupScreen> createState() => _ProfessionalSetupScreenState();
}

class _ProfessionalSetupScreenState extends State<ProfessionalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSpecialty;
  final List<String> _serviceAreas = ['New York', 'Paris', 'Paris', 'New York', 'New York'];

  final List<Map<String, dynamic>> _specialties = [
    {'name': 'Carpenters', 'icon': LucideIcons.hammer},
    {'name': 'Painters', 'icon': LucideIcons.palette},
    {'name': 'Tiler', 'icon': LucideIcons.layoutGrid},
    {'name': 'Kitchen\'s specialist', 'icon': LucideIcons.utensilsCrossed},
    {'name': 'Piscinist ( pool maintenance )', 'icon': LucideIcons.waves},
    {'name': 'Exterior architect', 'icon': LucideIcons.home},
  ];

  @override
  Widget build(BuildContext context) {
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
              _buildTextField(hint: 'User name', icon: LucideIcons.user),
              const SizedBox(height: 12),
              _buildTextField(hint: 'Phone No.', icon: LucideIcons.phone),
              const SizedBox(height: 12),
              _buildTextField(hint: 'Address', icon: LucideIcons.mapPin),
              const SizedBox(height: 12),
              _buildDescriptionField(),

              const SizedBox(height: 32),
              _buildSectionTitle('Choose your specialty*'),
              _buildSpecialtyDropdown(),

              const SizedBox(height: 32),
              _buildSectionTitle('Company Info.'),
              _buildLabel('Company name*'),
              _buildTextField(hint: 'ABCD'),
              const SizedBox(height: 12),
              _buildLabel('Contact Mail*'),
              _buildTextField(hint: 'nessa@gmail.com'),
              const SizedBox(height: 12),
              _buildLabel('Address*'),
              _buildTextField(hint: 'Address', icon: LucideIcons.mapPin),
              const SizedBox(height: 12),
              _buildLabel('Postal Code'),
              _buildTextField(hint: '655545'),
              const SizedBox(height: 12),
              _buildLabel('SIRET number *'),
              _buildTextField(hint: '123456'),
              const SizedBox(height: 24),
              _buildUploadButton('Upload KBIS (Optional)'),

              const SizedBox(height: 32),
              _buildSectionTitle('Projects and Certification'),
              _buildLabel('Upload Projects'),
              _buildFileItem('Projects.jpg'),
              _buildUploadButton('Upload', hint: 'Add at least 3 file maximum 20 file'),
              const SizedBox(height: 24),
              _buildLabel('Upload Certificate'),
              _buildFileItem('Certificate.jpg'),
              _buildUploadButton('Upload', hint: 'Add at least 2 file'),

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
              _buildTextField(hint: 'https://yourpageurl.com'),
              const SizedBox(height: 24),
              _buildLabel('Add social links'),
              _buildSocialLinks(),

              const SizedBox(height: 48),
              PrimaryGradientButton(
                text: 'Submit',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    context.go('/provider-home');
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

  Widget _buildTextField({required String hint, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        decoration: InputDecoration(
          hintText: hint,
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

  Widget _buildUploadButton(String label, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(hint, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.primaryRed)),
          ),
      ],
    );
  }

  Widget _buildFileItem(String fileName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(fileName, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4A698C))),
          const Icon(LucideIcons.trash2, color: AppColors.primaryRed, size: 18),
        ],
      ),
    );
  }

  Widget _buildServiceAreaTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _serviceAreas.map((area) {
        return Container(
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
        );
      }).toList(),
    );
  }

  Widget _buildLocationSearch() {
    return TextFormField(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF7A0000), borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Column(
      children: [
        _buildSocialInput(LucideIcons.instagram),
        const SizedBox(height: 12),
        _buildSocialInput(LucideIcons.facebook),
        const SizedBox(height: 12),
        _buildSocialInput(LucideIcons.twitter),
        const SizedBox(height: 12),
        _buildSocialInput(LucideIcons.linkedin),
      ],
    );
  }

  Widget _buildSocialInput(IconData icon) {
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
