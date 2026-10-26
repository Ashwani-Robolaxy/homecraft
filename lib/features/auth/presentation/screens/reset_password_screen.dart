import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/app_toast.dart';
import '../../domain/models/app_user.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final params = GoRouterState.of(context).uri.queryParameters;
    final email = params['email'] ?? '';
    final otp = params['otp'] ?? '';
    final role = (params['role'] == 'provider') ? UserRole.provider : UserRole.client;
    final password = _newPasswordController.text;
    if (password.length < 8) {
      AppToast.error('Password must be at least 8 characters.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      AppToast.error('Passwords do not match');
      return;
    }
    if (email.isEmpty || otp.isEmpty) {
      AppToast.error('Missing reset details. Please retry.');
      return;
    }
    setState(() => _isLoading = true);
    final error = await ref.read(authRepositoryProvider).resetPassword(
          email: email,
          otp: otp,
          password: password,
          role: role,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      AppToast.error(error);
      return;
    }
    final roleValue = role == UserRole.provider ? 'provider' : 'client';
    context.go('/login?role=$roleValue');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Center(
                child: Image.asset(
                  AppAssets.logoRed,
                  height: 82,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          Text(
                            tr('auth.reset_password.title'),
                            style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7A0000)),
                          ),
                          const SizedBox(height: 30),
                          CustomTextField(
                            hintText: tr('auth.reset_password.new_password_hint'),
                            prefixIcon: LucideIcons.key,
                            isPassword: true,
                            controller: _newPasswordController,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            hintText: tr('auth.reset_password.confirm_password_hint'),
                            prefixIcon: LucideIcons.key,
                            isPassword: true,
                            controller: _confirmPasswordController,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PrimaryGradientButton(
                      text: tr('auth.reset_password.button'),
                      onPressed: _submit,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
