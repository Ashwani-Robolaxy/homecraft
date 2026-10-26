import 'calendar_day_status.dart';

/// One time interval for a day (Swagger: `shifts` on write; API may return `slots` or `shifts`).
class AvailabilityTimeSlot {
  const AvailabilityTimeSlot({required this.startTime, required this.endTime});

  final String startTime;
  final String endTime;
}

/// Parsed row for one calendar day from [GET /professionals/availability].
class ProfessionalDayAvailability {
  const ProfessionalDayAvailability({required this.date, required this.status, this.slots = const []});

  final DateTime date;
  final CalendarDayStatus status;
  final List<AvailabilityTimeSlot> slots;
}

/// Monthly availability for the logged-in professional.
///
/// Swagger: `GET /professionals/availability?month=YYYY-MM`
class ProfessionalMonthAvailability {
  const ProfessionalMonthAvailability({required this.month, required this.days});

  /// Requested month `YYYY-MM` when provided by the API; may be empty.
  final String month;
  final List<ProfessionalDayAvailability> days;

  /// One entry per day for the calendar grid (date-only keys).
  Map<DateTime, CalendarDayStatus> toStatusByDate() {
    final map = <DateTime, CalendarDayStatus>{};
    for (final d in days) {
      map[_dateOnly(d.date)] = d.status;
    }
    return map;
  }

  /// Full day rows (status + time slots) keyed by calendar date.
  Map<DateTime, ProfessionalDayAvailability> toDetailsByDate() {
    final map = <DateTime, ProfessionalDayAvailability>{};
    for (final d in days) {
      map[_dateOnly(d.date)] = d;
    }
    return map;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Parses the JSON envelope from [ApiClient.get] (`data` or top-level).
  factory ProfessionalMonthAvailability.fromApiResponse(Map<String, dynamic> map) {
    final data = map['data'];
    final root = data is Map<String, dynamic> ? data : map;

    final month = (root['month'] ?? root['yearMonth'] ?? '').toString().trim();

    final mapByDate = <DateTime, ProfessionalDayAvailability>{};

    final dayList = _extractDayList(root);
    for (final entry in dayList) {
      if (entry is! Map) continue;
      final parsed = _parseDay(Map<String, dynamic>.from(entry));
      if (parsed != null) {
        mapByDate[_dateOnly(parsed.date)] = parsed;
      }
    }

    int statusPriority(CalendarDayStatus status) {
      switch (status) {
        case CalendarDayStatus.booked:
          return 4;
        case CalendarDayStatus.unavailable:
          return 3;
        case CalendarDayStatus.hourAvailable:
          return 2;
        case CalendarDayStatus.available:
          return 1;
      }
    }

    void applyDateList(dynamic raw, CalendarDayStatus status) {
      if (raw is! List) return;
      for (final item in raw) {
        final dt = DateTime.tryParse(item.toString());
        if (dt == null) continue;
        final day = _dateOnly(dt);
        final existing = mapByDate[day];
        if (existing == null) {
          mapByDate[day] = ProfessionalDayAvailability(date: day, status: status);
        } else {
          final existingPriority = statusPriority(existing.status);
          final newPriority = statusPriority(status);
          if (newPriority > existingPriority) {
            mapByDate[day] = ProfessionalDayAvailability(date: day, status: status, slots: existing.slots);
          }
        }
      }
    }

    applyDateList(root['availableDates'], CalendarDayStatus.available);
    applyDateList(root['hourAvailableDates'], CalendarDayStatus.hourAvailable);
    applyDateList(root['unavailableDates'], CalendarDayStatus.unavailable);
    applyDateList(root['bookedDates'], CalendarDayStatus.booked);

    final days = mapByDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return ProfessionalMonthAvailability(month: month, days: days.map((e) => e.value).toList());
  }

  static List<dynamic> _extractDayList(Map<String, dynamic> root) {
    for (final key in const ['days', 'availability', 'items', 'calendar']) {
      final v = root[key];
      if (v is List) return v;
    }
    return const [];
  }

  static ProfessionalDayAvailability? _parseDay(Map<String, dynamic> e) {
    final rawDate = (e['date'] ?? e['day'] ?? e['availableDate'] ?? '').toString().trim();
    if (rawDate.isEmpty) return null;
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return null;
    final date = _dateOnly(dt);

    if (_isBooked(e)) {
      return ProfessionalDayAvailability(date: date, status: CalendarDayStatus.booked, slots: _parseSlots(e));
    }

    final rawSlots = e['shifts'] ?? e['slots'] ?? e['timeSlots'];
    bool hasAnyBookedShift = false;
    bool hasAnyUnbookedShift = false;

    if (rawSlots is List) {
      for (final item in rawSlots) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        if (_boolish(m['isBooked'] ?? m['booked'] ?? m['hasBooking'])) {
          hasAnyBookedShift = true;
        } else {
          hasAnyUnbookedShift = true;
        }
      }
    }

    final slots = _parseSlots(e);
    final partial = _boolish(e['isPartiallyAvailable'] ?? e['partial'] ?? e['partiallyAvailable']);

    final bool? isAvailableOpt = () {
      if (e.containsKey('isAvailable')) {
        final v = e['isAvailable'];
        if (v == null) return null;
        return _boolish(v);
      }
      if (e.containsKey('available')) {
        final v = e['available'];
        if (v == null) return null;
        return _boolish(v);
      }
      return null;
    }();

    final CalendarDayStatus status;

    if (hasAnyBookedShift && !hasAnyUnbookedShift) {
      status = CalendarDayStatus.booked;
    } else if (isAvailableOpt == false) {
      status = CalendarDayStatus.unavailable;
    } else if (isAvailableOpt == true) {
      if (partial || slots.isNotEmpty || (hasAnyBookedShift && hasAnyUnbookedShift)) {
        status = CalendarDayStatus.hourAvailable;
      } else {
        status = CalendarDayStatus.available;
      }
    } else {
      status = (partial || slots.isNotEmpty || (hasAnyBookedShift && hasAnyUnbookedShift)) ? CalendarDayStatus.hourAvailable : _statusFromString((e['status'] ?? e['type'] ?? '').toString());
    }

    return ProfessionalDayAvailability(date: date, status: status, slots: slots);
  }

  static bool _isBooked(Map<String, dynamic> e) {
    if (_boolish(e['isBooked'] ?? e['booked'] ?? e['hasBooking'])) return true;
    return _statusIndicatesBooked((e['status'] ?? e['type'] ?? '').toString());
  }

  static bool _statusIndicatesBooked(String raw) {
    final v = raw.toLowerCase();
    return v.contains('book');
  }

  static CalendarDayStatus _statusFromString(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('book')) return CalendarDayStatus.booked;
    if (v.contains('hour') || v.contains('partial')) return CalendarDayStatus.hourAvailable;
    if (v.contains('avail') && !v.contains('un')) return CalendarDayStatus.available;
    return CalendarDayStatus.unavailable;
  }

  static bool _boolish(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static List<AvailabilityTimeSlot> _parseSlots(Map<String, dynamic> e) {
    final raw = e['shifts'] ?? e['slots'] ?? e['timeSlots'];
    if (raw is! List) return const [];
    final out = <AvailabilityTimeSlot>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final start = (m['startTime'] ?? m['start'] ?? '').toString();
      final end = (m['endTime'] ?? m['end'] ?? '').toString();
      if (start.isEmpty || end.isEmpty) continue;

      out.add(AvailabilityTimeSlot(startTime: start, endTime: end));
    }
    return out;
  }
}
