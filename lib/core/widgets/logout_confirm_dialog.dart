import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

Future<bool> showLogoutConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black45,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'logout_confirm_title'.tr(context: context),
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
      content: Text(
        'logout_confirm_message'.tr(context: context),
        style: GoogleFonts.outfit(color: Colors.black54, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'settings.cancel'.tr(context: context),
            style: GoogleFonts.outfit(color: Colors.black54),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            'logout_confirm_action'.tr(context: context),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
