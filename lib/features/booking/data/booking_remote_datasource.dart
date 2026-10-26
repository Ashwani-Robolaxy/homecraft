import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../../professionals/domain/models/professional_month_availability.dart';
import '../../professionals/domain/models/professional_review.dart';
import '../domain/models/booking.dart';

class BookingRemoteDatasource {
  BookingRemoteDatasource({ApiClient? api, SessionStorage? session})
      : _api = api ?? ApiClient(),
        _session = session ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<String> _token() async {
    final t = await _session.getToken();
    if (t == null || t.isEmpty) throw Exception('Please login again.');
    return t;
  }

  List<Booking> _parseList(Map<String, dynamic> map) {
    final raw = map['data'] ?? map['bookings'] ?? map['items'] ?? map['results'] ?? [];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Booking.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  // ── Client: create booking ──────────────────────────────────────────────────

  /// POST /users/bookings
  Future<Booking> createBooking({
    required String professionalId,
    required String customerLocation,
    required String date,     // YYYY-MM-DD
    String? slotStart,        // HH:MM
    String? slotEnd,          // HH:MM
    String? notes,
    String? budget,
    String? projectId,
  }) async {
    final token = await _token();

    // Build requestedShifts array if time slot provided
    final shifts = <Map<String, String>>[];
    if (slotStart != null && slotStart.isNotEmpty &&
        slotEnd != null && slotEnd.isNotEmpty) {
      shifts.add({'startTime': slotStart, 'endTime': slotEnd});
    }

    final body = <String, dynamic>{
      'professionalId': int.tryParse(professionalId) ?? professionalId,
      'bookingDate': date,
      'customerLocation': customerLocation,
      'requestedShifts': shifts,
      'description': notes ?? '',
      if (budget != null && budget.trim().isNotEmpty) 'budget': double.tryParse(budget.trim()) ?? budget.trim(),
      if (projectId != null && projectId.isNotEmpty) 'projectId': int.tryParse(projectId) ?? projectId,
    };
    final res = await _api.post('/users/bookings', body: body, token: token);
    final raw = res['data'] ?? res['booking'] ?? res;
    if (raw is Map) return Booking.fromMap(Map<String, dynamic>.from(raw));
    throw Exception('Unexpected booking response.');
  }

  // ── Client: list bookings ───────────────────────────────────────────────────

  /// GET /users/bookings?status=...
  Future<List<Booking>> fetchClientBookings({String? status}) async {
    final token = await _token();
    final query = status != null ? '?status=$status' : '';
    try {
      final res = await _api.get('/users/bookings$query', token: token);
      return _parseList(res);
    } catch (_) {
      return [];
    }
  }

  // ── Client: cancel booking ──────────────────────────────────────────────────

  /// PUT /users/bookings/{bookingId}/cancel
  Future<void> cancelBooking(int bookingId) async {
    final token = await _token();
    await _api.put('/users/bookings/$bookingId/cancel', body: {}, token: token);
  }

  // ── Professional: list bookings ─────────────────────────────────────────────

  /// GET /professionals/bookings?status=...
  Future<List<Booking>> fetchProfessionalBookings({String? status}) async {
    final token = await _token();
    final query = status != null ? '?status=$status' : '';
    try {
      final res = await _api.get('/professionals/bookings$query', token: token);
      return _parseList(res);
    } catch (_) {
      return [];
    }
  }

  // ── Client: professional availability for booking UI ───────────────────────

  /// GET /users/bookings/professionals/{professionalId}/availability?month=YYYY-MM
  Future<ProfessionalMonthAvailability> fetchProfessionalAvailabilityMonth({
    required String professionalId,
    required String monthYm,
  }) async {
    final token = await _token();
    final proId = professionalId.trim();
    if (proId.isEmpty) {
      throw ApiException('Professional id is missing.');
    }
    final month = Uri.encodeQueryComponent(monthYm);
    final res = await _api.get(
      '/users/bookings/professionals/$proId/availability?month=$month',
      token: token,
    );
    return ProfessionalMonthAvailability.fromApiResponse(res);
  }

  // ── Professional: update booking status ────────────────────────────────────

  /// PUT /professionals/bookings/{id}/status   body: { "status": "accepted"|"rejected"|"cancelled" }
  Future<void> updateBookingStatus(int bookingId, String status) async {
    final token = await _token();
    await _api.put(
      '/professionals/bookings/$bookingId/status',
      body: {'status': status},
      token: token,
    );
  }

  // ── Professional: mark booking as delivered ─────────────────────────────────

  /// POST /professionals/bookings/{bookingId}/deliver
  Future<void> deliverBooking(int bookingId) async {
    final token = await _token();
    try {
      await _api.post(
        '/professionals/bookings/$bookingId/deliver',
        body: {'delivery_status': 'pending', 'deliveryStatus': 'pending'},
        token: token,
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('null') || errStr.toLowerCase().contains('delivery status')) {
        try {
          await _api.put(
            '/professionals/bookings/$bookingId/status',
            body: {'status': 'accepted', 'delivery_status': 'pending', 'deliveryStatus': 'pending'},
            token: token,
          );
          await _api.post(
            '/professionals/bookings/$bookingId/deliver',
            body: {'delivery_status': 'pending', 'deliveryStatus': 'pending'},
            token: token,
          );
          return;
        } catch (_) {}
        throw ApiException("Server error: Booking #$bookingId has 'null' delivery status in database. Run database update to set delivery_status = 'pending'.");
      }
      rethrow;
    }
  }

  // ── Client: accept booking delivery ─────────────────────────────────────────

  /// POST /users/bookings/{bookingId}/accept
  Future<void> acceptBookingDelivery(int bookingId) async {
    final token = await _token();
    await _api.post(
      '/users/bookings/$bookingId/accept',
      body: {'delivery_status': 'delivered', 'deliveryStatus': 'delivered'},
      token: token,
    );
  }

  // ── Client: reject booking delivery ─────────────────────────────────────────

  /// POST /users/bookings/{bookingId}/reject
  Future<void> rejectBookingDelivery(int bookingId) async {
    final token = await _token();
    await _api.post(
      '/users/bookings/$bookingId/reject',
      body: {'delivery_status': 'delivered', 'deliveryStatus': 'delivered'},
      token: token,
    );
  }

  // ── Client: review and rate professional for booking ────────────────────────

  /// POST /users/bookings/{bookingId}/review
  Future<void> reviewBooking(int bookingId, {required int rating, String? comment}) async {
    final token = await _token();
    final body = <String, dynamic>{
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    };
    await _api.post('/users/bookings/$bookingId/review', body: body, token: token);
  }

  // ── Professional: get reviews received by me ───────────────────────────────

  /// GET /professionals/bookings/me/reviews
  Future<ProfessionalReviewsSummary> fetchProfessionalReviews() async {
    final token = await _token();
    final res = await _api.get('/professionals/bookings/me/reviews', token: token);
    if (res is Map) {
      return ProfessionalReviewsSummary.fromMap(Map<String, dynamic>.from(res));
    }
    return const ProfessionalReviewsSummary(success: true, averageRating: 0.0, totalReviews: 0, reviews: []);
  }
}

