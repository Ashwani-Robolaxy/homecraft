import 'package:flutter/material.dart';
import '../../../../core/widgets/common_app_bar.dart';

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  final List<String> _mediaImages = const [
    'assets/images/cleaner_profile_1.png',
    'assets/images/home_header_bg.png',
    'assets/images/professional_cleaner_male.png',
    'assets/images/professional_painter_female.png',
    'assets/images/professional_plumber_male.png',
    'assets/images/logo_white.png', // Placeholder for more variety
    'assets/images/cleaner_profile_1.png',
    'assets/images/home_header_bg.png',
    'assets/images/professional_cleaner_male.png',
    'assets/images/professional_painter_female.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CommonAppBar(title: 'Media', showBackButton: true, showLogo: true, showNotification: true, notificationCount: 1),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mediaImages.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: AssetImage(_mediaImages[index]), fit: BoxFit.cover, onError: (e, s) => const AssetImage('assets/images/logo_placeholder.png')),
            ),
          );
        },
      ),
    );
  }
}
