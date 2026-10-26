import 'package:shared_preferences/shared_preferences.dart';

/// Persisted notification toggles (push affects in-app foreground handling).
class NotificationPreferences {
  NotificationPreferences._();

  static const _kPush = 'push_notifications_enabled';
  static const _kEmail = 'email_notifications_enabled';

  static bool _pushEnabled = true;
  static bool _emailEnabled = true;
  static bool _loaded = false;

  static bool get pushEnabled => _pushEnabled;
  static bool get emailEnabled => _emailEnabled;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _pushEnabled = p.getBool(_kPush) ?? true;
    _emailEnabled = p.getBool(_kEmail) ?? true;
    _loaded = true;
  }

  /// No-op if already loaded (e.g. from [main]); safe to call multiple times.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  static Future<void> setPushEnabled(bool value) async {
    _pushEnabled = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPush, value);
  }

  static Future<void> setEmailEnabled(bool value) async {
    _emailEnabled = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEmail, value);
  }
}
