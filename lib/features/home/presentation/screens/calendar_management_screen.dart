import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../booking/domain/models/booking.dart';
import '../../../professionals/data/professional_availability_remote_datasource.dart';
import '../../../professionals/domain/models/calendar_day_status.dart';
import '../../../professionals/domain/models/professional_month_availability.dart';

/// Some locales lowercase the month in long date patterns (e.g. French "avril 2026").
String _capitalizeFirstLetter(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

class CalendarManagementScreen extends StatefulWidget {
  const CalendarManagementScreen({super.key});

  @override
  State<CalendarManagementScreen> createState() => _CalendarManagementScreenState();
}

class _CalendarManagementScreenState extends State<CalendarManagementScreen> {
  final ProfessionalAvailabilityRemoteDatasource _availabilityDs = ProfessionalAvailabilityRemoteDatasource();
  final BookingRemoteDatasource _bookingDs = BookingRemoteDatasource();
  DateTime _focusedMonth = DateTime.now();
  int _selectedTab = 0; // 0: Pending, 1: Accepted, 2: History
  bool _loading = true;
  String? _error;
  final Map<DateTime, ProfessionalDayAvailability> _dayDetailByDate = {};
  DateTime? _selectedDay;

  // Real booking lists from API
  List<Booking> _pendingBookings = [];
  List<Booking> _acceptedBookings = [];
  List<Booking> _historyBookings = [];
  bool _bookingBusy = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final monthParam = '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';
      final month = await _availabilityDs.fetchMyMonthlyAvailability(monthParam);
      if (!mounted) return;
      setState(() {
        _dayDetailByDate
          ..clear()
          ..addAll(month.toDetailsByDate());
        if (_selectedDay != null && (_selectedDay!.year != _focusedMonth.year || _selectedDay!.month != _focusedMonth.month)) {
          _selectedDay = null;
        }
        _loading = false;
      });
      // Also load bookings in parallel (non-blocking)
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadBookings() async {
    try {
      final all = await _bookingDs.fetchProfessionalBookings();
      if (!mounted) return;
      setState(() {
        _pendingBookings = all.where((b) => b.status == BookingStatus.pending).toList();
        _acceptedBookings = all.where((b) => b.status == BookingStatus.accepted).toList();
        _historyBookings = all.where((b) => b.status.isHistory).toList();
      });
    } catch (_) {
      // Silently fail – calendar still usable
    }
  }

  Future<void> _acceptBooking(Booking b) async {
    setState(() => _bookingBusy = true);
    try {
      await _bookingDs.updateBookingStatus(b.id, 'accepted');
      AppToast.success('booking.accepted_toast'.tr());
      await _loadBookings();
      await _loadAvailability();
    } catch (e) {
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  Future<void> _rejectBooking(Booking b) async {
    setState(() => _bookingBusy = true);
    try {
      await _bookingDs.updateBookingStatus(b.id, 'rejected');
      AppToast.success('booking.rejected_toast'.tr());
      await _loadBookings();
      await _loadAvailability();
    } catch (e) {
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  CalendarDayStatus _statusForDay(DateTime day) {
    final dayOnly = _dateOnly(day);
    final hasAccepted = _acceptedBookings.any((b) {
      final sd = b.scheduledDate;
      if (sd == null) return false;
      return sd.year == dayOnly.year && sd.month == dayOnly.month && sd.day == dayOnly.day;
    });
    if (hasAccepted) {
      return CalendarDayStatus.booked;
    }
    final rawStatus = _dayDetailByDate[dayOnly]?.status ?? CalendarDayStatus.unavailable;
    if (rawStatus == CalendarDayStatus.booked) {
      // If backend availability returned 'booked', but we know there are no active
      // (accepted or pending) bookings on this day, then the booking was refused/cancelled.
      final hasPending = _pendingBookings.any((b) {
        final sd = b.scheduledDate;
        if (sd == null) return false;
        return sd.year == dayOnly.year && sd.month == dayOnly.month && sd.day == dayOnly.day;
      });
      if (!hasPending) {
        final slots = _dayDetailByDate[dayOnly]?.slots ?? const [];
        if (slots.isNotEmpty) {
          return CalendarDayStatus.hourAvailable;
        }
        return CalendarDayStatus.available;
      }
    }
    return rawStatus;
  }

  bool _bookingOnSelectedDay(Booking b) {
    final day = _selectedDay;
    if (day == null) return true;
    final sd = b.scheduledDate;
    if (sd == null) return false;
    return sd.year == day.year && sd.month == day.month && sd.day == day.day;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static Color _colorForStatus(CalendarDayStatus s) {
    switch (s) {
      case CalendarDayStatus.available:
        return const Color(0xFF4CAF50); // green
      case CalendarDayStatus.unavailable:
        return const Color(0xFFE53935); // red
      case CalendarDayStatus.hourAvailable:
        return const Color(0xFFFFB74D); // yellow/orange
      case CalendarDayStatus.booked:
        return const Color(0xFF42A5F5); // blue
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: 'provider.profile.calendar_management'.tr(),
        showBackButton: false,
        showNotification: false,
        trailingActions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20, color: AppColors.primaryRed),
            onPressed: _loadAvailability,
            tooltip: 'common.retry'.tr(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAvailability,
        color: AppColors.primaryRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const _CalendarShimmer()
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadAvailability, child: Text('common.retry'.tr())),
                    ],
                  ),
                )
              else ...[
                _buildLegend(),
                _buildCalendar(),
                _buildSelectedDayPanel(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        final refreshed = await context.push<bool>('/edit-calendar');
                        if (refreshed == true && mounted) _loadAvailability();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        elevation: 2,
                      ),
                      child: Text('provider.profile.edit_your_availability'.tr(), style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTabs(),
                _buildAppointmentList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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
    const crossGap = 6.0;
    const mainGap = 6.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final localeTag = Localizations.localeOf(context).toLanguageTag();
          final weekdayLabels = [
            'provider.calendar.week_mon'.tr(),
            'provider.calendar.week_tue'.tr(),
            'provider.calendar.week_wed'.tr(),
            'provider.calendar.week_thu'.tr(),
            'provider.calendar.week_fri'.tr(),
            'provider.calendar.week_sat'.tr(),
            'provider.calendar.week_sun'.tr(),
          ];
          final maxW = constraints.maxWidth;
          final cellSize = (maxW - crossGap * 6) / 7;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textSecondary),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(year, month - 1);
                        _selectedDay = null;
                      });
                      _loadAvailability();
                    },
                  ),
                  Text(
                    _capitalizeFirstLetter(DateFormat.yMMMM(localeTag).format(DateTime(year, month))),
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.chevronRight, color: AppColors.textSecondary),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(year, month + 1);
                        _selectedDay = null;
                      });
                      _loadAvailability();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int col = 0; col < 7; col++) ...[
                    if (col > 0) SizedBox(width: crossGap),
                    SizedBox(
                      width: cellSize,
                      child: Center(
                        child: Text(
                          weekdayLabels[col],
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              for (int row = 0; row < rows; row++) ...[
                if (row > 0) SizedBox(height: mainGap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int col = 0; col < 7; col++) ...[
                      if (col > 0) SizedBox(width: crossGap),
                      _buildCalendarGridCell(cellIndex: row * 7 + col, year: year, month: month, leadingPadding: leadingPadding, daysInMonth: daysInMonth, totalCells: totalCells, cellSize: cellSize),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarGridCell({
    required int cellIndex,
    required int year,
    required int month,
    required int leadingPadding,
    required int daysInMonth,
    required int totalCells,
    required double cellSize,
  }) {
    if (cellIndex >= totalCells) {
      return SizedBox(width: cellSize, height: 0);
    }
    if (cellIndex < leadingPadding) {
      final prevLast = DateTime(year, month, 0);
      final day = prevLast.day - (leadingPadding - 1 - cellIndex);
      if (day < 1) return SizedBox(width: cellSize, height: 0);
      return SizedBox(
        width: cellSize,
        height: cellSize,
        child: Center(
          child: Text('$day', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black26)),
        ),
      );
    }
    final dayNum = cellIndex - leadingPadding + 1;
    if (dayNum > daysInMonth) {
      return SizedBox(width: cellSize, height: 0);
    }
    final day = DateTime(year, month, dayNum);
    final status = _statusForDay(day);
    final color = _colorForStatus(status);
    final selected = _selectedDay != null && _dateOnly(_selectedDay!) == _dateOnly(day);
    final hourStyle = status == CalendarDayStatus.hourAvailable;
    final labelColor = hourStyle ? Colors.black87 : Colors.white;
    // Halo so the day number stays readable on every fill (selection ring has no shadow — shadow here would wash out the label).
    final labelShadows = <Shadow>[
      if (hourStyle)
        Shadow(color: Colors.white.withValues(alpha: 0.95), blurRadius: selected ? 4 : 2, offset: const Offset(0, 0.5))
      else ...[
        Shadow(
          color: Colors.black.withValues(alpha: selected ? 0.55 : 0.35),
          blurRadius: selected ? 3 : 2,
          offset: const Offset(0, 1),
        ),
      ],
    ];

    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedDay = _dateOnly(day)),
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: GoogleFonts.outfit(fontSize: selected ? 13 : 12, fontWeight: FontWeight.w700, color: labelColor, height: 1, shadows: labelShadows),
                    ),
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedDay == null)
            Text('provider.profile.calendar_tap_day_hint'.tr(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, height: 1.35))
          else ...[
            Text(
              DateFormat.yMMMEd(Localizations.localeOf(context).toLanguageTag()).format(_selectedDay!),
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _colorForStatus(_statusForDay(_selectedDay!)), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_statusLabel(_statusForDay(_selectedDay!)), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'provider.profile.calendar_available_hours'.tr(),
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
            ),
            const SizedBox(height: 6),
            ..._buildHoursLinesForSelectedDay(),
            const SizedBox(height: 8),
            Text(
              'provider.profile.calendar_appointments_on_day'.tr(),
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(CalendarDayStatus s) {
    switch (s) {
      case CalendarDayStatus.available:
        return 'provider.profile.available'.tr();
      case CalendarDayStatus.unavailable:
        return 'provider.profile.unavailable'.tr();
      case CalendarDayStatus.hourAvailable:
        return 'provider.profile.hour_available'.tr();
      case CalendarDayStatus.booked:
        return 'provider.profile.booked'.tr();
    }
  }

  List<Widget> _buildHoursLinesForSelectedDay() {
    final day = _selectedDay!;
    final detail = _dayDetailByDate[_dateOnly(day)];
    final status = _statusForDay(day);
    final slots = detail?.slots ?? const [];

    if (status == CalendarDayStatus.unavailable) {
      return [Text('provider.profile.calendar_no_open_hours'.tr(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))];
    }

    if (slots.isNotEmpty) {
      return slots
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('${s.startTime} – ${s.endTime}', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain)),
                ],
              ),
            ),
          )
          .toList();
    }

    if (status == CalendarDayStatus.hourAvailable) {
      return [Text('provider.profile.calendar_partial_no_slots'.tr(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))];
    }

    if (status == CalendarDayStatus.booked) {
      return [Text('provider.profile.calendar_booked_see_below'.tr(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))];
    }

    if (status == CalendarDayStatus.available) {
      return [Text('provider.profile.calendar_full_day_available'.tr(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))];
    }

    return [Text('provider.profile.calendar_no_open_hours'.tr(), style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))];
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
                    child: Text(
                      tabs[i],
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: selected ? AppColors.textMain : AppColors.textSecondary),
                    ),
                  ),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(color: selected ? const Color(0xFFFFB74D) : Colors.transparent, borderRadius: BorderRadius.circular(2)),
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
    var bookings = _selectedTab == 0
        ? _pendingBookings
        : _selectedTab == 1
        ? _acceptedBookings
        : _historyBookings;

    if (_selectedDay != null) {
      bookings = bookings.where(_bookingOnSelectedDay).toList();
    }

    if (_bookingBusy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
      );
    }

    if (bookings.isEmpty) {
      final msg = _selectedDay != null ? 'provider.profile.calendar_no_appointments_this_day'.tr() : 'provider.calendar.no_appointments_section'.tr();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Center(
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final b = bookings[index];
        final isPending = b.status == BookingStatus.pending;
        final isHistory = b.status.isHistory;
        return _BookingCard(
          booking: b,
          onAccept: isPending ? () => _confirmAndAct(true, () => _acceptBooking(b)) : null,
          onReject: isPending ? () => _confirmAndAct(false, () => _rejectBooking(b)) : null,
          isHistory: isHistory,
        );
      },
    );
  }

  Future<void> _confirmAndAct(bool accept, Future<void> Function() action) async {
    final color = accept ? const Color(0xFF4CAF50) : AppColors.primaryRed;
    final title = accept ? 'booking.dialog_title_accept'.tr() : 'booking.dialog_title_reject'.tr();
    final body = accept ? 'booking.dialog_body_accept'.tr() : 'booking.dialog_body_reject'.tr();
    final confirmLabel = accept ? 'common.accept'.tr() : 'common.reject'.tr();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD0D0D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        child: Text(
                          'common.cancel'.tr(),
                          style: GoogleFonts.outfit(color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
      ),
    );
    if (confirmed == true) await action();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking card for professional's calendar view
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.onAccept, this.onReject, this.isHistory = false});

  final Booking booking;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetails(context, b),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.clientName ?? 'booking.fallback_client'.tr(),
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 6),
                      if (b.scheduledDate != null) ...[
                        Row(
                          children: [
                            const Icon(LucideIcons.calendarDays, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              '${b.scheduledDate!.day}/${b.scheduledDate!.month}/${b.scheduledDate!.year}'
                              '${b.slotStart != null ? "  ${b.slotStart}" : ""}'
                              '${b.slotEnd != null ? " – ${b.slotEnd}" : ""}',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (b.location != null && b.location!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(LucideIcons.mapPin, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(b.location!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      if (b.budget != null && b.budget!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(LucideIcons.wallet, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text('€${b.budget}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _statusColor(b.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          b.status.l10nKey.tr(),
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(b.status)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isHistory && (onAccept != null || onReject != null)) ...[
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onAccept != null)
                        SizedBox(
                          width: 72,
                          child: ElevatedButton(
                            onPressed: onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text('common.accept'.tr(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      if (onReject != null) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: OutlinedButton(
                            onPressed: onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: const BorderSide(color: AppColors.primaryRed),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text('common.reject'.tr(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, Booking b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'details.title'.tr(),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
              ),
              const SizedBox(height: 16),
              _detailRow(LucideIcons.user, 'booking.fallback_client'.tr(), b.clientName ?? 'booking.fallback_client'.tr()),
              if (b.scheduledDate != null) _detailRow(LucideIcons.calendarDays, 'booking.field_date'.tr(), '${b.scheduledDate!.day}/${b.scheduledDate!.month}/${b.scheduledDate!.year}'),
              if (b.slotStart != null) _detailRow(LucideIcons.clock, 'booking.field_time'.tr(), '${b.slotStart}${b.slotEnd != null ? " – ${b.slotEnd}" : ""}'),
              if (b.location != null && b.location!.isNotEmpty) _detailRow(LucideIcons.mapPin, 'booking.field_location'.tr(), b.location!),
              if (b.budget != null && b.budget!.isNotEmpty) _detailRow(LucideIcons.wallet, 'booking.budget'.tr(), b.budget!),
              const SizedBox(height: 12),
              Text(
                'booking.notes_description'.tr(),
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Text(
                  (b.notes != null && b.notes!.isNotEmpty) ? b.notes! : 'No additional notes provided.',
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return const Color(0xFF0095FF);
      case BookingStatus.completed:
        return const Color(0xFF2E8B47);
      case BookingStatus.rejected:
        return AppColors.primaryRed;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }
}

// ---------------------------------------------------------------------------
// Pure-Flutter shimmer skeleton for the calendar loading state
// ---------------------------------------------------------------------------

class _CalendarShimmer extends StatefulWidget {
  const _CalendarShimmer();

  @override
  State<_CalendarShimmer> createState() => _CalendarShimmerState();
}

class _CalendarShimmerState extends State<_CalendarShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => _ShimmerBody(shimmerOffset: _anim.value),
    );
  }
}

class _ShimmerBody extends StatelessWidget {
  const _ShimmerBody({required this.shimmerOffset});
  final double shimmerOffset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigator row skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_shimmerBox(width: 32, height: 32, radius: 16), _shimmerBox(width: 140, height: 22, radius: 6), _shimmerBox(width: 32, height: 32, radius: 16)],
          ),
          const SizedBox(height: 20),

          // Day-of-week label row
          Row(
            children: List.generate(
              7,
              (_) => Expanded(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _shimmerBox(height: 14, radius: 4)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Calendar grid: 7 columns x 5 rows of day cells
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: 35,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemBuilder: (_, __) => _shimmerBox(radius: 10),
          ),
          const SizedBox(height: 28),

          // Section label
          _shimmerBox(width: 130, height: 16, radius: 4),
          const SizedBox(height: 14),

          // Three appointment skeleton cards
          for (var i = 0; i < 3; i++) ...[_appointmentCard(), const SizedBox(height: 12)],
        ],
      ),
    );
  }

  Widget _appointmentCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _shimmerBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_shimmerBox(height: 14, radius: 4), const SizedBox(height: 8), _shimmerBox(width: 120, height: 12, radius: 4)],
            ),
          ),
          const SizedBox(width: 12),
          _shimmerBox(width: 60, height: 28, radius: 6),
        ],
      ),
    );
  }

  Widget _shimmerBox({double? width, double? height, double radius = 4}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: _ShimmerGradientBox(offset: shimmerOffset),
      ),
    );
  }
}

class _ShimmerGradientBox extends StatelessWidget {
  const _ShimmerGradientBox({required this.offset});
  final double offset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 40.0;
        return CustomPaint(
          size: Size(w, h),
          painter: _ShimmerPainter(offset: offset),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({required this.offset});
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment(offset - 1, 0),
      end: Alignment(offset + 1, 0),
      colors: const [Color(0xFFEDEDED), Color(0xFFF8F8F8), Color(0xFFFFFFFF), Color(0xFFF8F8F8), Color(0xFFEDEDED)],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.offset != offset;
}
