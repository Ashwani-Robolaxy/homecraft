import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../content/presentation/providers/content_provider.dart';

class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(termsProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: const CommonAppBar(title: 'Terms of Services', showLogo: false, showNotification: false),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our Terms of Services',
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
                        child: terms.when(
                          data: (data) => Text(
                            data.content,
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                          ),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(color: AppColors.primaryRed),
                            ),
                          ),
                          error: (_, __) => const Text(
                            'Unable to load terms right now.',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
