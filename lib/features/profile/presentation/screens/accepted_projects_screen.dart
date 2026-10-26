import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/services/app_toast.dart';
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

  List<Booking> _pending = [];
  List<Booking> _accepted = [];
  List<Booking> _delivered = [];
  List<Booking> _rejected = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _ds.fetchProfessionalBookings(status: 'pending'),
        _ds.fetchProfessionalBookings(status: 'accepted'),
        _ds.fetchProfessionalBookings(status: 'rejected'),
      ]);
      if (!mounted) return;

      final allAccepted = results[1];
      final acceptedOnly = <Booking>[];
      final deliveredOnly = <Booking>[];

      for (final b in allAccepted) {
        if (b.deliveryStatus == DeliveryStatus.delivered ||
            b.deliveryStatus == DeliveryStatus.accepted ||
            b.status == BookingStatus.completed) {
          deliveredOnly.add(b);
        } else {
          acceptedOnly.add(b);
        }
      }

      setState(() {
        _pending = results[0];
        _accepted = acceptedOnly;
        _delivered = deliveredOnly;
        _rejected = results[2];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: CommonAppBar(
          title: 'provider.profile.accepted_projects'.tr(),
          showNotification: false,
          trailingActions: [
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 20, color: AppColors.primaryRed),
              onPressed: _load,
              tooltip: 'common.retry'.tr(),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: AppColors.primaryRed,
            labelColor: AppColors.primaryRed,
            unselectedLabelColor: Colors.black54,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: [
              Tab(text: 'booking.status_pending'.tr()),
              Tab(text: 'booking.status_accepted'.tr()),
              Tab(text: 'booking.delivery_delivered'.tr()),
              Tab(text: 'booking.status_rejected'.tr()),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _Shimmer();
    if (_error != null) return _buildError();

    return TabBarView(
      children: [
        RefreshIndicator(onRefresh: _load, color: AppColors.primaryRed, child: _buildList(_pending, 'pending')),
        RefreshIndicator(onRefresh: _load, color: AppColors.primaryRed, child: _buildList(_accepted, 'accepted')),
        RefreshIndicator(onRefresh: _load, color: AppColors.primaryRed, child: _buildList(_delivered, 'delivered')),
        RefreshIndicator(onRefresh: _load, color: AppColors.primaryRed, child: _buildList(_rejected, 'rejected')),
      ],
    );
  }

  Widget _buildList(List<Booking> list, String type) {
    if (list.isEmpty) return _buildEmpty(type);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: list.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          String countText = '';
          Color countColor = const Color(0xFF2E8B47);
          if (type == 'pending') {
            countText = 'booking.pending_count'.tr(namedArgs: {'count': '${list.length}'});
            countColor = const Color(0xFFE6A23C);
          } else if (type == 'accepted') {
            countText = 'booking.accepted_count'.tr(namedArgs: {'count': '${list.length}'});
            countColor = const Color(0xFF2E8B47);
          } else if (type == 'delivered') {
            countText = 'booking.delivered_count'.tr(namedArgs: {'count': '${list.length}'});
            countColor = const Color(0xFF673AB7);
          } else {
            countText = 'booking.rejected_count'.tr(namedArgs: {'count': '${list.length}'});
            countColor = const Color(0xFFF56C6C);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              countText,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: countColor),
            ),
          );
        }
        final booking = list[i - 1];
        if (type == 'pending') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BookingRequestCard(booking: booking, onDismiss: _load),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BookingCard(booking: booking, onRefresh: _load),
          );
        }
      },
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  label: Text('common.retry'.tr()),
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

  Widget _buildEmpty(String type) {
    String title = '';
    String desc = '';
    IconData icon = LucideIcons.clipboardList;

    if (type == 'pending') {
      title = 'booking.no_pending_title'.tr();
      desc = 'booking.no_pending_desc'.tr();
      icon = LucideIcons.clipboardList;
    } else if (type == 'accepted') {
      title = 'booking.no_accepted_title'.tr();
      desc = 'booking.no_accepted_desc'.tr();
      icon = LucideIcons.clipboardCheck;
    } else if (type == 'delivered') {
      title = 'booking.no_delivered_title'.tr();
      desc = 'booking.no_delivered_desc'.tr();
      icon = LucideIcons.packageCheck;
    } else {
      title = 'booking.no_rejected_title'.tr();
      desc = 'booking.no_rejected_desc'.tr();
      icon = LucideIcons.clipboardX;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  decoration: BoxDecoration(color: AppColors.primaryRed.withOpacity(0.09), shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.primaryRed, size: 36),
                ),
                const SizedBox(height: 16),
                Text(title, style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  desc,
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

class _BookingCard extends StatefulWidget {
  const _BookingCard({required this.booking, this.onRefresh});
  final Booking booking;
  final VoidCallback? onRefresh;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  final _ds = BookingRemoteDatasource();
  bool _delivering = false;

  Future<void> _deliver() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('booking.deliver_title'.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text('booking.deliver_body'.tr(), style: GoogleFonts.outfit(color: Colors.black54, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr(), style: GoogleFonts.outfit(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('booking.deliver_confirm'.tr(), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _delivering = true);
    try {
      await _ds.deliverBooking(widget.booking.id);
      if (!mounted) return;
      AppToast.success('booking.delivered_toast'.tr());
      widget.onRefresh?.call();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _delivering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final hasPhoto = booking.clientPhoto != null && booking.clientPhoto!.isNotEmpty;
    final photoUrl = hasPhoto ? _resolveUrl(booking.clientPhoto!) : null;

    final dateStr = booking.scheduledDate != null ? _fmtDate(booking.scheduledDate!) : null;
    final timeStr = _buildTime(booking.slotStart, booking.slotEnd);

    final isAccepted = booking.status == BookingStatus.accepted;
    final isDelivered = booking.deliveryStatus == DeliveryStatus.delivered;
    final isDeliveryAccepted = booking.deliveryStatus == DeliveryStatus.accepted || booking.status == BookingStatus.completed;

    Color statusColor = isAccepted ? const Color(0xFF2E8B47) : const Color(0xFFF56C6C);
    String statusLabel = isAccepted ? 'booking.status_accepted'.tr().toUpperCase() : 'booking.status_rejected'.tr().toUpperCase();

    if (isDelivered) {
      statusColor = const Color(0xFF673AB7);
      statusLabel = 'booking.delivery_delivered'.tr().toUpperCase();
    } else if (isDeliveryAccepted) {
      statusColor = const Color(0xFF2E8B47);
      statusLabel = 'booking.status_completed'.tr().toUpperCase();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header strip ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.clientName ?? 'common.client'.tr(),
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Booking #${booking.id}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4),
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
                if (dateStr != null || timeStr != null) _infoRow(LucideIcons.calendar, [if (dateStr != null) dateStr, if (timeStr != null) timeStr].join('  ·  '), statusColor),
                if (booking.location != null && booking.location!.isNotEmpty) ...[const SizedBox(height: 6), _infoRow(LucideIcons.mapPin, booking.location!, Colors.black54)],
                if (booking.notes != null && booking.notes!.isNotEmpty) ...[const SizedBox(height: 6), _infoRow(LucideIcons.fileText, booking.notes!, Colors.black54)],
                if (booking.projectId != null && booking.projectId!.isNotEmpty) ...[const SizedBox(height: 6), _infoRow(LucideIcons.folder, 'Project #${booking.projectId}', Colors.black45)],
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
                            clientDisplayName: booking.clientName ?? 'common.client'.tr(),
                            isCurrentUserProfessional: true,
                            projectId: booking.projectId,
                          ),
                        ),
                        icon: const Icon(LucideIcons.messageCircle, size: 16),
                        label: Text('common.message'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Deliver / Status button
                    if (isAccepted && !isDelivered && !isDeliveryAccepted)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _delivering ? null : _deliver,
                          icon: _delivering
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(LucideIcons.checkCheck, size: 16),
                          label: Text('booking.mark_as_delivered'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B47),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: Icon(isDelivered ? LucideIcons.clock : (isAccepted ? LucideIcons.checkCircle : LucideIcons.xCircle), size: 16),
                          label: Text(isDelivered ? 'booking.delivery_delivered'.tr() : (isAccepted ? 'provider.profile.accepted_tab'.tr() : 'booking.status_rejected'.tr())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: statusColor,
                            disabledForegroundColor: statusColor,
                            side: BorderSide(color: statusColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
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
          style: GoogleFonts.outfit(fontSize: 13, color: color, height: 1.4),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _avatarFallback() => Image.asset(AppAssets.profilePlaceholder, width: 42, height: 42, fit: BoxFit.cover);

  static String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String? _buildTime(String? start, String? end) {
    if (start == null || start.isEmpty) return null;
    if (end == null || end.isEmpty) return start;
    return '$start – $end';
  }

  static String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    return '$base${url.startsWith('/') ? url : '/$url'}';
  }
}

// ── Booking request card ──────────────────────────────────────────────────────

class _BookingRequestCard extends StatefulWidget {
  const _BookingRequestCard({required this.booking, required this.onDismiss});
  final Booking booking;
  final VoidCallback onDismiss;

  @override
  State<_BookingRequestCard> createState() => _BookingRequestCardState();
}

class _BookingRequestCardState extends State<_BookingRequestCard> {
  final _ds = BookingRemoteDatasource();
  bool _accepting = false;
  bool _rejecting = false;

  bool get _busy => _accepting || _rejecting;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await _ds.updateBookingStatus(widget.booking.id, 'accepted');
      if (!mounted) return;
      AppToast.success('booking.accepted'.tr());
      widget.onDismiss();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', ''));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('booking.reject_title'.tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text('booking.reject_body'.tr(), style: GoogleFonts.outfit(color: Colors.black54, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr(), style: GoogleFonts.outfit(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('common.reject'.tr(), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _rejecting = true);
    try {
      await _ds.updateBookingStatus(widget.booking.id, 'rejected');
      if (!mounted) return;
      AppToast.success('booking.rejected'.tr());
      widget.onDismiss();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: client info ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF3F3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.clientName ?? 'common.client'.tr(), style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('#${b.id}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black38)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFC107), width: 1),
                  ),
                  child: Text(
                    'common.pending'.tr(),
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF856404)),
                  ),
                ),
              ],
            ),
          ),

          // ── Details ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b.scheduledDate != null) _infoRow(LucideIcons.calendar, _fmtDate(b.scheduledDate!), AppColors.primaryRed),
                if (b.slotStart != null || b.slotEnd != null) _infoRow(LucideIcons.clock, [b.slotStart, b.slotEnd].whereType<String>().join(' – '), Colors.black54),
                if (b.location != null && b.location!.isNotEmpty) _infoRow(LucideIcons.mapPin, b.location!, Colors.black54),
                if (b.budget != null && b.budget!.isNotEmpty) _infoRow(LucideIcons.wallet, '€${b.budget}', Colors.black54),
                if (b.notes != null && b.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    b.notes!,
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54, height: 1.45),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),

                Row(
                  children: [
                    GestureDetector(
                      onTap: _busy
                          ? null
                          : () => context.push(
                              '/chat',
                              extra: ProfessionalChatArgs(
                                clientUserId: b.clientId ?? '',
                                clientDisplayName: b.clientName ?? 'common.client'.tr(),
                                isCurrentUserProfessional: true,
                                projectId: b.projectId,
                              ),
                            ),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.messageCircle, size: 20, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _rejecting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))
                            : Text('common.reject'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _accept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF238E10),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _accepting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('common.accept'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _infoRow(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54)),
        ),
      ],
    ),
  );

  Widget _avatarFallback() => Image.asset(AppAssets.profilePlaceholder, width: 46, height: 46, fit: BoxFit.cover);

  static String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      ShimmerBox(width: 42, height: 42, radius: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [ShimmerBox(width: 120, height: 14, radius: 5), const SizedBox(height: 5), ShimmerBox(width: 80, height: 11, radius: 4)],
                        ),
                      ),
                      ShimmerBox(width: 70, height: 24, radius: 12),
                    ],
                  ),
                ),
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
                          Expanded(child: ShimmerBox(width: double.infinity, height: 44, radius: 12)),
                          const SizedBox(width: 10),
                          Expanded(child: ShimmerBox(width: double.infinity, height: 44, radius: 12)),
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
