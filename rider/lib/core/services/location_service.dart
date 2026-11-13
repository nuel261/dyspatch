import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../api/rider_api.dart';

/// GPS for the rider app. While the rider is online (or on a delivery) the position
/// stream runs as an Android foreground service with a persistent "You're online"
/// notification, so location keeps reaching the backend — and customers keep seeing
/// the rider move — when the app is in the background or the screen is off.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? last;
  StreamSubscription<Position>? _sub;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  Position? _lastSentPos;
  Future<bool>? _pending;
  final _controller = StreamController<Position>.broadcast();

  Stream<Position> get positions => _controller.stream;
  bool get tracking => _sub != null;

  /// True when location services are on and permission is granted. Never throws.
  Future<bool> ensurePermission({bool openSettingsIfOff = false}) =>
      _pending ??= _ensure(openSettingsIfOff).whenComplete(() => _pending = null);

  Future<bool> _ensure(bool openSettingsIfOff) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (openSettingsIfOff) await Geolocator.openLocationSettings();
        return false;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return p == LocationPermission.whileInUse || p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<Position?> current() async {
    if (!await ensurePermission()) return last;
    try {
      last = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
    } catch (_) {
      last ??= await Geolocator.getLastKnownPosition();
    }
    return last;
  }

  LocationSettings _settings() {
    if (kIsWeb) return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
          intervalDuration: const Duration(seconds: 8),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: "You're online",
            notificationText: 'Dyspatch is sharing your location so you can receive and complete deliveries.',
            notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
    }
  }

  /// Starts streaming GPS to the backend (no-op if already running).
  Future<void> startTracking() async {
    if (_sub != null) return;
    if (!await ensurePermission()) return;
    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen((p) {
      last = p;
      _controller.add(p);
      _maybeSend(p);
    }, onError: (e) => debugPrint('Location stream error: $e'));
  }

  Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Sends at most every 8 seconds, or sooner after moving 40 m.
  void _maybeSend(Position p, {bool force = false}) {
    final now = DateTime.now();
    final moved = _lastSentPos == null ? 1e9 : Geolocator.distanceBetween(_lastSentPos!.latitude, _lastSentPos!.longitude, p.latitude, p.longitude);
    if (!force && now.difference(_lastSent).inSeconds < 8 && moved < 40) return;
    _lastSent = now;
    _lastSentPos = p;
    RiderApi.sendLocation(p.latitude, p.longitude,
            heading: p.heading >= 0 ? p.heading : null, speed: p.speed >= 0 ? p.speed : null)
        .catchError((e) {
      debugPrint('Location upload failed: $e');
      return <String, dynamic>{};
    });
  }

  /// Push the latest fix right away (e.g. when going online).
  void sendNow() {
    if (last != null) _maybeSend(last!, force: true);
  }
}
