import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../booking/domain/models/booking.dart';
import '../../../chat/presentation/professional_chat_args.dart';

class AcceptedProjectsScreen extends StatefulWidget {
  const AcceptedProjectsScreen({super.key});

  @override
  State<AcceptedProjectsScreen> createState() => _AcceptedProjectsScreenState();
}

class _AcceptedProjectsScreenState extends State<AcceptedProjectsScreen> {
  final _ds = BookingRemoteDatasource();

  List<Booking> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _ds.fetchProfessionalBookings(status: 'accepted');
      if (!mounted) return;
      setState(() { _bookings = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: CommonAppBar(
        title: 'provider.profile.accepted_projects'.tr(),
        showNotification: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primaryRed,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _Shimmer();
    if (_error != null) return _buildError();
    if (_bookings.isEmpty) return _buildEmpty();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _bookings.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Accepted (${_bookings.length})',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E8B47),
              ),
            ),
          );
        }
        final booking = _bookings[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _BookingCard(booking: booking),
        );
      },
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.wifiOff, size: 48, color: Colors.black26),
                const SizedBox(height: 14),
                Text(
                  _error ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.black45, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.09),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.clipboardCheck,
                      color: AppColors.primaryRed, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Accepted Projects Yet',
                  style: GoogleFonts.outfit(
                      fontSize: 19, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'When a client books you and you accept, the project will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.black45, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = booking.clientPhoto != null && booking.clientPhoto!.isNotEmpty;
    final photoUrl = hasPhoto ? _resolveUrl(booking.clientPhoto!) : null;

    final dateStr = booking.scheduledDate != null
        ? _fmtDate(booking.scheduledDate!)
        : null;
    final timeStr = _buildTime(booking.slotStart, booking.slotEnd);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header strip ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E8B47).withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Client avatar
                ClipOval(
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.clientName ?? 'Client',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Booking #${booking.id}',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E8B47),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACCEPTED',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Details ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateStr != null || timeStr != null)
                  _infoRow(
                    LucideIcons.calendar,
                    [if (dateStr != null) dateStr, if (timeStr != null) timeStr]
                        .join('  ·  '),
                    const Color(0xFF2E8B47),
                  ),
                if (booking.location != null &&
                    booking.location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(LucideIcons.mapPin, booking.location!,
                      Colors.black54),
                ],
                if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                      LucideIcons.fileText, booking.notes!, Colors.black54),
                ],
                if (booking.projectId != null &&
                    booking.projectId!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(LucideIcons.folder,
                      'Project #${booking.projectId}', Colors.black45),
                ],
                const SizedBox(height: 14),
                // ── Action row ───────────────────────────────────────────
                Row(
                  children: [
                    // Message client
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(
                          '/chat',
                          extra: ProfessionalChatArgs(
                            clientUserId: booking.clientId ?? '',
                            clientDisplayName: booking.clientName ?? 'Client',
                            isCurrentUserProfessional: true,
                            projectId: booking.projectId,
                          ),
                        ),
                        icon: const Icon(LucideIcons.messageCircle, size: 16),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          textStyle: GoogleFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Accepted label (right side)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(LucideIcons.checkCircle, size: 16),
                        label: const Text('Accepted'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E8B47),
                          disabledForegroundColor: const Color(0xFF2E8B47),
                          side: const BorderSide(color: Color(0xFF2E8B47)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: GoogleFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: color, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _avatarFallback() => Container(
        width: 42,
        height: 42,
        color: AppColors.primaryRed.withOpacity(0.12),
        child: const Icon(LucideIcons.user,
            size: 22, color: AppColors.primaryRed),
      );

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String? _buildTime(String? start, String? end) {
    if (start == null || start.isEmpty) return null;
    if (end == null || end.isEmpty) return start;
    return '$start – $end';
  }

  static String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return '$base${url.startsWith('/') ? url : '/$url'}';
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header strip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      ShimmerBox(width: 42, height: 42, radius: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 120, height: 14, radius: 5),
                            const SizedBox(height: 5),
                            ShimmerBox(width: 80, height: 11, radius: 4),
                          ],
                        ),
                      ),
                      ShimmerBox(width: 70, height: 24, radius: 12),
                    ],
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 160, height: 13, radius: 4),
                      const SizedBox(height: 8),
                      ShimmerBox(width: 200, height: 13, radius: 4),
                      const SizedBox(height: 8),
                      ShimmerBox(width: double.infinity, height: 13, radius: 4),
                      const SizedBox(height: 4),
                      ShimmerBox(width: 220, height: 13, radius: 4),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: ShimmerBox(
                                  width: double.infinity,
                                  height: 44,
                                  radius: 12)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: ShimmerBox(
                                  width: double.infinity,
                                  height: 44,
                                  radius: 12)),
                        ],
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
  }
}
