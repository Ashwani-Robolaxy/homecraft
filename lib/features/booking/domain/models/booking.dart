import '../../../../core/network/api_config.dart';

enum BookingStatus { pending, accepted, rejected, cancelled, completed }

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
      case 'completed':
        return BookingStatus.completed;
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
      case BookingStatus.completed:
        return 'Completed';
    }
  }

  /// EasyLocalization key; use `status.l10nKey.tr()`.
  String get l10nKey {
    switch (this) {
      case BookingStatus.pending:
        return 'booking.status_pending';
      case BookingStatus.accepted:
        return 'booking.status_accepted';
      case BookingStatus.rejected:
        return 'booking.status_rejected';
      case BookingStatus.cancelled:
        return 'booking.status_cancelled';
      case BookingStatus.completed:
        return 'booking.status_completed';
    }
  }

  bool get isActive => this == BookingStatus.pending || this == BookingStatus.accepted;
  bool get isHistory => this == BookingStatus.rejected || this == BookingStatus.cancelled || this == BookingStatus.completed;
}

enum DeliveryStatus { pending, delivered, accepted, rejected }

extension DeliveryStatusX on DeliveryStatus {
  static DeliveryStatus fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'accepted':
        return DeliveryStatus.accepted;
      case 'rejected':
        return DeliveryStatus.rejected;
      default:
        return DeliveryStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Pending Delivery';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.accepted:
        return 'Delivery Accepted';
      case DeliveryStatus.rejected:
        return 'Delivery Rejected';
    }
  }

  String get l10nKey {
    switch (this) {
      case DeliveryStatus.pending:
        return 'booking.delivery_pending';
      case DeliveryStatus.delivered:
        return 'booking.delivery_delivered';
      case DeliveryStatus.accepted:
        return 'booking.delivery_accepted';
      case DeliveryStatus.rejected:
        return 'booking.delivery_rejected';
    }
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.status,
    this.deliveryStatus = DeliveryStatus.pending,
    this.hasReview = false,
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
    this.budget,
    this.projectId,
    this.createdAt,
  });

  final int id;
  final BookingStatus status;
  final DeliveryStatus deliveryStatus;
  final bool hasReview;
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
  final String? budget;
  final String? projectId;
  final DateTime? createdAt;

  factory Booking.fromMap(Map<String, dynamic> m) {
    // ── ID ──────────────────────────────────────────────────────────────────
    final id = _parseInt(m['id'] ?? m['bookingId']) ?? 0;

    // ── Status ───────────────────────────────────────────────────────────────
    final status = BookingStatusX.fromString((m['status'] ?? m['bookingStatus'] ?? '').toString());
    final deliveryStatus = DeliveryStatusX.fromString((m['deliveryStatus'] ?? m['delivery_status'] ?? '').toString());
    final hasReview = m['hasReview'] == true || m['isReviewed'] == true || m['review'] != null;

    // ── Professional ─────────────────────────────────────────────────────────
    final Map<String, dynamic> pro = _subMap(m, ['professional', 'provider', 'professionalUser', 'pro', 'professionalDetails']) ?? {};
    var professionalId = (m['professionalId'] ?? pro['id'] ?? pro['_id'] ?? '').toString();
    if (professionalId.isEmpty && m['professional'] != null && m['professional'] is! Map) {
      professionalId = m['professional'].toString();
    }

    final nameFromPro = _coalesceStr(pro, ['displayName', 'fullName', 'name', 'username', 'companyName']);
    final nameFromJoined = _joinParts(pro['firstName'], pro['lastName']) ?? '';
    final nameFromRoot = _coalesceStr(m, ['professionalName', 'professionalDisplayName', 'providerName', 'proName', 'professionalFullName']);
    final professionalName = _firstNonEmpty([nameFromPro, nameFromJoined, nameFromRoot]) ?? 'Professional';

    final photoFromPro = _coalesceStr(pro, ['profilePhotoUrl', 'profilePhoto', 'avatar', 'photo', 'profileImageUrl', 'photoUrl', 'imageUrl', 'picture']);
    final photoFromRoot = _coalesceStr(m, ['professionalPhotoUrl', 'professionalPhoto', 'professionalImageUrl', 'professionalAvatar']);
    final professionalPhotoRaw = _firstNonEmpty([photoFromPro, photoFromRoot]) ?? '';
    final professionalPhoto = professionalPhotoRaw.isEmpty ? null : _absoluteUrl(professionalPhotoRaw);

    final specFromPro = _coalesceStr(pro, [
      'profession',
      'category',
      'specialization',
      'specialty',
      'speciality',
      'trade',
      'jobTitle',
      'role',
      'title',
      'categoryName',
      'serviceType',
      'professionLabel',
    ]);
    final specFromRoot = _coalesceStr(m, ['professionalProfession', 'professionalSpecialty', 'profession', 'category', 'specialty', 'speciality', 'serviceType', 'jobTitle']);
    final professionalProfessionRaw = _firstNonEmpty([specFromPro, specFromRoot]) ?? '';
    final professionalProfession = professionalProfessionRaw.isEmpty ? null : professionalProfessionRaw;

    // ── Client ───────────────────────────────────────────────────────────────
    final Map<String, dynamic> client = _subMap(m, ['client', 'user', 'clientUser', 'customer', 'customerUser']) ?? {};
    final clientId = (m['userId'] ?? m['clientId'] ?? client['id'] ?? '').toString();
    final clientName = _joinName(
      client['username'] ?? client['displayName'] ?? client['fullName'] ?? client['name'] ?? m['customerName'] ?? _joinParts(client['firstName'], client['lastName']),
      fallback: 'Client',
    );
    final clientPhotoRaw = (client['profilePhoto'] ?? client['avatar'] ?? client['photo'] ?? client['imageUrl'] ?? m['clientPhoto'] ?? m['userPhoto'] ?? '').toString().trim();
    final clientPhoto = clientPhotoRaw.isEmpty ? null : _absoluteUrl(clientPhotoRaw);

    // ── Schedule ─────────────────────────────────────────────────────────────
    final rawDate = m['scheduledDate'] ?? m['bookingDate'] ?? m['date'] ?? m['appointmentDate'];
    final scheduledDate = _parseDate(rawDate);

    String? slotStart;
    String? slotEnd;
    if (m['requestedShifts'] is List && (m['requestedShifts'] as List).isNotEmpty) {
      final shift = (m['requestedShifts'] as List).first;
      if (shift is Map) {
        slotStart = shift['startTime']?.toString().trim();
        slotEnd = shift['endTime']?.toString().trim();
      }
    }
    if (slotStart == null || slotStart.isEmpty) {
      slotStart = (m['slotStart'] ?? m['startTime'] ?? m['timeStart'] ?? '').toString().trim();
    }
    if (slotEnd == null || slotEnd.isEmpty) {
      slotEnd = (m['slotEnd'] ?? m['endTime'] ?? m['timeEnd'] ?? '').toString().trim();
    }

    // ── Other ────────────────────────────────────────────────────────────────
    final location = (m['location'] ?? m['customerLocation'] ?? m['address'] ?? '').toString().trim();
    final budgetRaw = m['budget'] ?? m['budgetAmount'] ?? m['price'] ?? m['amount'];
    final budgetStr = (budgetRaw ?? '').toString().trim();
    final budget = budgetStr.isEmpty ? null : budgetStr;
    final notes = (m['notes'] ?? m['description'] ?? m['message'] ?? '').toString().trim();
    final projectId = (m['projectId'] ?? m['contextProjectId'] ?? '').toString().trim();
    final createdAt = _parseDate(m['createdAt'] ?? m['created_at']);

    return Booking(
      id: id,
      status: status,
      deliveryStatus: deliveryStatus,
      hasReview: hasReview,
      professionalId: professionalId,
      professionalName: professionalName,
      professionalPhoto: professionalPhoto,
      professionalProfession: professionalProfession,
      clientId: clientId.isEmpty ? null : clientId,
      clientName: clientName,
      clientPhoto: clientPhoto,
      scheduledDate: scheduledDate,
      slotStart: slotStart.isEmpty ? null : slotStart,
      slotEnd: slotEnd.isEmpty ? null : slotEnd,
      location: location.isEmpty ? null : location,
      notes: notes.isEmpty ? null : notes,
      budget: budget,
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

  /// First non-empty trimmed string from [candidates].
  static String? _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final t = c.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  /// First non-empty value among [keys] on [map].
  static String _coalesceStr(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String _absoluteUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) : ApiConfig.baseUrl;
    return '$base${t.startsWith('/') ? t : '/$t'}';
  }
}
