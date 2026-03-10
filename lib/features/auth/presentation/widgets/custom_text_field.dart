import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final String? prefixText;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.prefixText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixText != null
            ? Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  prefixText!,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain, fontWeight: FontWeight.w600),
                ),
              )
            : (prefixIcon != null ? Icon(prefixIcon, color: AppColors.textSecondary, size: 20) : null),
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AppColors.textSecondary, size: 20) : (isPassword ? const Icon(LucideIcons.eyeOff, color: AppColors.textSecondary, size: 20) : null),
      ),
    );
  }
}
