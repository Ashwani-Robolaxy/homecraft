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
    this.verificationStatus = '',
  });

  final String displayName;
  final double expandT;
  final String emptyNameFallback;

  /// Raw status string from the API: "verified", "pending", "unverified", "rejected", or empty.
  final String verificationStatus;

  static const double _nominalContentHeight = 208;

  // ── Badge icon ──────────────────────────────────────────────────────────────
  IconData get _badgeIcon {
    switch (verificationStatus) {
      case 'verified':   return Icons.check;
      case 'pending':    return Icons.hourglass_top_rounded;
      case 'rejected':   return Icons.close;
      default:           return Icons.help_outline_rounded; // unverified / unknown
    }
  }

  Color get _badgeColor {
    switch (verificationStatus) {
      case 'verified':   return AppColors.primaryRed;
      case 'pending':    return const Color(0xFFE07800);
      case 'rejected':   return const Color(0xFF888888);
      default:           return const Color(0xFF888888);
    }
  }

  // ── Status label ────────────────────────────────────────────────────────────
  String _statusLabel() {
    switch (verificationStatus) {
      case 'verified':   return 'provider.profile.verified'.tr();
      case 'pending':    return 'Pending Verification';
      case 'rejected':   return 'Verification Rejected';
      default:
        // empty string means we haven't loaded yet → show nothing obvious
        return verificationStatus.isEmpty ? 'Unverified' : verificationStatus;
    }
  }

  Color _statusLabelColor() {
    switch (verificationStatus) {
      case 'verified': return Colors.white70;
      case 'pending':  return const Color(0xFFFFCC70);
      case 'rejected': return const Color(0xFFFF9090);
      default:         return Colors.white54;
    }
  }

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
                          // ── Avatar with dynamic status badge ────────────
                          Stack(
                            alignment: Alignment.bottomRight,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: const AssetImage(
                                      'assets/images/cleaner_profile_1.png'),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _badgeColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_badgeIcon,
                                    color: Colors.white, size: 18),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ── Display name ────────────────────────────────
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // ── Verification status pill ─────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _badgeColor.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _badgeColor.withOpacity(0.55),
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_badgeIcon,
                                    color: _statusLabelColor(), size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  _statusLabel(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _statusLabelColor(),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2,
        size.width * 0.5, size.height * 0.35);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.5, size.width, size.height * 0.35);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
