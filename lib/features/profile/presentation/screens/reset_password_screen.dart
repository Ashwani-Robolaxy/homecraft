import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _oldController.text.trim();
    final newPassword = _newController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (currentPassword.isEmpty) {
      AppToast.error('Enter your current password.');
      return;
    }
    if (newPassword.length < 8) {
      AppToast.error('New password must be at least 8 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      AppToast.error('New passwords do not match.');
      return;
    }
    if (newPassword == currentPassword) {
      AppToast.error('New password must be different from the current one.');
      return;
    }

    setState(() => _saving = true);
    final error = await ref.read(authRepositoryProvider).changePassword(currentPassword: currentPassword, newPassword: newPassword);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      AppToast.error(error);
      return;
    }
    AppToast.success('Password updated successfully.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset(AppAssets.subscriptionBackground, fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.62), Colors.black.withValues(alpha: 0.35), AppColors.primaryRed.withValues(alpha: 0.22)],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.18))),
            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: bottomInset + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAppBar(context),
                    const SizedBox(height: 24),
                    Center(
                      child: Image.asset(
                        AppAssets.logo,
                        height: 88,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Text(
                            'H/',
                            style: TextStyle(fontFamily: 'Playfair Display', fontSize: 56, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'settings.reset_password_title'.tr(),
                              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 24),
                            _buildPasswordField(controller: _oldController, hint: 'settings.enter_old_password'.tr(), obscure: _obscureOld, onToggle: () => setState(() => _obscureOld = !_obscureOld)),
                            const SizedBox(height: 16),
                            _buildPasswordField(controller: _newController, hint: 'settings.enter_new_password'.tr(), obscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew)),
                            const SizedBox(height: 16),
                            _buildPasswordField(
                              controller: _confirmController,
                              hint: 'settings.reenter_new_password'.tr(),
                              obscure: _obscureConfirm,
                              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: PrimaryGradientButton(text: 'settings.update_password'.tr(), onPressed: _submit, isLoading: _saving),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'settings.reset_password_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String hint, required bool obscure, required VoidCallback onToggle}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: !_saving,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: hint,

          hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
          prefixIcon: const Icon(LucideIcons.key, color: Colors.black45, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.black38, size: 20),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
