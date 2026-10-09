import 'dart:convert';

import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../model/ride_model.dart';

/// Ride tracking calls against https://dyspatch.bitprofil.com/api.
class TrackingService {
  /// Full order details incl. rider, timeline and parcels. GET /orders/{trackId}
  /// (falls back to public GET /track/{trackId} for packages sent by others).
  static Future<RideModel> fetchRideDetails(String trackId) async =>
      RideModel.fromJson(await DyspatchApi.order(trackId));

  /// Rider GPS + ETA. GET /orders/{trackId}/rider-location → { lat, lng, eta_minutes, status }
  static Future<Map<String, dynamic>> fetchRiderLocation(String trackId) => DyspatchApi.riderLocation(trackId);

  /// Shareable public tracking URL. POST /orders/{trackId}/share-link → { url }
  static Future<String> fetchShareLink(String trackId) => DyspatchApi.shareLink(trackId);

  /// Flags a safety concern. POST /orders/{trackId}/sos
  static Future<void> sendSOS(String trackId, LatLng? userLocation) =>
      DyspatchApi.sos(trackId, userLocation?.latitude, userLocation?.longitude);

  /// Road route polyline between two points using OSRM (free; no key needed).
  static Future<String?> fetchRouteGeometry(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}?overview=full&geometries=polyline',
    );
    final response = await http.get(url, headers: {'User-Agent': 'DyspatchApp/1.0'});
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) return routes[0]['geometry'] as String?;
    }
    return null;
  }
}
