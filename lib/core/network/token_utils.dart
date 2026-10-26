import 'dart:convert';

/// Lightweight JWT utilities — no external package needed.
class TokenUtils {
  TokenUtils._();

  /// Returns true if [token] is expired or malformed.
  static bool isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Pad to valid base64 length and decode.
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;

      final exp = payload['exp'];
      if (exp == null) return false; // no expiry = treat as valid

      final expiry =
          DateTime.fromMillisecondsSinceEpoch((exp as num).toInt() * 1000);
      // Add a 30-second buffer so we refresh slightly before true expiry.
      return DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 30)));
    } catch (_) {
      return true; // malformed token → treat as expired
    }
  }

  /// JWT `sub` claim (user id), or null if missing / malformed.
  static String? readSubject(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final sub = payload['sub'];
      if (sub == null) return null;
      return sub.toString().trim();
    } catch (_) {
      return null;
    }
  }
}
