import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import 'appointment_screen.dart';
import 'favorites_screen.dart';
import 'message_screen.dart';
import 'search_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [const SearchScreen(), const FavoritesScreen(), const AppointmentScreen(), const MessageScreen(), const ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
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
            BottomNavigationBarItem(icon: const Icon(LucideIcons.search), label: tr('home.tabs.search')),
            BottomNavigationBarItem(icon: const Icon(LucideIcons.heart), label: tr('home.tabs.favorites')),
            BottomNavigationBarItem(icon: const Icon(LucideIcons.calendar), label: 'Track Appointment'),
            BottomNavigationBarItem(icon: const Icon(LucideIcons.messageCircle), label: tr('home.tabs.message')),
            BottomNavigationBarItem(icon: const Icon(LucideIcons.user), label: tr('home.tabs.profile')),
          ],
        ),
      ),
    );
  }
}
