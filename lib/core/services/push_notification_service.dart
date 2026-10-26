import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/notification_preferences.dart';
import '../storage/session_storage.dart';

/// Local notifications + FCM listeners so pushes show in foreground (Android)
/// and taps can be handled later via [onNotificationOpened].
class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'General';

  /// Called when user taps a notification that carried [payload] / opened from FCM.
  void Function(Map<String, dynamic> data)? onNotificationOpened;

  Future<void> initialize() async {
    if (kIsWeb) return;

    // Register lifecycle observer so we sync with system permission in real-time.
    WidgetsBinding.instance.addObserver(this);

    await _ensureNotificationPermissions();

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(_channelId, _channelName, description: 'App notifications', importance: Importance.high),
    );

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _dispatchOpened(initial.data);
    }
  }

  /// Called every time the app comes back to the foreground.
  /// Syncs [NotificationPreferences.pushEnabled] with the real system
  /// notification permission so the in-app toggle is always accurate.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSystemPermission();
    }
  }

  Future<void> _syncSystemPermission() async {
    if (kIsWeb) return;
    try {
      final bool granted;
      if (Platform.isAndroid) {
        granted = await Permission.notification.isGranted;
      } else if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        granted = settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional;
      } else {
        return;
      }
      // Only write if it changed to avoid unnecessary disk I/O.
      if (NotificationPreferences.pushEnabled != granted) {
        await NotificationPreferences.setPushEnabled(granted);
      }
    } catch (_) {}
  }

  Future<void> _ensureNotificationPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } else if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true, provisional: false);
      await _local.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    // Payload string is best-effort; deep links should use data keys from server.
    _dispatchOpened({'payload': payload});
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // Always reload so the toggle takes effect immediately without a restart.
    await NotificationPreferences.load();
    if (!NotificationPreferences.pushEnabled) return;

    final n = message.notification;
    if (n == null) return;

    final currentUser = await SessionStorage().getUser();
    if (currentUser != null) {
      final senderId = message.data['senderId']?.toString() ?? message.data['userId']?.toString();
      if (senderId == currentUser.uid.toString()) {
        return; // Ignore notification triggered by the current user
      }
    }

    await _local.show(
      message.messageId?.hashCode ?? n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName, channelDescription: 'App notifications', importance: Importance.high, priority: Priority.high, icon: '@mipmap/launcher_icon'),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  void _onOpenedFromBackground(RemoteMessage message) {
    // Do NOT gate on pushEnabled — the notification was already delivered by
    // the OS and the user explicitly tapped it; we must always handle the tap.
    _dispatchOpened(message.data);
  }

  void _dispatchOpened(Map<String, dynamic> data) {
    final cb = onNotificationOpened;
    if (cb != null) cb(Map<String, dynamic>.from(data));
  }
}
