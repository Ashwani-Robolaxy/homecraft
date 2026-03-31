import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../domain/models/app_user.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_validators.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final roleParam = GoRouterState.of(context).uri.queryParameters['role'];
    final role = roleParam == 'provider' ? UserRole.provider : UserRole.client;
    final repo = ref.read(authRepositoryProvider);
    final errorKey = await repo.sendPasswordResetEmail(_emailController.text.trim(), role: role);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (errorKey != null) {
      AppToast.error(errorKey.tr());
    } else {
      AppToast.success('auth.forgot_password.success'.tr());
      final roleValue = role == UserRole.provider ? 'provider' : 'client';
      context.push(
        '/verify-otp?email=${Uri.encodeComponent(_emailController.text.trim())}&role=$roleValue',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain), onPressed: () => context.pop()),
                  const Spacer(),
                  Image.asset(
                    AppAssets.logoHorizontalRed,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) => const Text('HomeCraft', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Text(tr('auth.forgot_password.title'), style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7A0000))),
                            const SizedBox(height: 16),
                            Text(tr('auth.forgot_password.subtitle'), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8))),
                            const SizedBox(height: 30),
                            CustomTextField(
                              hintText: tr('auth.forgot_password.email_hint'),
                              prefixIcon: LucideIcons.mail,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: AuthValidators.email,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    PrimaryGradientButton(
                      text: tr('auth.forgot_password.continue'),
                      onPressed: () => _submit(),
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
