import 'package:latlong2/latlong.dart';

/// Decodes a standard encoded polyline string into a list of LatLng points.
/// Works with OSRM and Google Maps encoded polylines.
List<LatLng> decodePolyline(String encodedPolyline) {
  List<LatLng> points = [];
  int index = 0;
  int len = encodedPolyline.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int shift = 0, result = 0, b;
    do {
      b = encodedPolyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dLat;

    shift = 0;
    result = 0;
    do {
      b = encodedPolyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dLng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}