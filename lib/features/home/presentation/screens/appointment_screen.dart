import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../booking/domain/models/booking.dart';
import '../widgets/appointment_card.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

import '../../../booking/presentation/widgets/review_dialog.dart';

class AppointmentScreen extends ConsumerStatefulWidget {
  const AppointmentScreen({super.key});

  @override
  ConsumerState<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends ConsumerState<AppointmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ds = BookingRemoteDatasource();

  List<Booking> _active = [];
  List<Booking> _history = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final all = await _ds.fetchClientBookings();
      if (!mounted) return;
      setState(() {
        _active = all.where((b) => b.status.isActive).toList();
        _history = all.where((b) => b.status.isHistory).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  /// Handles **Cancel Booking** from [AppointmentCard]: shows a confirmation dialog,
  /// then calls [BookingRemoteDatasource.cancelBooking] and refreshes the lists.
  Future<void> _cancel(Booking b) async {
    final confirmed = await _showConfirmDialog(
      title: 'booking.cancel_confirm_title'.tr(),
      body: 'booking.cancel_confirm_body'.tr(namedArgs: {'name': b.professionalName}),
      confirmLabel: 'booking.cancel_confirm_yes'.tr(),
    );
    if (!confirmed || !mounted) return;
    try {
      await _ds.cancelBooking(b.id);
      AppToast.success('booking.toast_cancelled'.tr());
      await _loadBookings();
    } catch (e) {
      AppToast.error(e.toString());
    }
  }

  Future<void> _acceptDelivery(Booking b) async {
    try {
      await _ds.acceptBookingDelivery(b.id);
      AppToast.success('booking.delivery_accepted_toast'.tr());
      await _loadBookings();
      if (mounted) {
        await ReviewDialog.show(context, bookingId: b.id, professionalName: b.professionalName);
        await _loadBookings();
      }
    } catch (e) {
      AppToast.error(e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _rejectDelivery(Booking b) async {
    final confirmed = await _showConfirmDialog(
      title: 'booking.reject_delivery_title'.tr(),
      body: 'booking.reject_delivery_body'.tr(namedArgs: {'name': b.professionalName}),
      confirmLabel: 'booking.reject_delivery_confirm'.tr(),
    );
    if (!confirmed || !mounted) return;
    try {
      await _ds.rejectBookingDelivery(b.id);
      AppToast.success('booking.delivery_rejected_toast'.tr());
      await _loadBookings();
    } catch (e) {
      AppToast.error(e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _writeReview(Booking b) async {
    final submitted = await ReviewDialog.show(context, bookingId: b.id, professionalName: b.professionalName);
    if (submitted == true && mounted) {
      await _loadBookings();
    }
  }

  /// Two-step confirm dialog used by [_cancel] (title/body/primary action label).
  Future<bool> _showConfirmDialog({required String title, required String body, required String confirmLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                  ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 15, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD0D0D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          backgroundColor: const Color(0xFFF5E9E9),
                        ),
                        child: Text(
                          'booking.cancel_confirm_go_back'.tr(),
                          style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: Text(
                          confirmLabel,
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final unread = unreadAsync.when<int>(data: (c) => c, loading: () => 0, error: (_, __) => 0);
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: CommonAppBar(
        title: 'booking.my_appointments'.tr(),
        showBackButton: false,
        showLogo: true,
        showNotification: true,
        notificationCount: unread,
        onNotificationTap: () {
          context.push('/notifications').then((_) {
            ref.invalidate(unreadNotificationCountProvider);
          });
        },
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryRed,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryRed,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: 'booking.tab_current'.tr()),
                Tab(text: 'booking.tab_history'.tr()),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const _AppointmentShimmer()
          : _hasError
          ? _BookingErrorState(onRetry: _loadBookings)
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: () async {
                await _loadBookings();
                ref.invalidate(unreadNotificationCountProvider);
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BookingList(
                    bookings: _active,
                    emptyText: 'booking.no_active_appointments'.tr(),
                    onCancel: _cancel,
                    onAcceptDelivery: _acceptDelivery,
                    onRejectDelivery: _rejectDelivery,
                    onReview: _writeReview,
                  ),
                  _BookingList(
                    bookings: _history,
                    emptyText: 'booking.no_history_appointments'.tr(),
                    isHistory: true,
                    onAcceptDelivery: _acceptDelivery,
                    onRejectDelivery: _rejectDelivery,
                    onReview: _writeReview,
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking list tab
// ─────────────────────────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.emptyText,
    this.isHistory = false,
    this.onCancel,
    this.onAcceptDelivery,
    this.onRejectDelivery,
    this.onReview,
  });

  final List<Booking> bookings;
  final String emptyText;
  final bool isHistory;

  final Future<void> Function(Booking)? onCancel;
  final Future<void> Function(Booking)? onAcceptDelivery;
  final Future<void> Function(Booking)? onRejectDelivery;
  final Future<void> Function(Booking)? onReview;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 56, color: AppColors.primaryRed),
              const SizedBox(height: 16),
              Text(
                emptyText,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      itemCount: bookings.length,
      itemBuilder: (_, i) {
        final b = bookings[i];
        return AppointmentCard(
          booking: b,
          isPro: false,
          onCancel: onCancel != null ? () => onCancel!(b) : null,
          onAcceptDelivery: onAcceptDelivery != null ? () => onAcceptDelivery!(b) : null,
          onRejectDelivery: onRejectDelivery != null ? () => onRejectDelivery!(b) : null,
          onReview: onReview != null ? () => onReview!(b) : null,
        );
      },
    );
  }
}

class _BookingErrorState extends StatelessWidget {
  const _BookingErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wifiOff, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'booking.error_load_appointments'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text('common.retry'.tr()),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentShimmer extends StatelessWidget {
  const _AppointmentShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(children: List.generate(3, (_) => _cardSkeleton())),
      ),
    );
  }

  Widget _cardSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          ShimmerBox(width: 72, height: 56, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 14, radius: 4),
                const SizedBox(height: 8),
                ShimmerBox(width: 120, height: 12, radius: 4),
                const SizedBox(height: 8),
                ShimmerBox(width: 60, height: 20, radius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
