import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../booking/domain/models/booking.dart';

class AppointmentCard extends StatefulWidget {
  const AppointmentCard({
    super.key,
    required this.booking,
    this.isPro = false,
    this.initiallyExpanded = false,
    this.onCancel,
    this.onAccept,
    this.onReject,
  });

  final Booking booking;
  final bool isPro;
  final bool initiallyExpanded;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

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

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return const Color(0xFF0095FF);
      case BookingStatus.rejected:
        return AppColors.error;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final isPro = widget.isPro;

    // Name and photo shown depend on perspective
    final displayName = isPro ? (b.clientName ?? 'Client') : b.professionalName;
    final displayPhoto = isPro ? b.clientPhoto : b.professionalPhoto;
    final displaySub = isPro ? 'Client' : (b.professionalProfession ?? 'Professional');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Header Row ────────────────────────────────────────────────────
          Padding(
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
                    child: (displayPhoto != null &&
                            displayPhoto.startsWith('http'))
                        ? Image.network(displayPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarPlaceholder(displayName))
                        : _avatarPlaceholder(displayName),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain),
                      ),
                      Text(displaySub,
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.status == BookingStatus.pending
                              ? Colors.transparent
                              : _statusColor(b.status),
                          borderRadius: BorderRadius.circular(20),
                          border: b.status == BookingStatus.pending
                              ? Border.all(color: Colors.orange)
                              : null,
                        ),
                        child: Text(
                          b.status.label,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: b.status == BookingStatus.pending
                                ? Colors.orange
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          // ── Expand Toggle ─────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: AppColors.textMain,
              ),
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
                    _InfoRow(
                      label: 'Date',
                      value: DateFormat('EEE, MMM d, yyyy').format(b.scheduledDate!),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (b.slotStart != null || b.slotEnd != null) ...[
                    _InfoRow(
                      label: 'Time',
                      value: [
                        if (b.slotStart != null) b.slotStart!,
                        if (b.slotEnd != null) b.slotEnd!,
                      ].join(' – '),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (b.location != null && b.location!.isNotEmpty) ...[
                    _InfoRow(label: 'Location', value: b.location!),
                    const SizedBox(height: 6),
                  ],
                  if (b.notes != null && b.notes!.isNotEmpty) ...[
                    _InfoRow(label: 'Notes', value: b.notes!),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 14),
                  // ── Actions ───────────────────────────────────────────────
                  if (isPro && b.status == BookingStatus.pending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: widget.onReject,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.primaryRed),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22)),
                              ),
                              child: Text(
                                'Reject',
                                style: GoogleFonts.outfit(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryGradientButton(
                            text: 'Accept',
                            height: 44,
                            onPressed: widget.onAccept ?? () {},
                          ),
                        ),
                      ],
                    ),
                  ] else if (!isPro &&
                      (b.status == BookingStatus.pending ||
                          b.status == BookingStatus.accepted)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryRed),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22)),
                          ),
                          child: Text(
                            'Cancel Booking',
                            style: GoogleFonts.outfit(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      color: AppColors.primaryRed.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryRed),
      ),
    );
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
          child: Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain)),
        ),
      ],
    );
  }
}
