import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/dyspatch_api.dart';
import '../api/session.dart';

/// Must be a top-level function: handles pushes while the app is terminated/backgrounded.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging: permission, token registration with the backend,
/// foreground display, and opening the right screen when a notification is tapped.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'dyspatch_updates', 'Delivery updates',
    description: 'Rider assigned, pickup, arrival and wallet updates',
    importance: Importance.high,
  );

  /// Set by main.dart: called with the notification data when the user taps one.
  void Function(Map<String, dynamic> data)? onOpen;
  String? token;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload != null && payload.isNotEmpty) onOpen?.call(Uri.splitQueryString(payload));
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null || !Platform.isAndroid) return; // iOS shows it natively via presentation options
      _local.show(
        m.hashCode, n.title, n.body,
        NotificationDetails(android: AndroidNotificationDetails(_channel.id, _channel.name,
            channelDescription: _channel.description, importance: Importance.high, priority: Priority.high, color: const Color(0xFF34A853))),
        payload: Uri(queryParameters: m.data.map((k, v) => MapEntry(k, v.toString()))).query,
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(m.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) Future.delayed(const Duration(milliseconds: 800), () => onOpen?.call(initial.data));

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      token = t;
      _register();
    });
  }

  /// Asks for permission (Android 13+/iOS) and registers this device with the backend.
  Future<bool> requestPermissionAndRegister() async {
    final s = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    final granted = s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
    await syncToken();
    return granted;
  }

  /// Registers the current FCM token if signed in. Safe to call often.
  Future<void> syncToken() async {
    try {
      if (Platform.isIOS) await FirebaseMessaging.instance.getAPNSToken();
      token = await FirebaseMessaging.instance.getToken();
      await _register();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
    }
  }

  Future<void> _register() async {
    if (token == null || !Session.instance.isLoggedIn) return;
    try {
      await DyspatchApi.registerDevice(token!, Platform.isIOS ? 'ios' : 'android');
    } catch (e) {
      debugPrint('Device registration failed: $e');
    }
  }
}
