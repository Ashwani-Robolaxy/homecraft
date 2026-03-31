import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

/// Expanded [SliverAppBar] hero used for both client and provider profile screens.
class ProfileHeroHeader extends StatelessWidget {
  const ProfileHeroHeader({
    super.key,
    required this.displayName,
    required this.expandT,
    required this.emptyNameFallback,
  });

  final String displayName;
  final double expandT;
  final String emptyNameFallback;

  /// Layout height for avatar + labels; [FittedBox] scales this down when the sliver is shorter (collapsing bar).
  static const double _nominalContentHeight = 208;

  @override
  Widget build(BuildContext context) {
    final name = displayName.isEmpty ? emptyNameFallback : displayName;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black,
                AppColors.primaryRed.withValues(alpha: 0.32),
                Colors.black,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: ProfileHeroWavesPainter())),
        SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Opacity(
                  opacity: expandT.clamp(0.0, 1.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: _nominalContentHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: const AssetImage('assets/images/cleaner_profile_1.png'),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
                                child: const Icon(Icons.check, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'provider.profile.verified'.tr(),
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ProfileHeroWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryRed.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.5, size.width, size.height * 0.35);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
