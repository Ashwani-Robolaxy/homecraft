import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import '../../domain/models/project.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({
    super.key,
    required this.project,
    this.bookingId,
  });

  final Project project;

  /// When non-null the screen is in "professional review" mode and shows
  /// Accept / Reject / Chat action buttons that operate on this booking.
  final int? bookingId;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _ds = BookingRemoteDatasource();
  bool _accepting = false;
  bool _rejecting = false;

  bool get _busy => _accepting || _rejecting;
  bool get _hasProfessionalActions => widget.bookingId != null;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await _ds.updateBookingStatus(widget.bookingId!, 'accepted');
      if (!mounted) return;
      AppToast.success('Booking accepted!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString()
          .replaceFirst('ApiException: ', '')
          .replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject this booking?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
          'The client will be notified that you are unavailable.',
          style: GoogleFonts.outfit(color: Colors.black54, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Reject', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _rejecting = true);
    try {
      await _ds.updateBookingStatus(widget.bookingId!, 'rejected');
      if (!mounted) return;
      AppToast.success('Booking rejected.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString()
          .replaceFirst('ApiException: ', '')
          .replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  void _openChat() {
    final uid = widget.project.clientUserId?.trim() ?? '';
    if (uid.isEmpty) {
      AppToast.info('Client information is not available.');
      return;
    }
    context.push('/chat',
        extra: ProfessionalChatArgs(
          clientUserId: uid,
          clientDisplayName: widget.project.clientDisplayName,
          isCurrentUserProfessional: true,
          projectId: widget.project.id,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: CommonAppBar(title: tr('details.title')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image ────────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: project.imageUrl != null &&
                            project.imageUrl!.startsWith('http')
                        ? Image.network(
                            project.imageUrl!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(),
                          )
                        : Image.asset(
                            project.imageUrl ?? AppAssets.homeHeaderBg,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 20),

                  // ── Title & Budget ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain),
                        ),
                      ),
                      if (project.budget != null &&
                          project.budget!.isNotEmpty)
                        Text(
                          project.budget!,
                          style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Category chip ─────────────────────────────────────
                  if (project.serviceType != null &&
                      project.serviceType!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        project.serviceType!,
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryRed),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Location & date ───────────────────────────────────
                  Row(
                    children: [
                      if (project.location.isNotEmpty) ...[
                        const Icon(LucideIcons.mapPin,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          project.location,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ],
                      if (project.location.isNotEmpty &&
                          project.date.isNotEmpty)
                        const SizedBox(width: 12),
                      if (project.date.isNotEmpty)
                        Text(
                          project.date.replaceAll('/', '-'),
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Description ───────────────────────────────────────
                  Text(
                    project.description,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textMain,
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Action buttons (professional mode) ─────────────────────
          if (_hasProfessionalActions)
            _buildProfessionalActions()
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfessionalActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          // Chat
          GestureDetector(
            onTap: _busy ? null : _openChat,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.messageCircle,
                  size: 22, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),

          // Reject
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: const BorderSide(
                    color: AppColors.primaryRed, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _rejecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed))
                  : Text('Reject',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),

          // Accept
          Expanded(
            child: ElevatedButton(
              onPressed: _busy ? null : _accept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238E10),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Accept',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        height: 220,
        color: Colors.grey[200],
        child: const Icon(LucideIcons.image,
            color: Colors.black12, size: 50),
      );
}
