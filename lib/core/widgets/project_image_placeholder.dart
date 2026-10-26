import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Grey block + gallery icon when a project has no attachment (matches "My Project" cards).
class ProjectImagePlaceholder extends StatelessWidget {
  const ProjectImagePlaceholder({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.iconSize = 48,
    this.borderRadius,
  });

  final double height;
  final double width;
  final double iconSize;
  final BorderRadiusGeometry? borderRadius;

  static bool hasDisplayableUrl(String? url) {
    if (url == null) return false;
    final u = url.trim();
    if (u.isEmpty) return false;
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.image,
        size: iconSize,
        color: const Color(0xFF9E9E9E),
      ),
    );
  }
}
