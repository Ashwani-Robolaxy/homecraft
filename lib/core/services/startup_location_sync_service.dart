import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/session_storage.dart';
import '../../features/auth/domain/models/app_user.dart';

/// Syncs device coordinates to backend when app starts.
/// All failures are swallowed silently — this is best-effort only.
class StartupLocationSyncService {
  StartupLocationSyncService({ApiClient? apiClient, SessionStorage? sessionStorage})
      : _api = apiClient ?? ApiClient(),
        _session = sessionStorage ?? SessionStorage();

  final ApiClient _api;
  final SessionStorage _session;

  Future<void> syncForUser(AppUser user) async {
    if (user.isProvider) return; // Do not overwrite professional's company map location with their device GPS coordinates
    try {
      final token = await _session.getToken();
      if (token == null || token.isEmpty) return;

      // ── Check location services ───────────────────────────────────────────
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // ── Get position (last-known first, fresh with short timeout) ─────────
      Position? position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          ).timeout(const Duration(seconds: 8));
        } catch (_) {
          // location unavailable on simulator or no GPS fix — skip
          return;
        }
      }

      // ── Push to backend ───────────────────────────────────────────────────
      final endpoint =
          user.isProvider ? '/professionals/location' : '/users/location';

      await _api.put(
        endpoint,
        body: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        token: token,
      );
    } on ApiException catch (e) {
      // 401 = token expired / not yet refreshed — silent, retry next launch
      debugPrint('[LocationSync] API error (ignored): ${e.message}');
    } catch (e) {
      debugPrint('[LocationSync] Skipped: $e');
    }
  }
}
