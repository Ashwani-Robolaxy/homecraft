import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

enum AppointmentStatus { current, accepted, complete, rejected }

class AppointmentCard extends StatefulWidget {
  final String profImage;
  final String profName;
  final String clientName;
  final AppointmentStatus status;
  final bool initiallyExpanded;
  final VoidCallback? onActionPressed;

  const AppointmentCard({super.key, required this.profImage, required this.profName, required this.clientName, required this.status, this.initiallyExpanded = false, this.onActionPressed});

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

  Color _getStatusColor() {
    switch (widget.status) {
      case AppointmentStatus.current:
        return Colors.white;
      case AppointmentStatus.accepted:
        return const Color(0xFF0095FF);
      case AppointmentStatus.complete:
        return const Color(0xFF4CAF50);
      case AppointmentStatus.rejected:
        return AppColors.error;
    }
  }

  String _getStatusText() {
    switch (widget.status) {
      case AppointmentStatus.current:
        return 'Current';
      case AppointmentStatus.accepted:
        return 'Accepted';
      case AppointmentStatus.complete:
        return 'Complete';
      case AppointmentStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(image: AssetImage(widget.profImage), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profName,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
                      ),
                      Text(widget.clientName, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.status == AppointmentStatus.current ? Colors.white : _getStatusColor(),
                          borderRadius: BorderRadius.circular(20),
                          border: widget.status == AppointmentStatus.current ? Border.all(color: AppColors.primaryRed) : null,
                        ),
                        child: Text(
                          _getStatusText(),
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500, color: widget.status == AppointmentStatus.current ? AppColors.primaryRed : Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                  child: const Icon(Icons.chat_bubble, color: Color(0xFF7A0000), size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textMain),
            ),
          ),
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Date & Time  ', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                      Expanded(
                        child: Text('Dec 23,2025  10:00-12:00 AM', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Location       ', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                      Expanded(
                        child: Text('267 New Avenue Park.', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: const DecorationImage(image: AssetImage('assets/images/map_placeholder.png'), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryGradientButton(text: widget.status == AppointmentStatus.complete ? 'Review Now' : 'Cancel Booking', height: 40, onPressed: widget.onActionPressed ?? () {}),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
