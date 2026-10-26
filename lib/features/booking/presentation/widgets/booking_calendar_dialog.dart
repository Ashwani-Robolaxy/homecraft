import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../professionals/domain/models/calendar_day_status.dart';
import '../../../professionals/domain/models/professional_month_availability.dart';

String _capitalizeFirstLetter(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

class BookingCalendarDialog extends StatefulWidget {
  const BookingCalendarDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.availabilityByDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Map<DateTime, ProfessionalDayAvailability> availabilityByDate;

  @override
  State<BookingCalendarDialog> createState() => _BookingCalendarDialogState();
}

class _BookingCalendarDialogState extends State<BookingCalendarDialog> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedDay = _dateOnly(widget.initialDate);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  CalendarDayStatus _statusForDay(DateTime day) {
    return widget.availabilityByDate[_dateOnly(day)]?.status ?? CalendarDayStatus.unavailable;
  }

  bool _isSelectableDate(DateTime d) {
    final status = _statusForDay(d);
    return status == CalendarDayStatus.available || status == CalendarDayStatus.hourAvailable;
  }

  static Color _colorForStatus(CalendarDayStatus s, bool selectable) {
    if (!selectable) {
      // If it's not selectable, make the colors slightly desaturated/opacity-reduced
      switch (s) {
        case CalendarDayStatus.unavailable:
          return const Color(0xFFE53935).withValues(alpha: 0.15); // faint red
        case CalendarDayStatus.booked:
          return const Color(0xFF42A5F5).withValues(alpha: 0.25); // faint blue
        default:
          return Colors.transparent;
      }
    }
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
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'booking.select_date'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDay != null
                  ? _capitalizeFirstLetter(DateFormat('EEE, MMM d', localeTag).format(_selectedDay!))
                  : 'booking.choose_date'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEEEEEE), height: 1),
            const SizedBox(height: 12),
            _buildLegend(),
            const SizedBox(height: 16),
            _buildCalendar(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'common.cancel'.tr(),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8B79A1),
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _selectedDay != null
                      ? () => Navigator.of(context).pop(_selectedDay)
                      : null,
                  child: Text(
                    'common.ok'.tr(),
                    style: GoogleFonts.outfit(
                      color: _selectedDay != null ? AppColors.primaryRed : Colors.black26,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        _legendItem(const Color(0xFF4CAF50), 'provider.profile.available'.tr()),
        _legendItem(const Color(0xFFE53935), 'provider.profile.unavailable'.tr()),
        _legendItem(const Color(0xFFFFB74D), 'provider.profile.hour_available'.tr()),
        _legendItem(const Color(0xFF42A5F5), 'provider.profile.booked'.tr()),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
        ),
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
    const crossGap = 4.0;
    const mainGap = 4.0;

    return LayoutBuilder(
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
                  icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textSecondary, size: 20),
                  onPressed: _focusedMonth.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month))
                      ? () {
                          setState(() {
                            _focusedMonth = DateTime(year, month - 1);
                          });
                        }
                      : null,
                ),
                Text(
                  _capitalizeFirstLetter(DateFormat.yMMMM(localeTag).format(DateTime(year, month))),
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, color: AppColors.textSecondary, size: 20),
                  onPressed: _focusedMonth.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month))
                      ? () {
                          setState(() {
                            _focusedMonth = DateTime(year, month + 1);
                          });
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int col = 0; col < 7; col++) ...[
                  if (col > 0) SizedBox(width: crossGap),
                  SizedBox(
                    width: cellSize,
                    child: Center(
                      child: Text(
                        weekdayLabels[col],
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            for (int row = 0; row < rows; row++) ...[
              if (row > 0) SizedBox(height: mainGap),
              Row(
                children: [
                  for (int col = 0; col < 7; col++) ...[
                    if (col > 0) SizedBox(width: crossGap),
                    _buildCalendarGridCell(
                      cellIndex: row * 7 + col,
                      year: year,
                      month: month,
                      leadingPadding: leadingPadding,
                      daysInMonth: daysInMonth,
                      totalCells: totalCells,
                      cellSize: cellSize,
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
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
    if (cellIndex >= totalCells || cellIndex < leadingPadding) {
      return SizedBox(width: cellSize, height: cellSize);
    }

    final dayNum = cellIndex - leadingPadding + 1;
    final day = DateTime(year, month, dayNum);
    final selectable = _isSelectableDate(day) && !day.isBefore(_dateOnly(widget.firstDate)) && !day.isAfter(_dateOnly(widget.lastDate));
    final status = _statusForDay(day);
    final color = _colorForStatus(status, selectable);
    final selected = _selectedDay != null && _dateOnly(_selectedDay!) == _dateOnly(day);
    final hourStyle = status == CalendarDayStatus.hourAvailable;

    Color labelColor;
    if (!selectable) {
      labelColor = Colors.black26;
    } else {
      labelColor = hourStyle ? Colors.black87 : Colors.white;
    }

    final labelShadows = <Shadow>[
      if (selectable && !hourStyle)
        Shadow(
          color: Colors.black.withValues(alpha: selected ? 0.55 : 0.35),
          blurRadius: selected ? 3 : 2,
          offset: const Offset(0, 1),
        ),
    ];

    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: selectable ? () => setState(() => _selectedDay = _dateOnly(day)) : null,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: !selectable && status == CalendarDayStatus.unavailable
                        ? Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.1), width: 1)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: GoogleFonts.outfit(
                        fontSize: selected ? 12 : 11,
                        fontWeight: selectable ? FontWeight.w700 : FontWeight.w400,
                        color: labelColor,
                        height: 1,
                        shadows: labelShadows,
                      ),
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
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
