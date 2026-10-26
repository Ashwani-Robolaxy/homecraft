import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/models/professional_month_availability.dart';

/// [GET /professionals/availability](http://13.39.19.165:5000/docs/#/) — monthly availability (pro JWT).
class ProfessionalAvailabilityRemoteDatasource {
  ProfessionalAvailabilityRemoteDatasource({ApiClient? api, SessionStorage? session})
      : _api = api ?? ApiClient(),
        _session = session ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;

  /// `monthYm` must be `YYYY-MM` (required query param per Swagger).
  Future<ProfessionalMonthAvailability> fetchMyMonthlyAvailability(String monthYm) async {
    final token = await _session.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Please login again to load availability.');
    }
    final q = Uri.encodeQueryComponent(monthYm);
    final map = await _api.get('/professionals/availability?month=$q', token: token);
    return ProfessionalMonthAvailability.fromApiResponse(map);
  }
}
