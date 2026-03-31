import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

class EditCalendarScreen extends StatefulWidget {
  const EditCalendarScreen({super.key});

  @override
  State<EditCalendarScreen> createState() => _EditCalendarScreenState();
}

class _EditCalendarScreenState extends State<EditCalendarScreen> {
  final ApiClient _api = ApiClient();
  final SessionStorage _session = SessionStorage();

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // Which days the professional has tapped to edit (day numbers 1..31)
  final Set<int> _selectedDays = {};

  // Availability type for ALL selected days
  // 'available' | 'hourAvailable' | 'unavailable'
  String _statusType = 'available';

  // Time slots to attach (for available / hourAvailable days)
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final List<({TimeOfDay start, TimeOfDay end})> _timeSlots = [];

  bool _showTimePicker = false;
  bool _pickingStart = true;
  bool _saving = false;
  String? _saveError;

  // ── colours ──────────────────────────────────────────────────────────────
  static const Color _green = Color(0xFF4CAF50);
  static const Color _yellow = Color(0xFFFFB74D);
  static const Color _red = Color(0xFFE53935);

  Color get _statusColor {
    switch (_statusType) {
      case 'hourAvailable':
        return _yellow;
      case 'unavailable':
        return _red;
      default:
        return _green;
    }
  }

  // ── API ──────────────────────────────────────────────────────────────────

  Future<void> _saveAvailability() async {
    if (_selectedDays.isEmpty) {
      AppToast.info('Please select at least one day.');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final token = await _session.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please log in again.');
      }

      final y = _focusedMonth.year;
      final m = _focusedMonth.month;

      // Build time-slots payload
      final slots = _timeSlots.map((s) => {'startTime': _toHHmm(s.start), 'endTime': _toHHmm(s.end)}).toList();

      final List<String> failed = [];

      for (final dayNum in _selectedDays.toList()..sort()) {
        final dateStr = '$y-${m.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';

        final payload = <String, dynamic>{'isAvailable': _statusType != 'unavailable', if (_statusType == 'hourAvailable') 'isPartiallyAvailable': true, if (slots.isNotEmpty) 'slots': slots};

        try {
          await _api.put('/professionals/availability/$dateStr', body: payload, token: token);
        } catch (e) {
          failed.add(dateStr);
        }
      }

      if (!mounted) return;

      if (failed.isEmpty) {
        AppToast.success('Availability updated for ${_selectedDays.length} day(s).');
        // Return true so CalendarManagementScreen can refresh
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _saveError = 'Failed to update ${failed.length} day(s): ${failed.join(', ')}';
          _saving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saveError = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  String _toHHmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(title: 'provider.profile.edit_calendar'.tr(), showNotification: false),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalendar(),
                _buildStatusSelector(),
                if (_statusType != 'unavailable') ...[_buildSelectTimes(), _buildTimeSlotsList()],
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(_saveError!, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.primaryRed)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _confirmAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
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

          // Saving overlay
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.6),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primaryRed),
                    const SizedBox(height: 16),
                    Text('Saving availability…', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomSheet: _showTimePicker ? _buildTimePickerOverlay() : null,
    );
  }

  // ── Calendar ──────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final daysInMonth = last.day;
    final leadingPadding = first.weekday - 1; // Mon=1 → 0 leading blanks
    final totalCells = leadingPadding + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textSecondary),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(year, month - 1);
                  _selectedDays.clear();
                }),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _monthName(month),
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
                  ),
                  const SizedBox(width: 4),
                  Text('$year', style: GoogleFonts.outfit(fontSize: 16, color: AppColors.textSecondary)),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, color: AppColors.textSecondary),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(year, month + 1);
                  _selectedDays.clear();
                }),
              ),
            ],
          ),

          // Day-of-week labels
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (d) => SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          // Day grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
            children: List.generate(rows * 7, (i) {
              if (i < leadingPadding) {
                final prevLast = DateTime(year, month, 0);
                final d = prevLast.day - (leadingPadding - 1 - i);
                if (d < 1) return const SizedBox();
                return Center(
                  child: Text('$d', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black26)),
                );
              }
              final dayNum = i - leadingPadding + 1;
              if (dayNum > daysInMonth) return const SizedBox();

              final isSelected = _selectedDays.contains(dayNum);
              final today = DateTime.now();
              final isToday = today.year == year && today.month == month && today.day == dayNum;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedDays.contains(dayNum)) {
                      _selectedDays.remove(dayNum);
                    } else {
                      _selectedDays.add(dayNum);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected ? _statusColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isSelected ? Border.all(color: AppColors.primaryRed, width: 1.5) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? (_statusType == 'hourAvailable' ? Colors.black87 : Colors.white) : (isToday ? AppColors.primaryRed : AppColors.textMain),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Selection hint
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              _selectedDays.isEmpty ? 'Tap days to select them for editing.' : '${_selectedDays.length} day(s) selected  •  tap to deselect',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── Status selector (replaces old binary toggles) ─────────────────────────

  Widget _buildStatusSelector() {
    final options = [
      (value: 'available', label: 'provider.profile.available'.tr(), color: _green),
      (value: 'hourAvailable', label: 'provider.profile.hour_available'.tr(), color: _yellow),
      (value: 'unavailable', label: 'provider.profile.unavailable'.tr(), color: _red),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set status for selected days',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((opt) {
              final selected = _statusType == opt.value;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _statusType = opt.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? opt.color : opt.color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: selected ? Border.all(color: opt.color, width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt.label,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : opt.color),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Time slots ────────────────────────────────────────────────────────────

  Widget _buildSelectTimes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'provider.profile.select_times'.tr(),
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'provider.profile.start_time'.tr(),
                  value: _startTime,
                  onTap: () => setState(() {
                    _pickingStart = true;
                    _showTimePicker = true;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeField(
                  label: 'provider.profile.end_time'.tr(),
                  value: _endTime,
                  onTap: () => setState(() {
                    _pickingStart = false;
                    _showTimePicker = true;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => setState(() => _timeSlots.add((start: _startTime, end: _endTime))),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.plus, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          'provider.profile.add'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                    child: Text('${_formatTime(slot.start)} – ${_formatTime(slot.end)}', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain)),
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

  // ── Time picker overlay ───────────────────────────────────────────────────

  Widget _buildTimePickerOverlay() {
    final cur = _pickingStart ? _startTime : _endTime;
    final hourCtrl = FixedExtentScrollController(initialItem: cur.hour);
    final minuteCtrl = FixedExtentScrollController(initialItem: cur.minute);

    // Declared OUTSIDE the builder so they survive localSetState rebuilds
    int hour = cur.hour;
    int minute = cur.minute;

    return StatefulBuilder(
      builder: (context, localSetState) {
        void onHourChanged(int i) => localSetState(() => hour = i);
        void onMinuteChanged(int i) => localSetState(() => minute = i);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                ),

                // Header: label + ✕
                Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        _pickingStart ? 'Start Time' : 'End Time',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                        onPressed: () => setState(() => _showTimePicker = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Live preview
                Text(
                  '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 16),

                // Drum-roll wheels
                SizedBox(
                  height: 160,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hour wheel
                      _DrumWheel(controller: hourCtrl, count: 24, label: (i) => i.toString().padLeft(2, '0'), onChanged: onHourChanged),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          ':',
                          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                      ),
                      // Minute wheel
                      _DrumWheel(controller: minuteCtrl, count: 60, label: (i) => i.toString().padLeft(2, '0'), onChanged: onMinuteChanged),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Cancel / Confirm
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showTimePicker = false),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 22),
                      ),
                    ),
                    const SizedBox(width: 28),
                    GestureDetector(
                      onTap: () {
                        // Read the wheel positions at confirm time
                        final h = hourCtrl.selectedItem;
                        final m = minuteCtrl.selectedItem;
                        setState(() {
                          if (_pickingStart) {
                            _startTime = TimeOfDay(hour: h, minute: m);
                          } else {
                            _endTime = TimeOfDay(hour: h, minute: m);
                          }
                          _showTimePicker = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(color: Color(0xFFE91E63), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.check, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _confirmAndSave() {
    if (_selectedDays.isEmpty) {
      AppToast.info('Please select at least one day.');
      return;
    }

    final statusLabel = _statusType == 'available'
        ? 'Available'
        : _statusType == 'hourAvailable'
        ? 'Hour Available'
        : 'Unavailable';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Update',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textMain),
              ),
              const SizedBox(height: 10),
              Text(
                'Mark ${_selectedDays.length} day(s) in '
                '${_monthName(_focusedMonth.month)} as "$statusLabel"'
                '${_timeSlots.isNotEmpty ? ' with ${_timeSlots.length} time slot(s)' : ''}.',
                style: GoogleFonts.outfit(fontSize: 16, height: 1.4, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primaryRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text(
                        'provider.profile.no'.tr(),
                        style: GoogleFonts.outfit(color: AppColors.primaryRed, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryGradientButton(
                      text: 'provider.profile.yes'.tr(),
                      height: 46,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _saveAvailability();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _monthName(int m) {
    const n = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return n[m - 1];
  }
}

// ── Reusable time-field chip ──────────────────────────────────────────────────

// ── Drum-roll scroll wheel ────────────────────────────────────────────────────

class _DrumWheel extends StatelessWidget {
  const _DrumWheel({required this.controller, required this.count, required this.label, required this.onChanged});

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 160,
      child: Stack(
        children: [
          // Selection highlight band
          Center(
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            perspective: 0.003,
            diameterRatio: 1.8,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) {
                final selected = controller.selectedItem == index;
                return Center(
                  child: Text(
                    label(index),
                    style: GoogleFonts.outfit(fontSize: selected ? 22 : 16, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? const Color(0xFF1A1A1A) : Colors.black38),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable time-field chip ──────────────────────────────────────────────────

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  const _TimeField({required this.label, required this.value, required this.onTap});

  String _format(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
                Text(
                  _format(value),
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMain),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
