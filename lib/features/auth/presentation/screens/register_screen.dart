import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../domain/models/app_user.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _termsAccepted = false;
  bool _isLoading = false;

  UserRole get _role {
    final role = GoRouterState.of(context).uri.queryParameters['role'];
    return role == 'provider' ? UserRole.provider : UserRole.client;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.validation.terms_required'.tr()), backgroundColor: AppColors.primaryRed),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.registerWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
      role: _role,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!.tr()), backgroundColor: AppColors.primaryRed),
      );
      return;
    }
    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    if (result.user!.isProvider) {
      context.go('/professional-setup');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30.0, bottom: 20.0),
              child: Image.asset(
                AppAssets.logoHorizontalRed,
                height: 45,
                errorBuilder: (context, error, stackTrace) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('H/', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 32, color: AppColors.primaryRed)),
                    Text('omeCraft', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryRed.withValues(alpha: 0.9))),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWhite,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(tr('auth.register.title'), style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF7A0000))),
                        const SizedBox(height: 8),
                        Text(tr('auth.register.subtitle'), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textMain.withValues(alpha: 0.7))),
                        const SizedBox(height: 30),
                        CustomTextField(
                          hintText: tr('auth.register.username'),
                          prefixIcon: LucideIcons.user,
                          controller: _nameController,
                          validator: AuthValidators.displayName,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          hintText: tr('auth.register.email'),
                          prefixIcon: LucideIcons.mail,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: AuthValidators.email,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          hintText: tr('auth.register.password'),
                          prefixIcon: LucideIcons.key,
                          isPassword: true,
                          controller: _passwordController,
                          validator: AuthValidators.password,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          hintText: tr('auth.register.confirm_password'),
                          prefixIcon: LucideIcons.key,
                          isPassword: true,
                          controller: _confirmPasswordController,
                          validator: (v) => AuthValidators.confirmPassword(v, _passwordController.text),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Checkbox(
                                value: _termsAccepted,
                                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                                activeColor: AppColors.primaryRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Outfit'),
                                  children: [
                                    TextSpan(text: tr('auth.register.terms_prefix')),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => context.push('/terms'),
                                        child: Text(tr('auth.register.terms_link'), style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, fontSize: 13, fontFamily: 'Outfit')),
                                      ),
                                    ),
                                    const TextSpan(text: ' & '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: () => context.push('/privacy'),
                                        child: Text(tr('auth.legal.privacy_title'), style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, fontSize: 13, fontFamily: 'Outfit')),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        PrimaryGradientButton(
                          text: tr('auth.register.button'),
                          onPressed: () => _submit(),
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(tr('auth.register.or_sign_in'), style: const TextStyle(color: AppColors.textSecondary))),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SocialButton(text: tr('auth.register.google_sign_in'), iconPath: 'google', onTap: () {}),
                        SocialButton(text: tr('auth.register.apple_sign_in'), iconPath: 'apple', onTap: () {}),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tr('auth.register.already_have'), style: const TextStyle(fontFamily: 'Outfit', fontSize: 14)),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: Text(tr('auth.register.login_link'), style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
