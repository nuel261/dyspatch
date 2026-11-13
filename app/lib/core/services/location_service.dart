import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Single place for location permission + GPS.
///
/// The app previously used two location plugins at once (`location` and
/// `geolocator`, the latter via the map's CurrentLocationLayer). Both answered
/// the same Android permission prompt, and `location` 8.0.1 crashes natively
/// (index out of bounds on an empty grantResults) when its prompt is interrupted —
/// which killed the app on the Track tab. Everything now goes through geolocator,
/// and permission requests are serialised so two screens can never prompt at once.
class LocationService {
  LocationService._();

  static Future<bool>? _pending;

  /// Returns true when location services are on and permission is granted.
  /// Prompts the user if needed. Never throws.
  static Future<bool> ensurePermission({bool openSettingsIfOff = false}) {
    return _pending ??= _ensure(openSettingsIfOff).whenComplete(() => _pending = null);
  }

  static Future<bool> _ensure(bool openSettingsIfOff) async {
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

  /// Current position, or throws an [Exception] with a user-facing message.
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Turn on location services');
    if (!await ensurePermission()) throw Exception('Location permission denied');
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw Exception('Could not get your location. Try again outdoors.');
    }
  }

  static Stream<Position> stream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      );
}
