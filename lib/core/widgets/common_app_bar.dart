import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showLogo;
  final bool showNotification;
  final int notificationCount;
  final VoidCallback? onBackPress;
  final PreferredSizeWidget? bottom;

  const CommonAppBar({super.key, required this.title, this.showBackButton = true, this.showLogo = true, this.showNotification = true, this.notificationCount = 1, this.onBackPress, this.bottom});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leadingWidth: showBackButton && showLogo ? 100 : (showBackButton || showLogo ? 56 : 0),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBackButton)
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textMain, size: 24),
                onPressed: onBackPress ?? () => context.pop(),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            if (showLogo)
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Image.asset(AppAssets.logo, height: 25, color: AppColors.primaryRed, errorBuilder: (context, error, stackTrace) => const SizedBox()),
              ),
          ],
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textMain),
      ),
      actions: [
        if (showNotification)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(LucideIcons.bell, color: AppColors.primaryRed, size: 24),
                if (notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.textMain, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        notificationCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
      bottom: bottom ?? const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 1));
}
