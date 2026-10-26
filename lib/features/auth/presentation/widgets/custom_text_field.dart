import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CustomTextField extends StatefulWidget {
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
  final String? Function(String?)? validator;

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
    this.validator,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  String _resolveText(String value) {
    if (!value.contains('.')) return value;
    final translated = value.tr();
    return translated == value ? value : translated;
  }

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPassword != oldWidget.isPassword) {
      _obscureText = widget.isPassword;
    }
  }

  @override
  Widget build(BuildContext context) {
    final obscureText = widget.isPassword ? _obscureText : false;
    return TextFormField(
      controller: widget.controller,
      obscureText: obscureText,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain),
      decoration: InputDecoration(
        hintText: _resolveText(widget.hintText),
        errorMaxLines: 3,
        errorStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryRed),
        prefixIcon: widget.prefixText != null
            ? Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  widget.prefixText!,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain, fontWeight: FontWeight.w600),
                ),
              )
            : (widget.prefixIcon != null ? Icon(widget.prefixIcon, color: AppColors.textSecondary, size: 20) : null),
        suffixIcon: widget.suffixIcon != null
            ? Icon(widget.suffixIcon, color: AppColors.textSecondary, size: 20)
            : (widget.isPassword
                  ? IconButton(
                      icon: Icon(_obscureText ? LucideIcons.eyeOff : LucideIcons.eye, color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    )
                  : null),
      ),
    );
  }
}
