import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';

class EditCalendarScreen extends StatefulWidget {
  const EditCalendarScreen({super.key});

  @override
  State<EditCalendarScreen> createState() => _EditCalendarScreenState();
}

class _EditCalendarScreenState extends State<EditCalendarScreen> {
  DateTime _focusedMonth = DateTime(2025, 4);
  bool _availableOn = true;
  bool _hoursAvailableOn = false;
  final Set<int> _selectedDays = {9, 17, 18, 29, 30}; // days with green/grey highlight
  final Set<int> _hourAvailableDays = {9, 17, 18}; // green; 29, 30 grey in one design
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  final List<({TimeOfDay start, TimeOfDay end})> _timeSlots = [
    (start: const TimeOfDay(hour: 10, minute: 50), end: const TimeOfDay(hour: 0, minute: 30)),
  ];
  bool _showTimePicker = false;
  bool _pickingStart = true;

  static const Color _green = Color(0xFF4CAF50);
  static const Color _yellow = Color(0xFFFFB74D);
  static const Color _grey = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(title: 'provider.profile.edit_calendar'.tr(), showNotification: false),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendar(),
            _buildToggles(),
            _buildSelectTimes(),
            _buildTimeSlotsList(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showUpdateDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('provider.profile.set_times'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _showTimePicker ? _buildTimePickerOverlay() : null,
    );
  }

  Widget _buildCalendar() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final daysInMonth = last.day;
    final weekdayStart = first.weekday;
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
              final isSelected = _selectedDays.contains(dayNum);
              final isHourAvailable = _hourAvailableDays.contains(dayNum);
              final color = isSelected ? (isHourAvailable ? _green : _grey) : null;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedDays.contains(dayNum)) {
                      _selectedDays.remove(dayNum);
                      _hourAvailableDays.remove(dayNum);
                    } else {
                      _selectedDays.add(dayNum);
                      _hourAvailableDays.add(dayNum);
                    }
                  });
                },
                child: Center(
                  child: color != null
                      ? Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('$dayNum', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: isHourAvailable ? Colors.white : Colors.black87)),
                        )
                      : Text('$dayNum', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMain)),
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

  Widget _buildToggles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('provider.profile.available'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain))),
              Switch(
                value: _availableOn,
                onChanged: (v) => setState(() => _availableOn = v),
                activeColor: _green,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text('provider.profile.hour_available'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain))),
              Switch(
                value: _hoursAvailableOn,
                onChanged: (v) => setState(() => _hoursAvailableOn = v),
                activeColor: _yellow,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectTimes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('provider.profile.select_times'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'provider.profile.start_time'.tr(),
                  value: _startTime,
                  onTap: () {
                    setState(() {
                      _pickingStart = true;
                      _showTimePicker = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeField(
                  label: 'provider.profile.end_time'.tr(),
                  value: _endTime,
                  onTap: () {
                    setState(() {
                      _pickingStart = false;
                      _showTimePicker = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _timeSlots.add((start: _startTime, end: _endTime));
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.plus, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text('provider.profile.add'.tr(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsList() {
    if (_timeSlots.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _timeSlots.asMap().entries.map((e) {
          final i = e.key;
          final slot = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      '${_formatTime(slot.start)} - ${_formatTime(slot.end)}',
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, color: AppColors.primaryRed, size: 20),
                  onPressed: () => setState(() => _timeSlots.removeAt(i)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour;
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final m = t.minute.toString().padLeft(2, '0');
    final am = h < 12 ? 'AM' : 'PM';
    return '$displayHour:$m $am';
  }

  Widget _buildTimePickerOverlay() {
    TimeOfDay cur = _pickingStart ? _startTime : _endTime;
    int hour = cur.hour == 0 ? 12 : (cur.hour > 12 ? cur.hour - 12 : cur.hour);
    int minute = cur.minute;
    bool isAm = cur.hour < 12;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Today', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('$hour ${minute.toString().padLeft(2, '0')} ${isAm ? "AM" : "PM"}', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _wheel(items: List.generate(12, (i) => '${i + 1}'), selected: hour.toString(), onSelected: (v) => hour = int.parse(v)),
                const SizedBox(width: 8),
                _wheel(items: List.generate(60, (i) => i.toString().padLeft(2, '0')), selected: minute.toString().padLeft(2, '0'), onSelected: (v) => minute = int.parse(v)),
                const SizedBox(width: 8),
                _wheel(items: ['AM', 'PM'], selected: isAm ? 'AM' : 'PM', onSelected: (v) => isAm = v == 'AM'),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                int h = isAm ? (hour == 12 ? 0 : hour) : (hour == 12 ? 12 : hour + 12);
                final t = TimeOfDay(hour: h, minute: minute);
                setState(() {
                  if (_pickingStart) _startTime = t; else _endTime = t;
                  _showTimePicker = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Color(0xFFE91E63), shape: BoxShape.circle),
                child: const Icon(LucideIcons.check, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({required List<String> items, required String selected, required void Function(String) onSelected}) {
    // Simple list; in production you might use a scrollable wheel
    return SizedBox(
      height: 120,
      width: 56,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final isSelected = item == selected;
          return GestureDetector(
            onTap: () => onSelected(item),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(item, style: GoogleFonts.outfit(fontSize: isSelected ? 18 : 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? AppColors.textMain : AppColors.textSecondary)),
            ),
          );
        },
      ),
    );
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('provider.profile.update'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain)),
        content: Text('provider.profile.update_confirm'.tr(), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryRed, side: const BorderSide(color: AppColors.primaryRed), backgroundColor: Colors.white),
            child: Text('provider.profile.no'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('provider.profile.yes'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  const _TimeField({required this.label, required this.value, required this.onTap});

  String _format(TimeOfDay t) {
    final h = t.hour;
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final m = t.minute.toString().padLeft(2, '0');
    return '$displayHour:$m ${h < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.clock, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                Text(_format(value), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
