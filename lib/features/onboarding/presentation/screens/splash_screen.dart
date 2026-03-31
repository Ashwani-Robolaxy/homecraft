import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/startup_location_sync_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _locationSyncService = StartupLocationSyncService();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final user = ref.read(authStateNotifierProvider).currentUser;
      if (user != null) {
        // Best-effort startup location sync; do not block navigation.
        _locationSyncService.syncForUser(user).catchError((_) {});
        context.go(user.isProvider ? '/provider-home' : '/home');
      } else {
        context.go('/onboarding');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF330000), Color(0xFFFF0000), Color(0xFF330000)], stops: [0.0, 0.5, 1.0]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Logo (Horizontal White)
            Image.asset(
              AppAssets.logo,
              width: MediaQuery.of(context).size.width * 0.50,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'H/ HomeCraft',
                  style: TextStyle(fontFamily: 'Playfair Display', fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                );
              },
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
