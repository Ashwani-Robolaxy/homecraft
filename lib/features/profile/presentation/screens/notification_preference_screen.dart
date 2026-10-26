import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/notification_preferences.dart';
import '../../../../core/widgets/common_app_bar.dart';

class NotificationPreferenceScreen extends StatefulWidget {
  const NotificationPreferenceScreen({super.key});

  @override
  State<NotificationPreferenceScreen> createState() => _NotificationPreferenceScreenState();
}

class _NotificationPreferenceScreenState extends State<NotificationPreferenceScreen> with WidgetsBindingObserver {
  bool _loading = true;
  bool _pushOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check every time user returns from system Settings.
    if (state == AppLifecycleState.resumed) {
      _checkSystemPermission();
    }
  }

  /// Reads the REAL system notification authorization status.
  ///
  /// On iOS, [Permission.notification] from permission_handler is unreliable —
  /// it doesn't correctly map UNUserNotificationCenter's authorization status.
  /// We use [FirebaseMessaging.getNotificationSettings()] on iOS instead,
  /// which directly queries UNUserNotificationCenter.
  Future<bool> _readSystemGranted() async {
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } else {
      return await Permission.notification.isGranted;
    }
  }

  Future<void> _checkSystemPermission() async {
    final isGranted = await _readSystemGranted();
    if (mounted) {
      setState(() => _pushOn = isGranted);
      await NotificationPreferences.setPushEnabled(isGranted);
    }
  }

  Future<void> _load() async {
    await _checkSystemPermission();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CommonAppBar(title: 'provider.profile.notification_preference_title'.tr(), showNotification: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'provider.profile.notification_method'.tr(),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 8),
                    Text('provider.profile.notification_method_hint'.tr(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, height: 1.35)),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'provider.profile.push_notification'.tr(),
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textMain),
                              ),
                              const SizedBox(height: 4),
                              Text('provider.profile.push_notification_hint'.tr(), style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
                            ],
                          ),
                        ),
                        SwitchTheme(
                          data: SwitchThemeData(
                            thumbColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return Colors.grey.shade400;
                            }),
                            trackColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.primaryRed;
                              }
                              return Colors.grey.shade300;
                            }),
                          ),
                          child: Switch.adaptive(
                            value: _pushOn,
                            onChanged: (v) async {
                              if (v) {
                                // On iOS, re-requesting permission is a no-op after first denial.
                                // Always open system settings so the user can grant it themselves.
                                if (Platform.isIOS) {
                                  await openAppSettings();
                                  // State will sync via didChangeAppLifecycleState on return.
                                } else {
                                  final status = await Permission.notification.request();
                                  if (status.isGranted) {
                                    setState(() => _pushOn = true);
                                    await NotificationPreferences.setPushEnabled(true);
                                  } else {
                                    await openAppSettings();
                                  }
                                }
                              } else {
                                // Can't programmatically revoke; send user to system settings.
                                await openAppSettings();
                                // State will sync via didChangeAppLifecycleState on return.
                              }
                            },
                          ),
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
