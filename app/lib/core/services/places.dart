import 'dart:math';

import 'package:dyspatch_app/core/api/dyspatch_api.dart';

/// One Google Places "session": every keystroke's autocomplete call and the
/// final Place Details call share a token, so Google bills it as one lookup.
/// Start a new session after each pick (or when the user clears the field).
class PlaceSession {
  static final _rng = Random.secure();
  String _token = _newToken();
  String get token => _token;
  void renew() => _token = _newToken();

  static String _newToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Future<List<Map<String, dynamic>>> suggest(String q) => DyspatchApi.autocompletePlaces(q, _token);

  /// Turns a suggestion into {name, address, lat, lng}. Suggestions from the
  /// OpenStreetMap fallback already carry coordinates; Google ones need Details.
  Future<Map<String, dynamic>> resolve(Map<String, dynamic> s) async {
    try {
      if (s['lat'] != null && s['lng'] != null) return s;
      final d = await DyspatchApi.placeDetails(s['place_id'] as String, _token);
      return {
        ...s,
        'lat': d['lat'],
        'lng': d['lng'],
        // Keep the short name the user tapped; use Google's full address as the detail line.
        'address': (d['address'] as String?)?.isNotEmpty == true ? d['address'] : s['address'],
      };
    } finally {
      renew();
    }
  }
}

/// "Name, address" without repeating the name.
String placeLabel(Map<String, dynamic> p) {
  final name = ((p['name'] ?? '') as String).trim();
  var addr = ((p['address'] ?? '') as String).trim();
  if (addr.startsWith('$name, ')) addr = addr.substring(name.length + 2);
  return addr.isNotEmpty && addr != name ? (name.isEmpty ? addr : '$name, $addr') : name;
}
