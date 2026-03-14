import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';

enum DayStatus { available, unavailable, hourAvailable, booked }

class CalendarManagementScreen extends StatefulWidget {
  const CalendarManagementScreen({super.key});

  @override
  State<CalendarManagementScreen> createState() => _CalendarManagementScreenState();
}

class _CalendarManagementScreenState extends State<CalendarManagementScreen> {
  DateTime _focusedMonth = DateTime(2025, 4);
  int _selectedTab = 0; // 0: Booked, 1: Accepted, 2: History

  // Demo: assign status per day for April 2025
  static DayStatus _statusForDay(DateTime day) {
    if (day.month != 4 || day.year != 2025) return DayStatus.unavailable;
    final d = day.day;
    if ([3, 7, 12].contains(d)) return DayStatus.booked;
    if ([4, 10, 11, 15, 16, 21, 22, 26, 27].contains(d)) return DayStatus.unavailable;
    if ([2, 9, 17, 18, 23, 29, 30].contains(d)) return DayStatus.hourAvailable;
    return DayStatus.available;
  }

  static Color _colorForStatus(DayStatus s) {
    switch (s) {
      case DayStatus.available:
        return const Color(0xFF4CAF50); // green
      case DayStatus.unavailable:
        return const Color(0xFFE53935); // red
      case DayStatus.hourAvailable:
        return const Color(0xFFFFB74D); // yellow/orange
      case DayStatus.booked:
        return const Color(0xFF42A5F5); // blue
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(title: 'provider.profile.calendar_management'.tr(), showBackButton: false, showNotification: false),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegend(),
            _buildCalendar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/edit-calendar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('provider.profile.edit_your_availability'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildTabs(),
            _buildAppointmentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(const Color(0xFF4CAF50), 'provider.profile.available'.tr()),
          _legendItem(const Color(0xFFE53935), 'provider.profile.unavailable'.tr()),
          _legendItem(const Color(0xFFFFB74D), 'provider.profile.hour_available'.tr()),
          _legendItem(const Color(0xFF42A5F5), 'provider.profile.booked'.tr()),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildCalendar() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final daysInMonth = last.day;
    final weekdayStart = first.weekday; // 1 = Monday
    final leadingPadding = weekdayStart - 1;
    final totalCells = leadingPadding + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textSecondary),
                onPressed: () => setState(() => _focusedMonth = DateTime(year, month - 1)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_monthName(month), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                  const SizedBox(width: 4),
                  Text('$year', style: GoogleFonts.outfit(fontSize: 16, color: AppColors.textSecondary)),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, color: AppColors.textSecondary),
                onPressed: () => setState(() => _focusedMonth = DateTime(year, month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => SizedBox(width: 36, child: Center(child: Text(d, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))))).toList(),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 1.1,
            children: List.generate(rows * 7, (i) {
              final cellIndex = i;
              if (cellIndex < leadingPadding) {
                final prevLast = DateTime(year, month, 0);
                final day = prevLast.day - (leadingPadding - 1 - cellIndex);
                if (day < 1) return const SizedBox();
                return Center(child: Text('$day', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black26)));
              }
              final dayNum = cellIndex - leadingPadding + 1;
              if (dayNum > daysInMonth) return const SizedBox();
              final day = DateTime(year, month, dayNum);
              final status = _statusForDay(day);
              final color = _colorForStatus(status);
              return Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('$dayNum', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: status == DayStatus.hourAvailable ? Colors.black87 : Colors.white)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }

  Widget _buildTabs() {
    final tabs = ['provider.profile.booked_tab'.tr(), 'provider.profile.accepted_tab'.tr(), 'provider.profile.history_tab'.tr()];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(tabs[i], style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: selected ? AppColors.textMain : AppColors.textSecondary)),
                  ),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFFB74D) : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAppointmentList() {
    final isBooked = _selectedTab == 0;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _AppointmentCard(
        name: 'Nessa',
        dateTime: '14 March || 10:00 AM - 11:00 PM',
        address: 'Paris, France',
        isBooked: isBooked,
        isHistory: _selectedTab == 2,
        onAccept: () => _showAcceptDialog(context),
        onReject: () => _showRejectDialog(context),
        onComplete: () {},
      ),
    );
  }

  void _showAcceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('provider.profile.accept'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50))),
        content: Text('provider.profile.accept_confirm'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryRed, side: const BorderSide(color: AppColors.primaryRed), backgroundColor: Colors.white),
            child: Text('provider.profile.no'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('provider.profile.yes'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('provider.profile.reject'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
        content: Text('provider.profile.reject_confirm'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryRed, side: const BorderSide(color: AppColors.primaryRed), backgroundColor: Colors.white),
            child: Text('provider.profile.no'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('provider.profile.yes'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final String name;
  final String dateTime;
  final String address;
  final bool isBooked;
  final bool isHistory;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;

  const _AppointmentCard({
    required this.name,
    required this.dateTime,
    required this.address,
    required this.isBooked,
    this.isHistory = false,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(dateTime, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('Address: $address', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.fileText, size: 20, color: AppColors.textSecondary),
              if (!isHistory) ...[
                const SizedBox(height: 8),
                if (isBooked) ...[
                SizedBox(
                  width: 70,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: Text('provider.profile.accept'.tr(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryRed, side: const BorderSide(color: AppColors.primaryRed), padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: Text('provider.profile.reject'.tr(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else
                SizedBox(
                  width: 80,
                  child: ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: Text('provider.profile.complete'.tr(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
