import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  String? _selectedRole;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Stack(
        children: [
          // Background Gradient matching Onboarding
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.52,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.lightPrimary, AppColors.primaryRed, AppColors.darkPrimary],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.elliptical(400, 180), bottomRight: Radius.elliptical(400, 180)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(bottomLeft: Radius.elliptical(400, 180), bottomRight: Radius.elliptical(400, 180)),
                child: Stack(
                  children: [
                    // Decorative Circles
                    _buildDecorativeCircle(top: 40, left: 40, size: 60, opacity: 0.1),
                    _buildDecorativeCircle(top: -20, right: 60, size: 100, opacity: 0.08),
                    _buildDecorativeCircle(top: 150, left: -30, size: 90, opacity: 0.05),
                    _buildDecorativeCircle(top: 120, right: -20, size: 120, opacity: 0.1),
                    _buildDecorativeCircle(bottom: 60, left: 80, size: 40, opacity: 0.06),
                    _buildDecorativeCircle(bottom: 40, right: 100, size: 50, opacity: 0.04),
                  ],
                ),
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header (Logo Image - Horizontal White)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Image.asset(
                    AppAssets.logoWhite,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'H/',
                          style: TextStyle(fontFamily: 'Playfair Display', fontSize: 32, color: AppColors.textWhite),
                        ),
                        Text(
                          'omeCraft',
                          style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textWhite.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center Circle Logo Overlay
                SizedBox(height: size.height * 0.05),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(40), // Added padding for the logo
                  child: Image.asset(
                    AppAssets.logo,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'H/',
                        style: TextStyle(fontFamily: 'Playfair Display', fontSize: 80, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 48),

                // White Card Context Area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: PageView(
                      controller: _pageController,
                      children: [
                        // Page 1
                        _buildPage1(context),
                        // Page 2
                        _buildPage2(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tr('onboarding.title'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.w300, color: AppColors.textMain),
          ),
          const SizedBox(height: 24),
          Text(
            tr('onboarding.subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, color: AppColors.textSecondary, height: 1.5, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 48),
          PrimaryGradientButton(
            width: 220,
            text: tr('onboarding.get_started'),
            onPressed: () {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPage2(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tr('onboarding.role_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textMain),
          ),
          const SizedBox(height: 16),
          Text(
            tr('onboarding.role_subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
          ),
          const SizedBox(height: 30),

          // Role Selection - Client
          _buildRoleButton(
            context: context,
            title: 'onboarding.client_role'.tr(),
            icon: LucideIcons.user,
            isSelected: _selectedRole == 'client',
            onTap: () {
              setState(() {
                _selectedRole = 'client';
              });
              // Navigate to auth
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) context.push('/login?role=client');
              });
            },
          ),
          const SizedBox(height: 16),

          // Role Selection - Provider
          _buildRoleButton(
            context: context,
            title: 'onboarding.provider_role'.tr(),
            icon: LucideIcons.hardHat,
            isSelected: _selectedRole == 'provider',
            onTap: () {
              setState(() {
                _selectedRole = 'provider';
              });
              // Navigate to auth
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) context.push('/login?role=provider');
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({required BuildContext context, required String title, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? null : Colors.white,
          gradient: isSelected ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.buttonGradientTop, AppColors.buttonGradientBottom]) : null,
          borderRadius: BorderRadius.circular(50),
          border: isSelected ? null : Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
          boxShadow: [if (isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : AppColors.primaryRed),
              child: Icon(icon, color: isSelected ? AppColors.primaryRed : Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: isSelected ? Colors.white : AppColors.textMain, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeCircle({double? top, double? left, double? right, double? bottom, required double size, required double opacity}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
