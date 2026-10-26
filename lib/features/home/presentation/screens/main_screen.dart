import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import 'appointment_screen.dart';
import 'favorites_screen.dart';
import 'message_screen.dart';
import 'search_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [const SearchScreen(), const FavoritesScreen(), const AppointmentScreen(), const MessageScreen(), const ProfileScreen()];

  void _onTabTap(int index) {
    ref.read(clientTabIndexProvider.notifier).setIndex(index);
    if (index == 4) {
      ref.read(authStateNotifierProvider).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(clientTabIndexProvider);
    return Scaffold(
      extendBody: true,
      body: _screens[selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reddish gradient fade above nav bar
          Container(
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.primaryRed.withValues(alpha: 0.18),
                  AppColors.primaryRed.withValues(alpha: 0.0),
                ],
              ),
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
                BottomNavigationBarItem(icon: const Icon(LucideIcons.search), label: tr('home.tabs.search')),
                BottomNavigationBarItem(icon: const Icon(LucideIcons.heart), label: tr('home.tabs.favorites')),
                BottomNavigationBarItem(icon: const Icon(LucideIcons.calendar), label: tr('home.tabs.appointment')),
                BottomNavigationBarItem(icon: const Icon(LucideIcons.messageCircle), label: tr('home.tabs.message')),
                BottomNavigationBarItem(icon: const Icon(LucideIcons.user), label: tr('home.tabs.profile')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
