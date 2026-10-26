import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';

/// Expanded [SliverAppBar] hero used for both client and provider profile screens.
class ProfileHeroHeader extends StatelessWidget {
  const ProfileHeroHeader({
    super.key,
    required this.displayName,
    this.profilePhotoUrl,
    this.localProfilePhotoPath,
    this.avatarVersion,
    this.avatarNonce,
    required this.expandT,
    required this.emptyNameFallback,
    this.verificationStatus = '',
    this.showVerificationBadge = true,
  });

  final String displayName;
  final String? profilePhotoUrl;
  final String? localProfilePhotoPath;
  final int? avatarVersion;
  final int? avatarNonce;
  final double expandT;
  final String emptyNameFallback;

  /// Raw status from the API (e.g. `profile_incomplete`, `pending_verification`, `verified`).
  final String verificationStatus;

  /// When false, hides both the avatar badge icon and the status pill entirely.
  final bool showVerificationBadge;

  static const double _nominalContentHeight = 214;

  // ── Badge icon ──────────────────────────────────────────────────────────────
  IconData get _badgeIcon {
    switch (verificationStatus) {
      case 'verified':
        return Icons.check;
      case 'pending':
      case 'pending_verification':
        return Icons.hourglass_top_rounded;
      case 'profile_incomplete':
        return Icons.edit_note_rounded;
      case 'rejected':
        return Icons.close;
      case 'blocked':
        return Icons.block;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color get _badgeColor {
    switch (verificationStatus) {
      case 'verified':
        return AppColors.primaryRed;
      case 'pending':
      case 'pending_verification':
      case 'profile_incomplete':
        return const Color(0xFFE07800);
      case 'rejected':
        return const Color(0xFF888888);
      case 'blocked':
        return const Color(0xFF555555);
      default:
        return const Color(0xFF888888);
    }
  }

  // ── Status label ────────────────────────────────────────────────────────────
  String _statusLabel() {
    switch (verificationStatus) {
      case 'verified':
        return 'provider.profile.verified'.tr();
      case 'pending':
      case 'pending_verification':
        return 'provider.profile.pending_verification'.tr();
      case 'profile_incomplete':
        return 'provider.profile.profile_incomplete'.tr();
      case 'rejected':
        return 'provider.profile.verification_rejected'.tr();
      case 'blocked':
        return 'provider.profile.blocked'.tr();
      case '':
        return 'provider.profile.unverified'.tr();
      default:
        return _humanizeUnknownStatus(verificationStatus);
    }
  }

  String _humanizeUnknownStatus(String raw) {
    final parts = raw.split('_').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'provider.profile.unverified'.tr();
    return parts
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Color _statusLabelColor() {
    switch (verificationStatus) {
      case 'verified':
        return Colors.white70;
      case 'pending':
      case 'pending_verification':
      case 'profile_incomplete':
        return const Color(0xFFFFCC70);
      case 'rejected':
        return const Color(0xFFFF9090);
      case 'blocked':
        return const Color(0xFFCCCCCC);
      default:
        return Colors.white54;
    }
  }

  Widget _buildAvatar() {
    final imageUrl = _avatarUrlWithVersion();
    if (imageUrl == null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[300],
        backgroundImage: const AssetImage(AppAssets.profilePlaceholder),
      );
    }
    if (localProfilePhotoPath != null && localProfilePhotoPath!.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(localProfilePhotoPath!),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildNetworkAvatar(imageUrl),
        ),
      );
    }
    return _buildNetworkAvatar(imageUrl);
  }

  Widget _buildNetworkAvatar(String imageUrl) {
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          AppAssets.profilePlaceholder,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  String? _avatarUrlWithVersion() {
    final base = profilePhotoUrl?.trim();
    if (base == null || base.isEmpty) return null;
    final effectiveVersion = avatarVersion ?? avatarNonce;
    if (effectiveVersion == null || effectiveVersion == 0) return base;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}v=$effectiveVersion';
  }

  @override
  Widget build(BuildContext context) {
    final name = displayName.isEmpty ? emptyNameFallback : displayName;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            AppAssets.subscriptionBackground,
            fit: BoxFit.cover,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.52),
                AppColors.primaryRed.withValues(alpha: 0.42),
                const Color(0xFF2B0000).withValues(alpha: 0.70),
              ],
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: ProfileHeroWavesPainter())),
        // Bottom white curve transition into page body.
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: ClipPath(
              clipper: _ProfileBottomCurveClipper(curveT: expandT.clamp(0.0, 1.0)),
              child: Container(
                height: lerpDouble(0, 64, expandT.clamp(0.0, 1.0))!,
                color: Colors.white,
              ),
            ),
          ),
        ),
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
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Decorative rings behind avatar.
                              Container(
                                width: 136,
                                height: 136,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.34),
                                      Colors.white.withValues(alpha: 0.04),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 118,
                                height: 118,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle),
                                child: _buildAvatar(),
                              ),
                              Positioned(
                                right: 10,
                                bottom: 14,
                                child: showVerificationBadge
                                    ? Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _badgeColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.18),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(_badgeIcon,
                                            color: Colors.white, size: 18),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (showVerificationBadge)
                                Positioned(
                                  top: 4,
                                  left: -6,
                                  child: _glowDot(10, 0.32),
                                ),
                              if (showVerificationBadge)
                                Positioned(
                                  top: -4,
                                  right: 12,
                                  child: _glowDot(6, 0.22),
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

                          // ── Verification status pill ─────────────────────
                          if (showVerificationBadge) ...[
                            const SizedBox(height: 6),
                            Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _badgeColor.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _badgeColor.withValues(alpha: 0.55),
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

  Widget _glowDot(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class ProfileHeroWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()
      ..color = AppColors.primaryRed.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final front = Paint()
      ..color = AppColors.primaryRed.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;

    // Gentle top ribbon, mostly flat at the sides.
    final topRibbon = Path()..moveTo(0, size.height * 0.16);
    topRibbon.cubicTo(
      size.width * 0.22,
      size.height * 0.08,
      size.width * 0.40,
      size.height * 0.22,
      size.width * 0.50,
      size.height * 0.18,
    );
    topRibbon.cubicTo(
      size.width * 0.62,
      size.height * 0.14,
      size.width * 0.80,
      size.height * 0.08,
      size.width,
      size.height * 0.14,
    );
    topRibbon.lineTo(size.width, 0);
    topRibbon.lineTo(0, 0);
    topRibbon.close();
    canvas.drawPath(topRibbon, back);

    // Very subtle center swell to support the avatar area.
    final centerSwell = Path()..moveTo(0, size.height * 0.34);
    centerSwell.cubicTo(
      size.width * 0.24,
      size.height * 0.28,
      size.width * 0.42,
      size.height * 0.44,
      size.width * 0.50,
      size.height * 0.40,
    );
    centerSwell.cubicTo(
      size.width * 0.60,
      size.height * 0.36,
      size.width * 0.78,
      size.height * 0.30,
      size.width,
      size.height * 0.34,
    );
    centerSwell.lineTo(size.width, size.height);
    centerSwell.lineTo(0, size.height);
    centerSwell.close();
    canvas.drawPath(centerSwell, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileBottomCurveClipper extends CustomClipper<Path> {
  const _ProfileBottomCurveClipper({required this.curveT});

  final double curveT;

  @override
  Path getClip(Size size) {
    final t = curveT.clamp(0.0, 1.0);
    final edgeY = lerpDouble(0, size.height * 0.10, t)!;
    final leftFlatY = lerpDouble(0, size.height * 0.08, t)!;
    final dipY = lerpDouble(0, size.height * 0.92, t)!;
    final rightFlatY = lerpDouble(0, size.height * 0.08, t)!;

    final path = Path()..moveTo(0, edgeY);
    // Localized center dip directly below the avatar area.
    path.cubicTo(
      size.width * 0.18,
      leftFlatY,
      size.width * 0.36,
      dipY,
      size.width * 0.50,
      dipY,
    );
    path.cubicTo(
      size.width * 0.64,
      dipY,
      size.width * 0.82,
      rightFlatY,
      size.width,
      edgeY,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ProfileBottomCurveClipper oldClipper) =>
      oldClipper.curveT != curveT;
}
