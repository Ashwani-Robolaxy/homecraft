import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';

class NotificationPreferenceScreen extends StatefulWidget {
  const NotificationPreferenceScreen({super.key});

  @override
  State<NotificationPreferenceScreen> createState() => _NotificationPreferenceScreenState();
}

class _NotificationPreferenceScreenState extends State<NotificationPreferenceScreen> {
  bool _emailOn = true;
  bool _pushOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CommonAppBar(title: 'provider.profile.notification_preference_title'.tr(), showNotification: false),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('provider.profile.notification_method'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('provider.profile.email'.tr(), style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textMain)),
                  Switch(
                    value: _emailOn,
                    onChanged: (v) => setState(() => _emailOn = v),
                    activeColor: const Color(0xFF4CAF50),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('provider.profile.push_notification'.tr(), style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textMain)),
                  Switch(
                    value: _pushOn,
                    onChanged: (v) => setState(() => _pushOn = v),
                    activeColor: AppColors.primaryRed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
