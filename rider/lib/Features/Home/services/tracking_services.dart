import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../model/ride_model.dart';

/// Handles all API calls related to ride tracking.
/// Replace [_baseUrl] with your actual backend URL.
/// Replace [_authToken] with your app's auth token storage solution.
class TrackingService {
  static const String _baseUrl =
      'https://api.dyspatch.com.ng'; // TODO: replace with real base URL
  static const String _authToken =
      'YOUR_AUTH_TOKEN'; // TODO: replace with stored user token

  static Map<String, String> get _headers => {
    'Authorization': 'Bearer $_authToken',
    'Content-Type': 'application/json',
    'User-Agent': 'DyspatchApp/1.0',
  };

  /// Fetches full order details including rider info and drop-off location.
  /// Called once when the tracking screen opens.
  /// Endpoint: GET /orders/{orderId}
  static Future<RideModel> fetchRideDetails(String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return RideModel.fromJson(data);
    } else {
      throw Exception('Failed to load ride details (${response.statusCode})');
    }
  }

  /// Fetches the rider's current GPS position and updated ETA.
  /// Called every 3–5 seconds via Timer.periodic.
  /// Endpoint: GET /orders/{orderId}/rider-location
  /// Returns: { lat, lng, eta_minutes, status }
  static Future<Map<String, dynamic>> fetchRiderLocation(String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/rider-location');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to fetch rider location (${response.statusCode})',
      );
    }
  }

  /// Fetches a shareable public tracking URL for the recipient.
  /// Endpoint: POST /orders/{orderId}/share-link
  /// Returns: { url }
  static Future<String> fetchShareLink(String orderId) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/share-link');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['url'] as String;
    } else {
      throw Exception('Failed to generate share link (${response.statusCode})');
    }
  }

  /// Sends an SOS/emergency flag for this order.
  /// Endpoint: POST /orders/{orderId}/sos
  static Future<void> sendSOS(String orderId, LatLng userLocation) async {
    final url = Uri.parse('$_baseUrl/orders/$orderId/sos');
    final response = await http.post(
      url,
      headers: _headers,
      body: json.encode({
        'user_lat': userLocation.latitude,
        'user_lng': userLocation.longitude,
        'message': 'User flagged a safety concern',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send SOS (${response.statusCode})');
    }
  }

  /// Fetches the route polyline between two points using OSRM.
  /// rider position → drop-off location.
  static Future<String?> fetchRouteGeometry(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}?overview=full&geometries=polyline',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['routes'][0]['geometry'] as String?;
    }
    return null;
  }
}
