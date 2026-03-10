import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SocialButton extends StatelessWidget {
  final String text;
  final String iconPath;
  final VoidCallback onTap;

  const SocialButton({super.key, required this.text, required this.iconPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconPath.contains('apple') ? AppAssets.appleIcon : AppAssets.googleIcon,
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) => Icon(iconPath.contains('apple') ? LucideIcons.apple : LucideIcons.chrome, color: AppColors.textMain, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
