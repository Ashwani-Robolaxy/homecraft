import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_button.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

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
              padding: const EdgeInsets.only(top: 30.0, bottom: 20.0),
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
            ),

            // Main White Card
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
                          tr('auth.register.title'),
                          style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A0000), // Darker red from Figma
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          tr('auth.register.subtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: AppColors.textMain.withValues(alpha: 0.7)),
                        ),
                      ),
                      const SizedBox(height: 30),
                      CustomTextField(hintText: tr('auth.register.username'), prefixIcon: LucideIcons.user),
                      const SizedBox(height: 12),
                      CustomTextField(hintText: tr('auth.register.email'), prefixIcon: LucideIcons.mail),
                      const SizedBox(height: 12),
                      CustomTextField(hintText: tr('auth.register.password'), prefixIcon: LucideIcons.key, isPassword: true),
                      const SizedBox(height: 12),
                      CustomTextField(hintText: tr('auth.register.confirm_password'), prefixIcon: LucideIcons.key, isPassword: true),

                      const SizedBox(height: 16),
                      // Terms & Conditions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Checkbox(value: false, onChanged: (v) {}, activeColor: AppColors.primaryRed),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Outfit'),
                                children: [
                                  TextSpan(text: 'auth.register.terms_prefix'.tr()),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: () => context.push('/terms'),
                                      child: Text(
                                        'auth.register.terms_link'.tr(),
                                        style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, fontSize: 13, fontFamily: 'Outfit'),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' & '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: () => context.push('/privacy'),
                                      child: const Text(
                                        'Privacy Policy',
                                        style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, fontSize: 13, fontFamily: 'Outfit'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      PrimaryGradientButton(text: tr('auth.register.button'), onPressed: () => context.go('/home')),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(tr('auth.register.or_sign_in'), style: const TextStyle(color: AppColors.textSecondary)),
                          ),
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
                            child: Text(
                              tr('auth.register.login_link'),
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
