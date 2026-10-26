import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
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
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = size.height * 0.48;

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
              height: headerHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.lightPrimary, AppColors.primaryRed, AppColors.darkPrimary],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.elliptical(400, 150), bottomRight: Radius.elliptical(400, 150)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(bottomLeft: Radius.elliptical(400, 150), bottomRight: Radius.elliptical(400, 150)),
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

          // Static Logo centered inside the red header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: headerHeight - topPadding,
                child: Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(35),
                    child: Image.asset(
                      AppAssets.logo,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          'H/',
                          style: GoogleFonts.playfairDisplay(fontSize: 75, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // PageView for Onboarding Pages (positioned below the red header to avoid overlap)
          Positioned(
            top: headerHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
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

          // Language Selector
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      context.setLocale(const Locale('en'));
                    },
                    style: TextButton.styleFrom(foregroundColor: context.locale.languageCode == 'en' ? AppColors.primaryRed : AppColors.textSecondary),
                    child: Text('English', style: GoogleFonts.outfit(fontWeight: context.locale.languageCode == 'en' ? FontWeight.bold : FontWeight.normal)),
                  ),
                  Text('|', style: GoogleFonts.outfit(color: AppColors.textSecondary.withValues(alpha: 0.5))),
                  TextButton(
                    onPressed: () {
                      context.setLocale(const Locale('fr'));
                    },
                    style: TextButton.styleFrom(foregroundColor: context.locale.languageCode == 'fr' ? AppColors.primaryRed : AppColors.textSecondary),
                    child: Text('Français', style: GoogleFonts.outfit(fontWeight: context.locale.languageCode == 'fr' ? FontWeight.bold : FontWeight.normal)),
                  ),
                ],
              ),
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
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w300, color: AppColors.textMain, height: 1.25),
          ),
          const SizedBox(height: 24),
          Text(
            tr('onboarding.subtitle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textSecondary, height: 1.5, fontWeight: FontWeight.w300),
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tr('onboarding.role_title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w400, color: AppColors.textMain, height: 1.3),
          ),
          const SizedBox(height: 12),
          Text(
            tr('onboarding.role_subtitle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryRed, letterSpacing: 0.2),
          ),
          const SizedBox(height: 32),

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
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!context.mounted) return;
                final user = ref.read(authStateNotifierProvider).currentUser;
                if (user != null) {
                  context.go(user.isProvider ? '/provider-home' : '/home');
                } else {
                  context.push('/login?role=client');
                }
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
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!context.mounted) return;
                final user = ref.read(authStateNotifierProvider).currentUser;
                if (user != null) {
                  context.go(user.isProvider ? '/provider-home' : '/home');
                } else {
                  context.push('/login?role=provider');
                }
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
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? null : Colors.white,
          gradient: isSelected ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.buttonGradientTop, AppColors.buttonGradientBottom]) : null,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? null : Border.all(color: AppColors.primaryRed.withValues(alpha: 0.15)),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: AppColors.primaryRed.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6))
            else
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : AppColors.primaryRed),
              child: Icon(icon, color: isSelected ? AppColors.primaryRed : Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(color: isSelected ? Colors.white : AppColors.textMain, fontSize: 18, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
