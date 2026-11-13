import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'theme.dart';

/// OpenStreetMap tiles (no API key). Carto's free basemaps now require a key.
/// Dark mode darkens the same tiles; the attribution is required by OSM's usage policy.
TileLayer tiles(BuildContext context) => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.dyspatch.rider',
      maxNativeZoom: 19,
      tileBuilder: Theme.of(context).brightness == Brightness.dark ? darkModeTileBuilder : null,
    );

Widget osmCredit() => const SimpleAttributionWidget(source: Text('OpenStreetMap contributors'), backgroundColor: Color(0xCCFFFFFF));

Marker pinMarker(LatLng p, Color c, {IconData icon = Icons.circle, double size = 34}) => Marker(
      point: p,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)]),
        child: Icon(icon, size: size * 0.45, color: Colors.white),
      ),
    );

Marker meMarker(LatLng p) => Marker(
      point: p,
      width: 26,
      height: 26,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF1A73E8), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)]),
      ),
    );

const routeColor = brandGreen;
