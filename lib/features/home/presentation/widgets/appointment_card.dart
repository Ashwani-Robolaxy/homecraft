import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../booking/domain/models/booking.dart';
import '../../../professionals/domain/models/professional_listing.dart';

class AppointmentCard extends StatefulWidget {
  const AppointmentCard({
    super.key,
    required this.booking,
    this.isPro = false,
    this.initiallyExpanded = false,
    this.onCancel,
    this.onAccept,
    this.onReject,
    this.onDeliver,
    this.onAcceptDelivery,
    this.onRejectDelivery,
    this.onReview,
  });

  final Booking booking;
  final bool isPro;
  final bool initiallyExpanded;

  /// Client-side only: invoked when the user taps **Cancel Booking** on a card
  /// whose status is [BookingStatus.pending] or [BookingStatus.accepted].
  /// Provider cards use [onAccept] / [onReject] instead.
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onDeliver;
  final VoidCallback? onAcceptDelivery;
  final VoidCallback? onRejectDelivery;
  final VoidCallback? onReview;

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  Color _statusColor(Booking b) {
    if (b.deliveryStatus == DeliveryStatus.delivered) {
      return const Color(0xFF673AB7); // Deep Purple for delivered awaiting acceptance
    }
    if (b.deliveryStatus == DeliveryStatus.rejected) {
      return Colors.deepOrange;
    }
    switch (b.status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return const Color(0xFF0095FF);
      case BookingStatus.completed:
        return const Color(0xFF2E8B47);
      case BookingStatus.rejected:
        return AppColors.error;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }

  String _statusLabel(Booking b) {
    if (b.deliveryStatus == DeliveryStatus.delivered) {
      return 'booking.delivery_delivered'.tr();
    }
    if (b.deliveryStatus == DeliveryStatus.rejected) {
      return 'booking.delivery_rejected'.tr();
    }
    return b.status.l10nKey.tr();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isPro = widget.isPro;

    // Name and photo shown depend on perspective
    final displayName = isPro ? (b.clientName ?? 'booking.fallback_client'.tr()) : b.professionalName;
    final displayPhoto = isPro ? b.clientPhoto : b.professionalPhoto;
    final displaySub = isPro ? 'booking.fallback_client'.tr() : ((b.professionalProfession ?? '').trim().isNotEmpty ? b.professionalProfession!.trim() : '—');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // ── Header Row ────────────────────────────────────────────────────
          InkWell(
            onTap: () {
              if (!isPro && b.professionalId.trim().isNotEmpty) {
                context.push(
                  '/professional-detail',
                  extra: ProfessionalListing(
                    id: b.professionalId.trim(),
                    displayName: b.professionalName,
                    specialty: b.professionalProfession ?? '',
                    roleLabel: b.professionalProfession ?? '',
                    location: b.location ?? '',
                    costDisplay: '',
                    dateDisplay: '',
                    profilePhotoUrl: b.professionalPhoto,
                    profileAssetFallback: AppAssets.profilePlaceholder,
                    backgroundAssetFallback: AppAssets.homeHeaderBg,
                  ),
                );
              } else {
                setState(() => _isExpanded = !_isExpanded);
              }
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 56,
                      child: (displayPhoto != null && displayPhoto.trim().isNotEmpty)
                          ? Image.network(displayPhoto, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarPlaceholder())
                          : _avatarPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
                        ),
                        Text(displaySub, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: b.status == BookingStatus.pending ? Colors.transparent : _statusColor(b),
                            borderRadius: BorderRadius.circular(20),
                            border: b.status == BookingStatus.pending ? Border.all(color: Colors.orange) : null,
                          ),
                          child: Text(
                            _statusLabel(b),
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: b.status == BookingStatus.pending ? Colors.orange : Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          // ── Expand Toggle ─────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textMain),
            ),
          ),
          // ── Expanded Content ──────────────────────────────────────────────
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (b.scheduledDate != null) ...[
                    _InfoRow(label: 'booking.field_date'.tr(), value: DateFormat.yMMMEd(Localizations.localeOf(context).toLanguageTag()).format(b.scheduledDate!)),
                    const SizedBox(height: 6),
                  ],
                  if (b.slotStart != null || b.slotEnd != null) ...[
                    _InfoRow(label: 'booking.field_time'.tr(), value: [if (b.slotStart != null) b.slotStart!, if (b.slotEnd != null) b.slotEnd!].join(' – ')),
                    const SizedBox(height: 6),
                  ],
                  if (b.location != null && b.location!.isNotEmpty) ...[_InfoRow(label: 'booking.field_location'.tr(), value: b.location!), const SizedBox(height: 6)],
                  if (b.notes != null && b.notes!.isNotEmpty) ...[_InfoRow(label: 'booking.field_notes'.tr(), value: b.notes!), const SizedBox(height: 6)],
                  const SizedBox(height: 14),

                  // ── Actions ───────────────────────────────────────────────
                  if (isPro) ...[
                    if (b.status == BookingStatus.pending) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: widget.onReject,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primaryRed),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                ),
                                child: Text(
                                  'common.reject'.tr(),
                                  style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryGradientButton(text: 'common.accept'.tr(), height: 44, onPressed: widget.onAccept ?? () {}),
                          ),
                        ],
                      ),
                    ] else if (b.status == BookingStatus.accepted && (b.deliveryStatus == DeliveryStatus.pending || b.deliveryStatus == DeliveryStatus.rejected)) ...[
                      if (b.deliveryStatus == DeliveryStatus.rejected) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            'booking.delivery_rejected_hint'.tr(),
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.deepOrange.shade800),
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: PrimaryGradientButton(
                          text: 'booking.mark_as_delivered'.tr(),
                          height: 44,
                          onPressed: widget.onDeliver ?? () {},
                        ),
                      ),
                    ] else if (b.deliveryStatus == DeliveryStatus.delivered) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF673AB7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: Color(0xFF673AB7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'booking.awaiting_client_confirmation'.tr(),
                                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF673AB7), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // Client Actions
                    if (b.deliveryStatus == DeliveryStatus.delivered) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: OutlinedButton(
                                onPressed: widget.onRejectDelivery,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  side: const BorderSide(color: AppColors.primaryRed),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'booking.reject_delivery'.tr(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: widget.onAcceptDelivery,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  backgroundColor: const Color(0xFF2E8B47),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 0,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'booking.accept_delivery'.tr(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (b.status == BookingStatus.completed || b.deliveryStatus == DeliveryStatus.accepted) ...[
                      if (!b.hasReview)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: widget.onReview,
                            icon: const Icon(Icons.star, size: 18, color: Colors.white),
                            label: Text(
                              'booking.write_review'.tr(),
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB800),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              elevation: 0,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E8B47)),
                              const SizedBox(width: 6),
                              Text(
                                'booking.review_submitted'.tr(),
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2E8B47)),
                              ),
                            ],
                          ),
                        ),
                    ] else if (b.status == BookingStatus.pending || b.status == BookingStatus.accepted) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryRed),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          child: Text(
                            'booking.cancel_booking'.tr(),
                            style: GoogleFonts.outfit(color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Image.asset(AppAssets.profilePlaceholder, fit: BoxFit.cover);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMain),
          ),
        ),
      ],
    );
  }
}
