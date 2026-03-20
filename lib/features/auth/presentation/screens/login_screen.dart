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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final roleParam = GoRouterState.of(context).uri.queryParameters['role'];
    final role = roleParam == 'provider'
        ? UserRole.provider
        : roleParam == 'client'
            ? UserRole.client
            : null;
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: role,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!.tr()),
          backgroundColor: AppColors.primaryRed,
        ),
      );
      return;
    }
    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    final user = result.user!;
    if (user.isProvider) {
      context.go('/provider-home');
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
              padding: const EdgeInsets.only(top: 40.0, bottom: 20.0),
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
                        Text(tr('auth.login.title'), style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF7A0000))),
                        const SizedBox(height: 8),
                        Text(tr('auth.login.subtitle'), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textSecondary.withValues(alpha: 0.8))),
                        const SizedBox(height: 30),
                        CustomTextField(
                          hintText: tr('auth.login.email'),
                          prefixIcon: LucideIcons.mail,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: AuthValidators.email,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          hintText: tr('auth.login.password'),
                          prefixIcon: LucideIcons.key,
                          isPassword: true,
                          controller: _passwordController,
                          validator: AuthValidators.password,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                    activeColor: AppColors.primaryRed,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(tr('auth.login.remember_me'), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                final role = GoRouterState.of(context).uri.queryParameters['role'];
                                context.push(role != null ? '/forgot-password?role=$role' : '/forgot-password');
                              },
                              child: Text(tr('auth.login.forget_password'), style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        PrimaryGradientButton(
                          text: tr('auth.login.button'),
                          onPressed: () => _submit(),
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(tr('auth.login.or_sign_in'), style: const TextStyle(color: AppColors.textSecondary))),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SocialButton(text: tr('auth.login.google_sign_in'), iconPath: 'google', onTap: () {}),
                        SocialButton(text: tr('auth.login.apple_sign_in'), iconPath: 'apple', onTap: () {}),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tr('auth.login.dont_have'), style: const TextStyle(fontFamily: 'Outfit', fontSize: 14)),
                            TextButton(
                              onPressed: () {
                                final role = GoRouterState.of(context).uri.queryParameters['role'];
                                context.push(role != null ? '/register?role=$role' : '/register');
                              },
                              child: Text(tr('auth.login.register_link'), style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 14)),
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
