import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../content/presentation/providers/content_provider.dart';

import '../../../../core/widgets/common_app_bar.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  bool _isAgreed = false;

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(privacyProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: const CommonAppBar(title: 'Privacy Policy', showLogo: false, showNotification: false),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our Policy',
                    style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: SingleChildScrollView(
                        child: privacy.when(
                          data: (data) => Text(
                            data.content,
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                          ),
                          loading: () => const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(color: AppColors.primaryRed),
                          )),
                          error: (_, __) => const Text(
                            'Unable to load privacy policy right now.',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: _isAgreed,
                          activeColor: AppColors.primaryRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (value) {
                            setState(() {
                              _isAgreed = value ?? false;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tr('auth.legal.agree_text'),
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
