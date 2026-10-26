import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showLogo;
  final bool showNotification;
  final int notificationCount;
  /// When [showNotification] is true, called when the bell is tapped. Defaults to `/notifications`.
  final VoidCallback? onNotificationTap;
  final VoidCallback? onBackPress;
  final PreferredSizeWidget? bottom;
  final List<Widget>? trailingActions;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.showLogo = true,
    this.showNotification = true,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.onBackPress,
    this.bottom,
    this.trailingActions,
  });

  String _resolveText(String value) {
    if (!value.contains('.')) return value;
    final translated = value.tr();
    return translated == value ? value : translated;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
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
        _resolveText(title),
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textMain),
      ),
      actions: [
        ...?trailingActions,
        if (showNotification)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: onNotificationTap ?? () => context.push('/notifications'),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
              icon: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    notificationCount > 0 ? LucideIcons.bellRing : LucideIcons.bell,
                    color: AppColors.primaryRed,
                    size: 24,
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: -2,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: const BoxDecoration(color: AppColors.textMain, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          notificationCount > 99 ? '99+' : '$notificationCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
      bottom: bottom ?? const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 1));
}
