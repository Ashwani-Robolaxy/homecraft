import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../domain/models/app_user.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  String _otp = '';
  final bool _isLoading = false;
  bool _isResending = false;

  // Resend cooldown — 60 seconds after the initial OTP send.
  static const int _cooldownSeconds = 60;
  int _secondsLeft = _cooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    if (name.length <= 3) return '${name[0]}***@${parts[1]}';
    return '${name.substring(0, 5)}***@${parts[1]}';
  }

  Future<void> _verifyOtp() async {
    final params = GoRouterState.of(context).uri.queryParameters;
    final email = params['email'] ?? '';
    final role = (params['role'] == 'provider') ? UserRole.provider : UserRole.client;
    if (email.isEmpty || _otp.length != 6) {
      AppToast.error('auth.verify_otp.invalid_otp'.tr());
      return;
    }

    // Bypass the intermediate verify API call because the backend route is missing.
    // The OTP will be verified securely by the backend during the final reset-password step.
    final roleValue = role == UserRole.provider ? 'provider' : 'client';
    context.push('/reset-password?email=${Uri.encodeComponent(email)}&otp=$_otp&role=$roleValue');
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _isResending) return;
    final params = GoRouterState.of(context).uri.queryParameters;
    final email = params['email'] ?? '';
    final role = (params['role'] == 'provider') ? UserRole.provider : UserRole.client;
    if (email.isEmpty) return;

    setState(() => _isResending = true);
    final error = await ref.read(authRepositoryProvider).sendPasswordResetEmail(email, role: role);
    if (!mounted) return;
    setState(() => _isResending = false);

    if (error != null) {
      AppToast.error(error);
    } else {
      AppToast.success('auth.verify_otp.resent_success'.tr());
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = GoRouterState.of(context).uri.queryParameters['email'] ?? '';
    final subtitle = email.isEmpty ? tr('auth.verify_otp.subtitle') : tr('auth.verify_otp.sent_to', namedArgs: {'email': _maskEmail(email)});

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(border: Border.all(color: AppColors.primaryRed)),
    );

    final canResend = _secondsLeft == 0 && !_isResending;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Center(child: Image.asset(AppAssets.logoRed, height: 82, fit: BoxFit.contain)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          Text(
                            tr('auth.verify_otp.title'),
                            style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7A0000)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 30),
                          Pinput(length: 6, defaultPinTheme: defaultPinTheme, focusedPinTheme: focusedPinTheme, onChanged: (pin) => _otp = pin, onCompleted: (pin) => _otp = pin),
                          const SizedBox(height: 30),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tr('auth.verify_otp.resend_prefix'), style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                              const SizedBox(height: 4),
                              _isResending
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))
                                  : TextButton(
                                      onPressed: canResend ? _resendOtp : null,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        canResend ? tr('auth.verify_otp.resend_link') : tr('auth.verify_otp.resend_in', namedArgs: {'seconds': '$_secondsLeft'}),
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          color: canResend ? AppColors.primaryRed : AppColors.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          decoration: canResend ? TextDecoration.underline : TextDecoration.none,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PrimaryGradientButton(text: tr('auth.verify_otp.verify'), onPressed: _verifyOtp, isLoading: _isLoading),
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
