enum BookingStatus { pending, accepted, rejected, cancelled }

extension BookingStatusX on BookingStatus {
  static BookingStatus fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'accepted':
        return BookingStatus.accepted;
      case 'rejected':
        return BookingStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive => this == BookingStatus.pending || this == BookingStatus.accepted;
  bool get isHistory => this == BookingStatus.rejected || this == BookingStatus.cancelled;
}

class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.professionalId,
    required this.professionalName,
    this.professionalPhoto,
    this.professionalProfession,
    this.clientId,
    this.clientName,
    this.clientPhoto,
    this.scheduledDate,
    this.slotStart,
    this.slotEnd,
    this.location,
    this.notes,
    this.projectId,
    this.createdAt,
  });

  final int id;
  final BookingStatus status;
  final String professionalId;
  final String professionalName;
  final String? professionalPhoto;
  final String? professionalProfession;
  final String? clientId;
  final String? clientName;
  final String? clientPhoto;
  final DateTime? scheduledDate;
  final String? slotStart;
  final String? slotEnd;
  final String? location;
  final String? notes;
  final String? projectId;
  final DateTime? createdAt;

  factory Booking.fromMap(Map<String, dynamic> m) {
    // ── ID ──────────────────────────────────────────────────────────────────
    final id = _parseInt(m['id'] ?? m['bookingId']) ?? 0;

    // ── Status ───────────────────────────────────────────────────────────────
    final status = BookingStatusX.fromString(
        (m['status'] ?? m['bookingStatus'] ?? '').toString());

    // ── Professional ─────────────────────────────────────────────────────────
    final Map<String, dynamic> pro = _subMap(m, ['professional', 'provider', 'professionalUser']) ?? {};
    final professionalId =
        (m['professionalId'] ?? pro['id'] ?? pro['_id'] ?? '').toString();
    final professionalName = _joinName(
      pro['displayName'] ?? pro['fullName'] ?? pro['name'] ??
          _joinParts(pro['firstName'], pro['lastName']),
      fallback: 'Professional',
    );
    final professionalPhoto =
        (pro['profilePhoto'] ?? pro['avatar'] ?? pro['photo'] ?? '').toString().trim();
    final professionalProfession =
        (pro['profession'] ?? pro['category'] ?? pro['specialization'] ?? '').toString().trim();

    // ── Client ───────────────────────────────────────────────────────────────
    final Map<String, dynamic> client = _subMap(m, ['client', 'user', 'clientUser']) ?? {};
    final clientId = (m['userId'] ?? m['clientId'] ?? client['id'] ?? '').toString();
    final clientName = _joinName(
      client['displayName'] ?? client['fullName'] ?? client['name'] ??
          _joinParts(client['firstName'], client['lastName']),
      fallback: 'Client',
    );
    final clientPhoto =
        (client['profilePhoto'] ?? client['avatar'] ?? client['photo'] ?? '').toString().trim();

    // ── Schedule ─────────────────────────────────────────────────────────────
    final rawDate = m['date'] ?? m['scheduledDate'] ?? m['bookingDate'] ?? m['appointmentDate'];
    final scheduledDate = _parseDate(rawDate);
    final slotStart = (m['slotStart'] ?? m['startTime'] ?? m['timeStart'] ?? '').toString().trim();
    final slotEnd = (m['slotEnd'] ?? m['endTime'] ?? m['timeEnd'] ?? '').toString().trim();

    // ── Other ────────────────────────────────────────────────────────────────
    final location = (m['location'] ?? m['address'] ?? '').toString().trim();
    final notes = (m['notes'] ?? m['message'] ?? m['description'] ?? '').toString().trim();
    final projectId = (m['projectId'] ?? m['contextProjectId'] ?? '').toString().trim();
    final createdAt = _parseDate(m['createdAt'] ?? m['created_at']);

    return Booking(
      id: id,
      status: status,
      professionalId: professionalId,
      professionalName: professionalName,
      professionalPhoto: professionalPhoto.isEmpty ? null : professionalPhoto,
      professionalProfession: professionalProfession.isEmpty ? null : professionalProfession,
      clientId: clientId.isEmpty ? null : clientId,
      clientName: clientName,
      clientPhoto: clientPhoto.isEmpty ? null : clientPhoto,
      scheduledDate: scheduledDate,
      slotStart: slotStart.isEmpty ? null : slotStart,
      slotEnd: slotEnd.isEmpty ? null : slotEnd,
      location: location.isEmpty ? null : location,
      notes: notes.isEmpty ? null : notes,
      projectId: projectId.isEmpty ? null : projectId,
      createdAt: createdAt,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static Map<String, dynamic>? _subMap(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m[k] is Map) return Map<String, dynamic>.from(m[k] as Map);
    }
    return null;
  }

  static String? _joinParts(dynamic first, dynamic last) {
    final f = (first ?? '').toString().trim();
    final l = (last ?? '').toString().trim();
    if (f.isEmpty && l.isEmpty) return null;
    return '$f $l'.trim();
  }

  static String _joinName(dynamic raw, {required String fallback}) {
    final s = (raw ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }
}
