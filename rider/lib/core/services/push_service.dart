import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/rider_api.dart';
import '../api/session.dart';

/// Push notifications for the rider app.
///
/// Two Android channels:
///   dyspatch_jobs     — new job offers: max importance, the "job_alert" chime, strong
///                       vibration, shown on the lock screen. The backend sends offers
///                       on this channel (see backend/includes/Push.php).
///   dyspatch_updates  — everything else (payouts, verification, cancellations).
///
/// Firebase is optional at runtime: until google-services.json for com.dyspatch.rider is
/// added, [fcmReady] stays false and offers still arrive by polling (RiderState), with the
/// same chime played through a local notification.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Offer pushes carry a notification block, so Android shows them itself.
  // A silent "offer_closed" message removes the alert for a job someone else took.
  if (message.data['type'] == 'offer_closed') {
    final id = int.tryParse('${message.data['offer_id']}');
    if (id != null) await FlutterLocalNotificationsPlugin().cancel(PushService.offerNotificationId(id));
  }
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const jobsChannel = AndroidNotificationChannel(
    'dyspatch_jobs',
    'New jobs',
    description: 'Delivery requests you can accept. Rings until you respond or the offer expires.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('job_alert'),
    enableVibration: true,
  );

  static const updatesChannel = AndroidNotificationChannel(
    'dyspatch_updates',
    'Delivery updates',
    description: 'Cancellations, payouts and account updates.',
    importance: Importance.high,
  );

  static int offerNotificationId(int offerId) => 100000 + offerId % 800000;

  final _local = FlutterLocalNotificationsPlugin();
  bool fcmReady = false;
  bool _localReady = false;

  /// Push payload handlers, wired up by RiderState.
  void Function(Map<String, dynamic> data)? onOfferPushed;
  void Function(Map<String, dynamic> data)? onOfferClosed;
  void Function(Map<String, dynamic> data)? onUpdate;
  void Function(Map<String, dynamic> data)? onOpen;

  Future<void>? _initFuture;

  /// Sets up local notifications + Firebase. Runs once (later calls share the
  /// same future). Started after the first frame, never on the startup path.
  Future<void> init() => _initFuture ??= _init().timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('Push init timed out');
      }).catchError((e) {
        debugPrint('Push init failed: $e');
      });

  Future<void> _init() async {
    if (kIsWeb) return;
    await _initLocal();
    try {
      await Firebase.initializeApp();
      fcmReady = true;
    } catch (e) {
      debugPrint('Firebase not configured for the rider app yet — using polling for offers. ($e)');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((m) {
      final data = Map<String, dynamic>.from(m.data);
      switch (data['type']) {
        case 'offer':
          onOfferPushed?.call(data);
          break;
        case 'offer_closed':
          final id = int.tryParse('${data['offer_id']}');
          if (id != null) _local.cancel(offerNotificationId(id));
          onOfferClosed?.call(data);
          break;
        default:
          final n = m.notification;
          if (n != null) showUpdate(n.title ?? 'Dyspatch', n.body ?? '');
          onUpdate?.call(data);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(Map<String, dynamic>.from(m.data)));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final data = Map<String, dynamic>.from(initial.data);
      Future.delayed(const Duration(milliseconds: 600), () => onOpen?.call(data));
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      if (Session.instance.isLoggedIn) RiderApi.registerDevice(t, Platform.isIOS ? 'ios' : 'android').catchError((_) {});
    });
  }

  Future<void> _initLocal() async {
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => onOpen?.call({'type': r.payload ?? 'open'}),
      );
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(jobsChannel);
      await android?.createNotificationChannel(updatesChannel);
      _localReady = true;
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }
  }

  /// Asks for notification permission and registers this phone with the backend.
  Future<bool> requestPermissionAndRegister() async {
    if (kIsWeb) return false;
    await init();
    var granted = true;
    try {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      granted = await android?.requestNotificationsPermission() ?? true;
      final ios = _local.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true, critical: false);
    } catch (_) {}
    if (!fcmReady) return granted;
    try {
      final s = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      granted = s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
      await syncToken();
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
    return granted;
  }

  Future<void> syncToken() async {
    await init();
    if (!fcmReady || !Session.instance.isLoggedIn) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await RiderApi.registerDevice(token, Platform.isIOS ? 'ios' : 'android');
    } catch (e) {
      debugPrint('Could not register push token: $e');
    }
  }

  Future<String?> currentToken() async {
    if (!fcmReady) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Rings the job chime with a heads-up notification (used for offers found by polling,
  /// and for pushed offers while the app is open).
  Future<void> showOfferAlert(int offerId, String title, String body, {int expiresIn = 45}) async {
    if (!_localReady) return;
    await _local.show(
      offerNotificationId(offerId),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          jobsChannel.id, jobsChannel.name,
          channelDescription: jobsChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          sound: const RawResourceAndroidNotificationSound('job_alert'),
          vibrationPattern: Int64List.fromList([0, 600, 250, 600, 250, 900]),
          timeoutAfter: expiresIn * 1000,
          visibility: NotificationVisibility.public,
          color: const Color(0xFF34A853),
          fullScreenIntent: true,
          ticker: 'New delivery request',
        ),
        iOS: const DarwinNotificationDetails(presentSound: true, sound: 'job_alert.caf', interruptionLevel: InterruptionLevel.timeSensitive),
      ),
      payload: 'offer',
    );
  }

  Future<void> cancelOfferAlert(int offerId) async {
    if (_localReady) await _local.cancel(offerNotificationId(offerId));
  }

  Future<void> showUpdate(String title, String body) async {
    if (!_localReady) return;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(updatesChannel.id, updatesChannel.name,
            channelDescription: updatesChannel.description, importance: Importance.high, priority: Priority.high, color: const Color(0xFF34A853)),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }
}
