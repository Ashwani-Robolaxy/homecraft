import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import 'message_screen.dart';
import 'provider_home_screen.dart';
import 'calendar_management_screen.dart';
import '../../../profile/presentation/screens/provider_profile_screen.dart';

class ProviderMainScreen extends StatefulWidget {
  const ProviderMainScreen({super.key});

  @override
  State<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends State<ProviderMainScreen> {
  int _selectedIndex = 0;

  /// Build current tab screen without const so it rebuilds when locale changes.
  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
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
