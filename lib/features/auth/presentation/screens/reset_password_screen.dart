import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

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
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  Image.asset(
                    AppAssets.logoHorizontalRed,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'HomeCraft',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                    ),
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
                      child: Column(
                        children: [
                          Text(
                            tr('auth.reset_password.title'),
                            style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7A0000)),
                          ),
                          const SizedBox(height: 30),
                          CustomTextField(hintText: tr('auth.reset_password.new_password_hint'), prefixIcon: LucideIcons.key, isPassword: true),
                          const SizedBox(height: 16),
                          CustomTextField(hintText: tr('auth.reset_password.confirm_password_hint'), prefixIcon: LucideIcons.key, isPassword: true),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PrimaryGradientButton(text: tr('auth.reset_password.button'), onPressed: () => context.go('/home')),
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
