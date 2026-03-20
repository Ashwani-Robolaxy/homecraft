import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../content/presentation/providers/content_provider.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Privacy Policy', showNotification: false),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                privacy.asData?.value.title.isNotEmpty == true ? privacy.asData!.value.title : 'Our Policy',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: privacy.when(
                    data: (d) => Text(
                      d.content,
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
                    ),
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )),
                    error: (_, __) => Text(
                      'Unable to load privacy policy right now.',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
