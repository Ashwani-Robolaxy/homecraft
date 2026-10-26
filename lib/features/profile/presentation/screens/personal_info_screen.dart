import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _userNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _session = SessionStorage();
  bool _saving = false;
  bool _profileLoading = true;
  String? _pendingPhotoPath;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateNotifierProvider).currentUser;
    if (user != null) {
      _applyUserToControllers(user);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfileFromApi());
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _applyUserToControllers(AppUser user) {
    _userNameController.text = user.username ?? '';
    final parts = user.displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    _firstNameController.text = parts.isNotEmpty ? parts.first : '';
    _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _phoneController.text = user.phone ?? '';
  }

  Future<void> _refreshProfileFromApi() async {
    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    // Only update the loading flag — do NOT reset text controllers here,
    // otherwise typed edits get wiped when the API response arrives.
    setState(() => _profileLoading = false);
  }

  Future<void> _updateProfile() async {
    final username = _userNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty) {
      AppToast.error('First name is required.');
      return;
    }
    final displayName = lastName.isNotEmpty ? '$firstName $lastName' : firstName;
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && phone.length != 10) {
      AppToast.error('Enter a valid 10-digit phone number.');
      return;
    }
    setState(() => _saving = true);
    final existingCity = ref.read(authStateNotifierProvider).currentUser?.city;
    final result = _pendingPhotoPath != null
        ? await ref.read(authRepositoryProvider).updateClientProfilePhoto(
              _pendingPhotoPath!,
              displayName: displayName,
              username: username.isEmpty ? null : username,
              phone: phone.isEmpty ? null : phone,
              city: existingCity,
            )
        : await ref.read(authRepositoryProvider).updateProfile(
              displayName: displayName,
              username: username.isEmpty ? null : username,
              phone: phone.isEmpty ? null : phone,
              city: existingCity,
            );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.errorMessage != null) {
      AppToast.error(result.errorMessage!);
      return;
    }
    if (_pendingPhotoPath != null && _pendingPhotoPath!.isNotEmpty) {
      await _session.setLocalProfilePhotoPath(_pendingPhotoPath!);
    }
    _pendingPhotoPath = null;
    // Signal ProfileScreen to reload photo + user data immediately.
    ref.read(profileRefreshTriggerProvider.notifier).trigger();
    if (!mounted) return;
    AppToast.success('Profile updated.');
    // Select the profile tab then go to the home shell so the back stack is clean.
    ref.read(clientTabIndexProvider.notifier).setIndex(4);
    context.go('/home');
  }

  Future<void> _pickPhoto() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final path = picked.files.single.path;
    if (path == null || path.isEmpty) {
      AppToast.error('Could not read the selected image.');
      return;
    }
    await _session.setLocalProfilePhotoPath(path);
    setState(() => _pendingPhotoPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateNotifierProvider).currentUser;
    final displayName = user?.displayName ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Personal Info', showNotification: false),
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(child: _buildProfileImage(user)),
                    const SizedBox(height: 12),
                    Text(
                      displayName.isEmpty ? '—' : displayName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black12),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(label: 'User Name', controller: _userNameController),
                    const SizedBox(height: 20),
                    _buildTextField(label: 'client_profile.first_name'.tr(), controller: _firstNameController),
                    const SizedBox(height: 20),
                    _buildTextField(label: 'client_profile.last_name'.tr(), controller: _lastNameController),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'client_profile.phone'.tr(),
                      controller: _phoneController,
                      digitsPhone: true,
                    ),
                    if (_profileLoading) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Material(
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: PrimaryGradientButton(
              text: 'client_profile.update_profile'.tr(),
              onPressed: _updateProfile,
              isLoading: _saving,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(AppUser? user) {
    final photo = user?.profilePhotoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final hasPickedPhoto = _pendingPhotoPath != null && _pendingPhotoPath!.isNotEmpty;

    final Widget avatarChild = hasPickedPhoto
        ? ClipOval(
            child: Image.file(
              File(_pendingPhotoPath!),
              width: 140,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const CircleAvatar(
                radius: 70,
                backgroundImage: AssetImage(AppAssets.profilePlaceholder),
              ),
            ),
          )
        : hasPhoto
        ? ClipOval(
            child: Image.network(
              photo,
              width: 140,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const CircleAvatar(
                radius: 70,
                backgroundImage: AssetImage(AppAssets.profilePlaceholder),
              ),
            ),
          )
        : const CircleAvatar(
            radius: 70,
            backgroundImage: AssetImage(AppAssets.profilePlaceholder),
          );

    // Pencil is [Positioned] so it wins hit tests over the avatar; no shared Stack alignment with the big circle.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
          ),
          child: avatarChild,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _saving ? null : _pickPhoto,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Icon(
                LucideIcons.pencil,
                size: 20,
                color: _saving ? Colors.black26 : Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool digitsPhone = false,
  }) {
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
          keyboardType: digitsPhone ? TextInputType.phone : TextInputType.text,
          inputFormatters: digitsPhone
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]
              : null,
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
}
