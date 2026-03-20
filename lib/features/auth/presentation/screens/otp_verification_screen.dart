import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
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
  bool _isLoading = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP'), backgroundColor: AppColors.primaryRed),
      );
      return;
    }
    setState(() => _isLoading = true);
    final error = await ref.read(authRepositoryProvider).verifyResetOtp(
          email: email,
          otp: _otp,
          role: role,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.primaryRed),
      );
      return;
    }
    final roleValue = role == UserRole.provider ? 'provider' : 'client';
    context.push(
      '/reset-password?email=${Uri.encodeComponent(email)}&otp=$_otp&role=$roleValue',
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = GoRouterState.of(context).uri.queryParameters['email'] ?? '';
    final subtitle = email.isEmpty
        ? tr('auth.verify_otp.subtitle')
        : 'We have sent an OTP code to your email\n${_maskEmail(email)}.';
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
                          Pinput(
                            length: 6,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: focusedPinTheme,
                            onChanged: (pin) => _otp = pin,
                            onCompleted: (pin) => _otp = pin,
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tr('auth.verify_otp.resend_prefix'), style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  tr('auth.verify_otp.resend_link'),
                                  style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PrimaryGradientButton(
                      text: tr('auth.verify_otp.verify'),
                      onPressed: _verifyOtp,
                      isLoading: _isLoading,
                    ),
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
