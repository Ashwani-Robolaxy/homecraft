import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_button.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Logo
            Padding(
              padding: const EdgeInsets.only(top: 40.0, bottom: 20.0),
              child: Image.asset(
                AppAssets.logoHorizontalRed,
                height: 45,
                errorBuilder: (context, error, stackTrace) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'H/',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 32, color: AppColors.primaryRed),
                    ),
                    Text(
                      'omeCraft',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryRed.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ), // Main White Card
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
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                          tr('auth.login.title'),
                          style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF7A0000)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          tr('auth.login.subtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                        ),
                      ),
                      const SizedBox(height: 30),
                      CustomTextField(hintText: tr('auth.login.email'), prefixIcon: LucideIcons.mail),
                      const SizedBox(height: 16),
                      CustomTextField(hintText: tr('auth.login.password'), prefixIcon: LucideIcons.key, isPassword: true),

                      const SizedBox(height: 16),
                      // Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(value: true, onChanged: (v) {}, activeColor: AppColors.primaryRed),
                              ),
                              const SizedBox(width: 8),
                              Text(tr('auth.login.remember_me'), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push('/forgot-password'),
                            child: Text(
                              tr('auth.login.forget_password'),
                              style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
                      PrimaryGradientButton(
                        text: tr('auth.login.button'),
                        onPressed: () {
                          final role = GoRouterState.of(context).uri.queryParameters['role'];
                          if (role == 'provider') {
                            context.go('/professional-setup');
                          } else {
                            context.go('/home');
                          }
                        },
                      ),

                      const SizedBox(height: 30),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(tr('auth.login.or_sign_in'), style: const TextStyle(color: AppColors.textSecondary)),
                          ),
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
                            onPressed: () => context.push('/register'),
                            child: Text(
                              tr('auth.login.register_link'),
                              style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
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
