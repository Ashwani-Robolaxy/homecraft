import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'message_screen.dart';
import 'provider_home_screen.dart';
import 'calendar_management_screen.dart';
import '../../../profile/presentation/screens/provider_profile_screen.dart';

class ProviderMainScreen extends ConsumerStatefulWidget {
  const ProviderMainScreen({super.key});

  @override
  ConsumerState<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends ConsumerState<ProviderMainScreen> {
  /// Build current tab screen without const so it rebuilds when locale changes.
  Widget _buildCurrentScreen(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return ProviderHomeScreen();
      case 1:
        return MessageScreen();
      case 2:
        return CalendarManagementScreen();
      case 3:
        return ProviderProfileScreen();
      default:
        return ProviderHomeScreen();
    }
  }

  void _onTabTap(int index) {
    ref.read(providerTabIndexProvider.notifier).setIndex(index);
    if (index == 3) {
      ref.read(authStateNotifierProvider).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(providerTabIndexProvider);
    return Scaffold(
      extendBody: true,
      body: _buildCurrentScreen(selectedIndex),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reddish gradient fade above nav bar
          Container(
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.primaryRed.withValues(alpha: 0.18), AppColors.primaryRed.withValues(alpha: 0.0)]),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: _onTabTap,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: AppColors.primaryRed,
              unselectedItemColor: AppColors.textSecondary,
              selectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 10),
              items: [
                BottomNavigationBarItem(icon: const Icon(LucideIcons.layers), label: 'provider.nav.project'.tr()),
                BottomNavigationBarItem(icon: const Icon(LucideIcons.messageCircle), label: 'provider.nav.message'.tr()),
                BottomNavigationBarItem(icon: const Icon(LucideIcons.calendar), label: 'provider.nav.calendar'.tr()),
                BottomNavigationBarItem(icon: const Icon(LucideIcons.user), label: 'provider.nav.profile'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: title, showBackButton: false, showNotification: false),
      body: Center(child: Text('$title Screen Placeholder')),
    );
  }
}
