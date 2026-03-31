import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../booking/data/booking_remote_datasource.dart';
import '../../../booking/domain/models/booking.dart';

enum DayStatus { available, unavailable, hourAvailable, booked }

class CalendarManagementScreen extends StatefulWidget {
  const CalendarManagementScreen({super.key});

  @override
  State<CalendarManagementScreen> createState() => _CalendarManagementScreenState();
}

class _CalendarManagementScreenState extends State<CalendarManagementScreen> {
  final ApiClient _api = ApiClient();
  final SessionStorage _session = SessionStorage();
  final BookingRemoteDatasource _bookingDs = BookingRemoteDatasource();
  DateTime _focusedMonth = DateTime.now();
  int _selectedTab = 0; // 0: Pending, 1: Accepted, 2: History
  bool _loading = true;
  String? _error;
  final Map<DateTime, DayStatus> _dayStatusByDate = {};
  final List<_AppointmentItem> _bookedItems = [];
  final List<_AppointmentItem> _acceptedItems = [];
  final List<_AppointmentItem> _historyItems = [];

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
      final token = await _session.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('Please login again to load availability.');
      }
      final monthParam =
          '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';
      final map = await _api.get(
        '/professionals/availability?month=$monthParam',
        token: token,
      );
      _parseAvailabilityPayload(map);
      if (!mounted) return;
      setState(() => _loading = false);
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
      await _bookingDs.acceptBooking(b.id);
      AppToast.success('Booking accepted.');
      await _loadBookings();
    } catch (e) {
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  Future<void> _rejectBooking(Booking b) async {
    setState(() => _bookingBusy = true);
    try {
      await _bookingDs.rejectBooking(b.id);
      AppToast.success('Booking rejected.');
      await _loadBookings();
    } catch (e) {
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  void _parseAvailabilityPayload(Map<String, dynamic> map) {
    _dayStatusByDate.clear();
    _bookedItems.clear();
    _acceptedItems.clear();
    _historyItems.clear();

    final data = map['data'];
    final root = data is Map<String, dynamic> ? data : map;

    final dayList = _extractList(root, const ['availability', 'days', 'items', 'calendar']);
    for (final entry in dayList.whereType<Map>()) {
      final e = Map<String, dynamic>.from(entry);
      final rawDate = (e['date'] ?? e['day'] ?? e['availableDate'] ?? '').toString().trim();
      final dt = DateTime.tryParse(rawDate);
      if (dt == null) continue;
      _dayStatusByDate[_dateOnly(dt)] = _statusFromRaw((e['status'] ?? e['type'] ?? '').toString());
    }

    _applyDateListStatus(root['bookedDates'], DayStatus.booked);
    _applyDateListStatus(root['unavailableDates'], DayStatus.unavailable);
    _applyDateListStatus(root['hourAvailableDates'], DayStatus.hourAvailable);
    _applyDateListStatus(root['availableDates'], DayStatus.available);

    _bookedItems.addAll(_extractAppointments(root, keys: const ['booked', 'bookings']));
    _acceptedItems.addAll(_extractAppointments(root, keys: const ['accepted', 'acceptedBookings']));
    _historyItems.addAll(_extractAppointments(root, keys: const ['history', 'pastBookings']));
  }

  List<dynamic> _extractList(Map<String, dynamic> root, List<String> keys) {
    for (final key in keys) {
      final v = root[key];
      if (v is List) return v;
    }
    return const [];
  }

  void _applyDateListStatus(dynamic raw, DayStatus status) {
    if (raw is! List) return;
    for (final d in raw) {
      final dt = DateTime.tryParse(d.toString());
      if (dt != null) _dayStatusByDate[_dateOnly(dt)] = status;
    }
  }

  List<_AppointmentItem> _extractAppointments(Map<String, dynamic> root, {required List<String> keys}) {
    for (final key in keys) {
      final v = root[key];
      if (v is List) {
        return v.whereType<Map>().map((raw) {
          final e = Map<String, dynamic>.from(raw);
          final start = (e['startTime'] ?? e['dateTime'] ?? e['time'] ?? e['scheduledAt'] ?? '').toString();
          final end = (e['endTime'] ?? '').toString();
          final when = end.isEmpty || start.isEmpty ? start : '$start - $end';
          final addr = (e['address'] ?? e['location'] ?? e['city'] ?? '—').toString();
          final name = (e['clientName'] ?? e['name'] ?? e['userName'] ?? 'Client').toString();
          return _AppointmentItem(name: name, dateTime: when.isEmpty ? '—' : when, address: addr);
        }).toList();
      }
    }
    return const [];
  }

  DayStatus _statusForDay(DateTime day) {
    return _dayStatusByDate[_dateOnly(day)] ?? DayStatus.unavailable;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DayStatus _statusFromRaw(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('book')) return DayStatus.booked;
    if (v.contains('hour')) return DayStatus.hourAvailable;
    if (v.contains('avail') && !v.contains('un')) return DayStatus.available;
    return DayStatus.unavailable;
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
            if (_loading)
              const _CalendarShimmer()
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadAvailability, child: const Text('Retry')),
                  ],
                ),
              )
            else ...[
            _buildLegend(),
            _buildCalendar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final refreshed =
                        await context.push<bool>('/edit-calendar');
                    if (refreshed == true && mounted) _loadAvailability();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                    elevation: 2,
                  ),
                  child: Text(
                    'provider.profile.edit_your_availability'.tr(),
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
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
                onPressed: () {
                  setState(() => _focusedMonth = DateTime(year, month - 1));
                  _loadAvailability();
                },
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
                onPressed: () {
                  setState(() => _focusedMonth = DateTime(year, month + 1));
                  _loadAvailability();
                },
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
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
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
              return Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status == DayStatus.hourAvailable
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
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
    final bookings = _selectedTab == 0
        ? _pendingBookings
        : _selectedTab == 1
            ? _acceptedBookings
            : _historyBookings;

    if (_bookingBusy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
      );
    }

    if (bookings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Center(
          child: Text(
            'No appointments in this section.',
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
          onAccept: isPending ? () => _confirmAndAct('Accept', () => _acceptBooking(b)) : null,
          onReject: isPending ? () => _confirmAndAct('Reject', () => _rejectBooking(b)) : null,
          isHistory: isHistory,
        );
      },
    );
  }

  Future<void> _confirmAndAct(String label, Future<void> Function() action) async {
    final color = label == 'Accept' ? const Color(0xFF4CAF50) : AppColors.primaryRed;
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
                '$label Booking',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to $label this booking?',
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
                        child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.black54, fontWeight: FontWeight.w600)),
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
                        child: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
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
  const _BookingCard({
    required this.booking,
    this.onAccept,
    this.onReject,
    this.isHistory = false,
  });

  final Booking booking;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.clientName ?? 'Client',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                const SizedBox(height: 6),
                if (b.scheduledDate != null) ...[
                  Row(children: [
                    const Icon(LucideIcons.calendarDays, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      '${b.scheduledDate!.day}/${b.scheduledDate!.month}/${b.scheduledDate!.year}'
                      '${b.slotStart != null ? "  ${b.slotStart}" : ""}'
                      '${b.slotEnd != null ? " – ${b.slotEnd}" : ""}',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ]),
                  const SizedBox(height: 4),
                ],
                if (b.location != null && b.location!.isNotEmpty)
                  Row(children: [
                    const Icon(LucideIcons.mapPin, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(b.location!,
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ]),
                const SizedBox(height: 6),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(b.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(b.status.label,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(b.status))),
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
                      child: Text('Accept', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
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
                      child: Text('Reject', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending: return Colors.orange;
      case BookingStatus.accepted: return const Color(0xFF0095FF);
      case BookingStatus.rejected: return AppColors.primaryRed;
      case BookingStatus.cancelled: return Colors.grey;
    }
  }
}

class _AppointmentItem {
  const _AppointmentItem({required this.name, required this.dateTime, required this.address});
  final String name;
  final String dateTime;
  final String address;
}


// ---------------------------------------------------------------------------
// Pure-Flutter shimmer skeleton for the calendar loading state
// ---------------------------------------------------------------------------

class _CalendarShimmer extends StatefulWidget {
  const _CalendarShimmer();

  @override
  State<_CalendarShimmer> createState() => _CalendarShimmerState();
}

class _CalendarShimmerState extends State<_CalendarShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
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
            children: [
              _shimmerBox(width: 32, height: 32, radius: 16),
              _shimmerBox(width: 140, height: 22, radius: 6),
              _shimmerBox(width: 32, height: 32, radius: 16),
            ],
          ),
          const SizedBox(height: 20),

          // Day-of-week label row
          Row(
            children: List.generate(
              7,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _shimmerBox(height: 14, radius: 4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Calendar grid: 7 columns x 5 rows of day cells
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: 35,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, __) => _shimmerBox(radius: 10),
          ),
          const SizedBox(height: 28),

          // Section label
          _shimmerBox(width: 130, height: 16, radius: 4),
          const SizedBox(height: 14),

          // Three appointment skeleton cards
          for (var i = 0; i < 3; i++) ...[
            _appointmentCard(),
            const SizedBox(height: 12),
          ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
              children: [
                _shimmerBox(height: 14, radius: 4),
                const SizedBox(height: 8),
                _shimmerBox(width: 120, height: 12, radius: 4),
              ],
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
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
      final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 40.0;
      return CustomPaint(
        size: Size(w, h),
        painter: _ShimmerPainter(offset: offset),
      );
    });
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
      colors: const [
        Color(0xFFEDEDED),
        Color(0xFFF8F8F8),
        Color(0xFFFFFFFF),
        Color(0xFFF8F8F8),
        Color(0xFFEDEDED),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.offset != offset;
}
